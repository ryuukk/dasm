module renderer;

import gl;
import camera;
import dbg;
import ecs;
import memory;
import math;
import filesystem;
import spritebatch;
import gfx;

struct Renderer
{
    RenderState state;
    Camera camera;
    Registry registry;
    SpriteBatch spritebatch;

    Engine* engine;

    void create(Engine* engine)
    {
        this.engine = engine;
        //init_renderer();
        
        state.set_blend_state(BlendState.AlphaBlend);
        state.set_depth_state(DepthState.Default, true);

        camera = Camera.init_perspective(60, engine.width, engine.height);
        camera.near = 0.1;
        camera.far = 35.0;
        //cam.position = v3(0, 10, 6) * 0.6;
        //cam.rotate(v3(1,0,0), -45);

        camera.position = v3(0, 10, 5) * 0.6;
        camera.look_at(0, 0, 0);
        camera.update();

        registry.create(MALLOCATOR.ptr());

        spritebatch.create(engine);
    }

    void init_renderer()
    {
        glBindVertexArray(0);
        glUseProgram(0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        for(int i = 0; i < 16; i++)
        {
            glActiveTexture(GL_TEXTURE0 + 1);
            glBindTexture(GL_TEXTURE_2D, 0);
        }
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
                break;

                default: break;
            }
        }

    }
}


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

    void apply(ref const PolygonState current) const
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

    void set_polygon_state(ref const PolygonState ps) const
    {
        ps.apply(poly_state);
    }

    void set_vertex_buffer(uint handle)
    {

    }

    void set_texture(int unit, uint handle)
    {

    }
}

