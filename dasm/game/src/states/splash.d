module states.splash;

import app;

import rt.dbg;
import rt.math;
import rt.time;
import rt.memory;
import rt.dbg;

import dawn.gfx;
import dawn.renderer;
import dawn.gl;
import dawn.mesh;
import dawn.camera;
import dawn.assets;
import dawn.font;


const(char)[] shader_v = "#version 300 es
    #ifdef GL_ES
    precision lowp float;
    #endif	
    uniform mat4 u_mvp;
    uniform mat4 u_transform;
    in vec4 a_position;
    in vec3 a_normal;
    out vec3 v_col;
    void main()
    {
        v_col = a_normal;
        gl_Position = u_mvp * u_transform * a_position;
    }
";

const(char)[] shader_f = "#version 300 es
    #ifdef GL_ES
    precision lowp float;
    #endif	
    in vec3 v_col;
    out vec4 f_col;
    void main()
    {
        f_col = vec4(v_col, 1.0);
    }
";

Allocator* allocator;
ShaderProgram program;
Mesh cube_mesh;
mat4 transform = mat4.identity;
float a = 0;
ModelAsset* mdl;
FontAsset* fnt;
TextureAsset* tex;

FontCache fc;

void splash_init(State* state)
{
    LINFO("Splash: init");    
    
    tex = engine.cache.load!(TextureAsset)("res/textures/uv_grid.png");
    mdl = engine.cache.load!(ModelAsset)("res/models/male.bin");
    fnt = engine.cache.load!(FontAsset)("res/fonts/font.dat");
    
    program.create(shader_v, shader_f);
    assert(program.is_compiled, "can't compile shader");

    create_cube_mesh(&cube_mesh);

    fc.create(null, false);
}

void splash_render(State* state, float dt)
{
    auto renderer = &engine.renderer;
        
    if (engine.input.is_key_just_pressed(Key.KEY_A))
    {
        LINFO("List cached resources:");
        foreach(pair; engine.cache.map)
        {
            LINFO("p: {} rc: {} {}", pair.value.path, pair.value.ref_count, pair.value.is_empty());
        }
    }

    a += 5 * dt;
    transform = mat4.set(v3(0, 0, 0), quat.fromAxis(0, 1, 0, a), v3(1, 1, 1));

    renderer.camera.update();

    // render cube
    renderer.state.set_depth_state(DepthState.Read, true);
    program.bind();
    program.set_uniform_mat4("u_mvp", &renderer.camera.combined);
    program.set_uniform_mat4("u_transform", &transform);
    
    cube_mesh.render(&program, GL_TRIANGLES);

    // render texture when ready

    renderer.state.set_depth_state(DepthState.None);
    renderer.spritebatch.begin();
    if (tex && tex.base.is_ready())
    {
        renderer.spritebatch.draw(&tex.tex, 0,0, 128, 128);
        renderer.spritebatch.draw(&tex.tex, 128,128, 128, 128);

        // void draw (Texture2D* texture,
        // Rectf region, float x, float y,
        // float originX, float originY, float width, float height,
		// float scaleX, float scaleY, float rotation) 

        renderer.spritebatch.draw(&tex.tex, 
            Rectf(0, 0, tex.tex.width, tex.tex.height),
            256,256,
            0,0,
            128,128,
            1, 1, a
        );
    }
    renderer.spritebatch.end(); 


    if (fnt.base.is_ready && !fc.font)
    {
        LINFO("set font!");
        fc.font = &fnt.fnt;
    }


    fc.clear();

    char[256] tmp = 0;
    import rt.str;

    float_to_str(tmp.ptr, now.seconds, 2);
    
    fc.add_text("Hello WASM! dsqdsqdqs", 8, engine.height);
    fc.add_text(tmp, 8, engine.height - 32);

    renderer.spritebatch.begin();
    fc.draw(&renderer.spritebatch);
    renderer.spritebatch.end();
}