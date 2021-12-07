module dawn.renderer;

import rt.dbg;
import rt.memory;
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
import dawn.assets;

struct Renderer
{
    RenderState state;
    ResourceCache cache;

    Camera camera;
    Registry registry;
    SpriteBatch spritebatch;
    EntityRenderer entity_renderer;

    Engine* engine;

    void create(Engine* engine)
    {
        this.engine = engine;
        //init_renderer();

        cache.create();
        
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
        cache.process();
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


struct EntityRenderer
{
    EntityShader[8] shaders;
    int num_shaders;

    Array!(Renderable*) renderables;
    Array!(Renderable) pool;
    int used;

    const(char)[] fs;
    const(char)[] vs;

    Texture2D no_tex;
    int num_bones = 30;

    void create()
    {
        
    }
}

struct EntityShader
{
    // Global uniforms
    int u_time;
    int u_projTrans;
    int u_viewTrans;
    int u_projViewTrans;
    int u_cameraPosition;
    
    // Object uniforms
    int u_worldTrans;
    int u_bones;
    int u_diffuseTexture;
    int u_diffuseUVTransform;

    // Light uniforms
    int u_fogColor;


    bool animation = false;
    
    Texture2D* no_tex = null;
    ShaderProgram program;

    ulong attributes_mask;
    ulong vertex_mask;

    Mesh* current_mesh = null;

    int num_bones = 0;

    bool use_texture;
    
    void create(Renderable* renderable, const(char)[] vs, const(char)[] fs, int numBones)
    {
        use_texture = renderable.use_tex;

        num_bones = numBones;
        program.create(vs, fs);
        if(!program.is_compiled)
            panic("can't build shader");

        vertex_mask = renderable.meshpart.mesh.vb.attributes.get_mask_with_size_packed();
        debug check_gl_error();
    }

    void init()
    {
        u_time = program.fetch_uniform_location("u_time", false);
        u_projTrans = program.fetch_uniform_location("u_projTrans", false);
        u_viewTrans = program.fetch_uniform_location("u_viewTrans", false);
        u_projViewTrans = program.fetch_uniform_location("u_projViewTrans", false);
        u_cameraPosition = program.fetch_uniform_location("u_cameraPosition", false);
    
        u_worldTrans = program.fetch_uniform_location("u_worldTrans", false);
        u_bones = program.fetch_uniform_location("u_bones", false);

        u_diffuseTexture = program.fetch_uniform_location("u_diffuseTexture", false);
        u_diffuseUVTransform = program.fetch_uniform_location("u_diffuseUVTransform", false);

        u_fogColor = program.fetch_uniform_location("u_fogColor", false);

        // &LINFO("u_time:           %i",u_time);
        // LINFO("u_projTrans:      %i",u_projTrans);
        // LINFO("u_viewTrans:      %i",u_viewTrans);
        // LINFO("u_projViewTrans:  %i",u_projViewTrans);
        // LINFO("u_cameraPosition: %i",u_cameraPosition);
    
        // LINFO("u_worldTrans:     %i",u_worldTrans);
        // LINFO("u_bones:          %i",u_bones);

        // LINFO("u_diffuseTexture:     %i",u_diffuseTexture);
        // LINFO("u_diffuseUVTransform: %i",u_diffuseUVTransform);

        // LINFO("u_fogColor: %i",u_fogColor);
        
    }

    bool can_render(Renderable* renderable)
    {
        ulong mask = combine_attributes(renderable);
        return 
        attributes_mask == mask &&
        vertex_mask == renderable.meshpart.mesh.vb.attributes.get_mask_with_size_packed() &&
         use_texture == renderable.use_tex
        ;
    }

    void begin(Camera* camera)
    {

        if(!program.is_compiled)
            panic("shader problem");

        current_mesh = null;

        program.bind();
        debug check_gl_error();

        // bind global

        if(u_time > 0)
            program.set_uniformf(u_time, 0.0f); // TODO: implement that
        
        program.set_uniform_mat4(u_projViewTrans, &camera.combined);
        program.set_uniform4f(u_cameraPosition, camera.position.x, camera.position.y, camera.position.z, 1.1001f / (camera.far * camera.far));

        if(u_fogColor >= 0)
            program.set_uniform4f(u_fogColor, 0,0,0,1);

        debug check_gl_error();
    }

    void render(Renderable* renderable, Camera* camera)
    {
        if(current_mesh != renderable.meshpart.mesh)
        {
            if(current_mesh) 
            {
                current_mesh.unbind(&program, null);
                debug check_gl_error();
            }
            
            current_mesh = renderable.meshpart.mesh;
            current_mesh.bind(&program, null);
            debug check_gl_error();
        }

        // bind object
        
        program.set_uniform_mat4(u_worldTrans, &renderable.world_transform);
        debug check_gl_error();

        //if(u_bones >= 0 && renderable.bones.length > 0)
        //{
        //    int count = cast(int) renderable.bones.length;
        //    if(count > num_bones) count = num_bones;
        //
        //    program.set_uniform_mat4_array(u_bones, count, renderable.bones);
        //    debug check_gl_error();
        //}

        // blending
        // metarial

        if(use_texture && no_tex)
        {
            no_tex.bind();
            debug check_gl_error();
            program.set_uniformi(u_diffuseTexture, 0);
            debug check_gl_error();

            program.set_uniform4f(u_diffuseUVTransform, 0, 0, 1, 1);
            debug check_gl_error();
        }

        // env

        // light
        //program.set_uniform4f()


        renderable.meshpart.render(&program, false);

        debug check_gl_error();

    }

    void end()
    {
        if(current_mesh)
        {
            current_mesh.unbind(&program, null);
            current_mesh = null;
            debug check_gl_error();
        }
        else
        {
        }
    }
}

struct Renderable
{
    mat4 world_transform;
    MeshPart meshpart;
    Material* material = null;
    //Environment* environment;
    mat4[] bones;
    EntityShader* shader = null;

    bool use_tex = false;
}


ulong combine_attributes(Renderable* renderable)
{
    ulong mask = 0;
    //if(renderable.environement) mask |= renderable.environement.mask;
    if(renderable.material) mask |= renderable.material.mask;
    return mask;
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

