module dawn.renderer;

import rt.dbg;
import rt.memz;
import rt.math;
import rt.filesystem;
import rt.collections.array;

import dawn.gl;
import dawn.camera;
import dawn.ecs;
import dawn.spritebatch;
import dawn.gfx;
import dawn.mesh;
import dawn.texture;
import dawn.font;
import dawn.assets;
import dawn.model;
import mu = dawn.microui;

struct Renderer
{
    RenderState state;
    Texture2D ui_atlas;
    FontCache font_cache;

    Camera camera;
    SpriteBatch spritebatch;

    Engine* engine;

    Allocator* allocator;

    void create(Engine* engine)
    {
        LINFO("Create renderer");
        this.engine = engine;
        this.allocator = engine.allocator;

        glBindVertexArray(0);
        glUseProgram(0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glBindTexture(GL_TEXTURE_2D, 0);

        state.set_blend_state(BlendState.AlphaBlend, true);
        state.set_depth_state(DepthState.Default, true);
        state.set_polygon_state(PolygonState.CullCCW, true);


        camera = Camera.init_perspective(45, engine.width, engine.height);
        camera.near = 0.1;
        camera.far = 35.0;
        //cam.position = v3(0, 10, 6) * 0.6;
        //cam.rotate(v3(1,0,0), -45);

        // camera.position = v3(0, 8, 8) * 0.6;
        camera.position = v3(0, 10.2, 6.4) * 0.8;
        camera.look_at(0, 0, 0);
        camera.update();

        spritebatch.create(engine);

        ui_atlas = create_texture(mu.ATLAS_WIDTH, mu.ATLAS_HEIGHT, mu.atlas_texture.ptr, PixelFormat.Alpha);
    }

    void tick()
    {
        foreach(Event* e; engine.queue)
        {
            switch (e.type) with(EventType)
            {
                case GFX_RESIZE:
                    writeln("RESIZE: {}:{}", e.resize.width, e.resize.height);
                    camera.viewport_width = e.resize.width;
                    camera.viewport_height = e.resize.height;
                    camera.update();

                    auto pm = mat4.create_orthographic_offcenter(0f, 0f, e.resize.width, e.resize.height);
                    spritebatch.set_proj(pm);

                break;

                default: break;
            }
        }
    }
}


ubyte[256] button_map =
[
    (cast(ubyte) Mouse.LEFT   & 0xff):  mu.MOUSE_LEFT,
    (cast(ubyte) Mouse.RIGHT  & 0xff):  mu.MOUSE_RIGHT,
    (cast(ubyte) Mouse.MIDDLE & 0xff):  mu.MOUSE_MIDDLE,
];

ubyte[256] key_map = 
[
    (cast(ubyte) Key.KEY_LEFT_SHIFT    & 0xff): mu.KEY_SHIFT,
    // (cast(ubyte) Key.KEY_RIGHT_SHIFT   & 0xff): mu.KEY_SHIFT,
    (cast(ubyte) Key.KEY_LEFT_CONTROL  & 0xff): mu.KEY_CTRL,
    // (cast(ubyte) Key.KEY_RIGHT_CONTROL & 0xff): mu.KEY_CTRL,
    (cast(ubyte) Key.KEY_LEFT_ALT      & 0xff): mu.KEY_ALT,
    // (cast(ubyte) Key.KEY_RIGHT_ALT     & 0xff): mu.KEY_ALT,
    (cast(ubyte) Key.KEY_ENTER         & 0xff): mu.KEY_RETURN,
    (cast(ubyte) Key.KEY_BACKSPACE     & 0xff): mu.KEY_BACKSPACE,
    (cast(ubyte) Key.KEY_LEFT          & 0xff): mu.KEY_LEFT,
    (cast(ubyte) Key.KEY_RIGHT         & 0xff): mu.KEY_RIGHT,
];

int text_width(mu.Font font, const char* text, int len)
{
    import rt.str;
    auto fc = cast(FontCache*) font;
    if (!fc) return 0;

    if (len == -1)
        len = cast(int) str_len(text);

    auto b = fc.font.get_bounds(text, 0, len);
    return cast(int)b.width;
}

int text_height(mu.Font font)
{
    auto fc = cast(FontCache*) font;
    if (!fc) return 0;

    return fc.font.line_height;
}

void process_ui(mu.Context* ctx)
{
    foreach(Event* e; engine.queue)
    {
        switch(e.type) with(EventType)
        {
            case INPUT_MOUSE_MOVED:
            mu.input_mousemove(ctx, e.touch_moved.screen_x, e.touch_moved.screen_y);
            if(ctx.hover_root) e.consumed = true;
            break;
            case INPUT_TOUCH_DRAGGED:
            mu.input_mousemove(ctx, e.touch_moved.screen_x, e.touch_moved.screen_y);
            if(ctx.hover_root) e.consumed = true;
            break;
            case INPUT_TOUCH_DOWN:
            mu.input_mousedown(ctx, e.touch_down.screen_x, e.touch_down.screen_y, button_map[e.touch_down.button]);
            if(ctx.hover_root) e.consumed = true;            
            break;
            case INPUT_TOUCH_UP:
            mu.input_mouseup(ctx, e.touch_up.screen_x, e.touch_up.screen_y, button_map[e.touch_up.button]);
            if(ctx.hover_root) e.consumed = true;
            break;
            case INPUT_KEY_DOWN:
            mu.input_keydown(ctx, key_map[e.key_down.key]);
            if(ctx.focus) e.consumed = true;
            break;
            case INPUT_KEY_UP:
            mu.input_keyup(ctx, key_map[e.key_up.key]);
            if(ctx.focus) e.consumed = true;
            break;
            case INPUT_KEY_TYPED:
            mu.input_text(ctx, cast(const char*) &e.key_typed.character);
            if(ctx.focus) e.consumed = true;
            break;
            default:
        }
    }
}

void render_ui(mu.Context* ctx, FontCache* font_cache, SpriteBatch* batch)
{
    import rt.str;
    engine.renderer.state.set_depth_state(DepthState.None);
    glEnable(GL_SCISSOR_TEST);
    batch.begin();

    mu.Command* cmd = null;
    while (mu.next_command(ctx, &cmd))
    {
        final switch (cmd.type)
        {
        case mu.COMMAND_TEXT: /* r_draw_text(cmd.text.str, cmd.text.pos, cmd.text.color); */ 
        
            float x = cmd.text.pos.x;
            float y = cmd.text.pos.y;
            
            // flip for Y up
            y = (engine.height - font_cache.font.line_height - y);

            // batch.set_color(Color.GREEN.tupleof);
            // batch.draw_rect(x, y, 16, font_cache.font.line_height);

            y += font_cache.font.line_height;

            font_cache.clear();
            font_cache.set_tint(Color(cmd.text.color.tupleof));

            auto l = str_len(cmd.text.str.ptr);
            auto b = font_cache.add_text(cmd.text.str.ptr[0 .. l], x, y);

            // batch.set_color(cmd.text.color.tupleof);
            // batch.draw_rect(x, y, b.width, b.height);

            font_cache.draw(batch);
            font_cache.clear();
            // TODO: BUG: font cache shouldn't need to be cleared twice..
            // i suspect a bug somewhere, but idk wher yet
            // i need to investigate..

        
        break;
        case mu.COMMAND_RECT: /* r_draw_rect(cmd.rect.rect, cmd.rect.color);               */ 

            float x = cmd.rect.rect.x;
            float y = cmd.rect.rect.y;
            float w = cmd.rect.rect.w;
            float h = cmd.rect.rect.h;

            // flip for Y up
            y = (engine.height - h - y);

            batch.set_color(cmd.rect.color.tupleof);
            batch.draw_rect_filled(x, y, w, h);

        break;
        case mu.COMMAND_ICON: /* r_draw_icon(cmd.icon.id, cmd.icon.rect, cmd.icon.color); */
            float x = cmd.icon.rect.x;
            float y = cmd.icon.rect.y;
            float w = cmd.icon.rect.w;
            float h = cmd.icon.rect.h;
        
            // flip for Y up
            y = (engine.height - h - y);
            batch.set_color(cmd.icon.color.tupleof);
            
            auto src = mu.atlas[cmd.icon.id];
            batch.draw(&font_cache.font.atlas,
                Rectf(cast(float) src.x, cast(float) src.y, cast(float) src.w, cast(float) src.h),
                x, y, 0, 0, w, h, 1, 1, 0
            );

        break;
        case mu.COMMAND_CLIP: /* r_set_clip_rect(cmd.clip.rect);                            */ 
            int x = cmd.clip.rect.x;
            int y = cmd.clip.rect.y;
            int w = cmd.clip.rect.w;
            int h = cmd.clip.rect.h;

            // // flip for Y 
            // y = (game.engine.gfx.get_iheight - h - y);

            // LINFO("scisor! %d:%d:%d:%d", x, y, w, h);

            // x, y, z, w
            // x, y, w, h
            //glScissor((int)pcmd.ClipRect.x,
            // (int)(fb_height - pcmd.ClipRect.h),
            // (int)(pcmd.ClipRect.w - pcmd.ClipRect.x),
            //  (int)(pcmd.ClipRect.h - pcmd.ClipRect.y));

            auto clipy = engine.iheight - (cmd.clip.rect.y + cmd.clip.rect.h);

            batch.flush();
            glScissor(
                    cmd.clip.rect.x,
                    cast(uint)clipy,
                    cmd.clip.rect.w,
                    cmd.clip.rect.h
            );
            // batch.set_color(Color.RED.tupleof);
            // batch.draw_rect(Rectf(cmd.clip.rect.x,clipy,cmd.clip.rect.w,cmd.clip.rect.h));
            break;
        }
    }
    batch.end();

    batch.color = Color.WHITE;
}




// GL STATE

struct DepthState
{
    bool enabled;
    uint func = GL_LESS;
    float[2] range = [0, 100];
    bool write_mask;

    void apply(ref DepthState previous, bool force = false) 
    {
        if(force)
        {
            if(enabled)
            {
                glEnable(GL_DEPTH_TEST);

                glDepthMask(write_mask);
                glDepthFunc(func);
                glDepthRange(range[0], range[1]);
            }
            else
            {
                glDisable(GL_DEPTH_TEST);
                glDepthMask(false);
            }
            return;
        }

        if(enabled != previous.enabled)
        {
            if(enabled)
            {
                // LINFO("GL: enable depth");
                glEnable(GL_DEPTH_TEST);
                

                if(func != previous.func)
                    glDepthFunc(func);
                if(write_mask != previous.write_mask)
                    glDepthMask(write_mask);
                if(range[] == previous.range[])
                    glDepthRange(range[0], range[1]);
            }
            else
            {
                glDisable(GL_DEPTH_TEST);
                glDepthMask(false);
                // LINFO("GL: disable depth");
            }
        }
    }

    bool opEquals()(auto ref const DepthState rhs) const
    {
        if (
            enabled == rhs.enabled &&
            func == rhs.func &&
            range == rhs.range &&

            write_mask == rhs.write_mask)
            return true;

        return false;
    }

    enum DepthState None = {
        enabled: false,
        write_mask: false
    };
    enum DepthState Default = {
        enabled: true,
        write_mask: true,
    };
    enum DepthState Read = {
        enabled: true,
        write_mask: false
    };
}

struct BlendState
{
    bool enabled;
    uint equation_rgb = GL_FUNC_ADD;
    uint equation_a = GL_FUNC_ADD;

    uint rgb_src = GL_ONE;
    uint rgb_dst = GL_ZERO;

    uint alpha_src = GL_ONE;
    uint alpha_dst = GL_ZERO;

    uint color;

    void apply(ref BlendState previous, bool force = false) 
    {
        if(force)
        {
            if (enabled)
            {
                glEnable(GL_BLEND);
            }
            else
            {
                glDisable(GL_BLEND);
            }

            glBlendFuncSeparate(rgb_src, rgb_dst, alpha_src, alpha_dst);
            glBlendEquationSeparate(equation_rgb, equation_a);
            glBlendColor(0,0,0,0);
            return;
        }
        if (enabled != previous.enabled)
        {
            if (enabled)
            {
                LINFO("GL: enable blend");
                glEnable(GL_BLEND);
            }
            else
            {
                glDisable(GL_BLEND);
            }
        }

        if (rgb_src != previous.rgb_src ||
            rgb_dst != previous.rgb_dst ||
            alpha_src != previous.alpha_src ||
            alpha_dst != previous.alpha_dst)
        {
            glBlendFuncSeparate(rgb_src, rgb_dst, alpha_src, alpha_dst);
        }

        if (equation_rgb != previous.equation_rgb || equation_a != previous.equation_a)
        {
            glBlendEquationSeparate(equation_rgb, equation_a);
        }
        
        glBlendColor(0,0,0,0);
    }

    bool opEquals()(auto ref const BlendState rhs) const
    {
        if (
            enabled == rhs.enabled &&
            equation_rgb == rhs.equation_rgb &&
            equation_a == rhs.equation_a &&

            rgb_src == rhs.rgb_src &&
            rgb_dst == rhs.rgb_dst &&
            alpha_src == rhs.alpha_src &&
            alpha_dst == rhs.alpha_dst)
            return true;

        return false;
    }

    enum BlendState Disabled = 
    {
        enabled: false,
    };
    enum BlendState AlphaBlend =
    {
        enabled: true,
        equation_rgb: GL_FUNC_ADD,
        equation_a: GL_FUNC_ADD,

        rgb_src: GL_SRC_ALPHA,
        alpha_src: GL_SRC_ALPHA,

        rgb_dst: GL_ONE_MINUS_SRC_ALPHA,
        alpha_dst: GL_ONE_MINUS_SRC_ALPHA,
    };
    enum BlendState Additive =
    {
        enabled: true,
        equation_rgb: GL_FUNC_ADD,
        equation_a: GL_FUNC_ADD,

        rgb_src: GL_ONE,
        alpha_src: GL_ONE,

        rgb_dst: GL_ONE_MINUS_SRC_COLOR,
        alpha_dst: GL_ONE_MINUS_SRC_COLOR,
    };
    enum BlendState NonPremultiplied =
    {
        enabled: true,
        equation_rgb: GL_FUNC_ADD,
        equation_a: GL_FUNC_ADD,

        rgb_src: GL_SRC_ALPHA,
        alpha_src: GL_SRC_ALPHA,

        rgb_dst: GL_ONE_MINUS_SRC_ALPHA,
        alpha_dst: GL_ONE_MINUS_SRC_ALPHA,
    };

    enum BlendState Opaque =
    {
        enabled: true,
        equation_rgb: GL_FUNC_ADD,
        equation_a: GL_FUNC_ADD,

        rgb_src: GL_ONE,
        alpha_src: GL_ONE,

        rgb_dst: GL_ZERO,
        alpha_dst: GL_ZERO,
    };
}

struct StencilState
{
    // TODO: will i ever need this? idk
}

struct ViewportState
{
    // TODO: will i ever need this? probably
}

enum CullMode
{
    CW,
    CCW,
    OFF
}

enum CullFace
{
    FRONT,
    BACK,
    FRONT_BACK
}

struct PolygonState
{
    bool cullface;
    uint cull_face = GL_BACK;
    uint front_face = GL_CCW;

    void apply(ref PolygonState current, bool force = false)
    {
        if (cullface)
        {
            glEnable(GL_CULL_FACE);
            glFrontFace(front_face);
            glCullFace(cull_face);
        }
        else
        {
            glDisable(GL_CULL_FACE);
        }
    }

    bool opEquals()(auto ref const PolygonState rhs) const
    {
        if (
            cullface == rhs.cullface &&
            mode == rhs.mode &&
            front_face == rhs.front_face
            )
            return true;

        return false;
    }

    
    enum PolygonState None = 
    {
        cullface: false,
    };
    
    enum PolygonState CullCW = 
    {
        cullface: true,
        front_face: GL_CW
    };
    
    enum PolygonState CullCCW = 
    {
        cullface: true,
        front_face: GL_CCW
    };
}

struct RenderState
{
    uint vao;
    uint program;
    uint fbo;
    uint[16] tex_unit;
    int nex_tex_unit;
    int viewport_width;
    int viewport_height;
    int frame_counter;

    

    BlendState blend_state;
    DepthState depth_state;
    PolygonState poly_state;

    void set_blend_state(ref BlendState bs, bool force = false)    
    {
        bs.apply(blend_state, force);
        blend_state = bs;
    }

    void set_depth_state(ref DepthState ds, bool force = false)
    {
        ds.apply(depth_state, force);
        depth_state = ds;
    }

    void set_polygon_state(ref PolygonState ps, bool force = false)
    {
        ps.apply(poly_state, force);
        poly_state = ps;
    }

    void set_vertex_buffer(uint handle)
    {

    }

    void set_texture(int unit, uint handle)
    {

    }
}

