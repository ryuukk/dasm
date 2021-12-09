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
Texture* tex;
ModelAsset* mdl;
Texture* tex2;

void splash_init(State* state)
{
    LINFO("Splash: init");    
    
    tex = engine.cache.load!(Texture)("res/textures/uv_grid.png");
    mdl = engine.cache.load!(ModelAsset)("res/models/male.bin");

    program.create(shader_v, shader_f);
    assert(program.is_compiled, "can't compile shader");

    create_cube_mesh(&cube_mesh);
}

void splash_render(State* state, float dt)
{
    auto renderer = &engine.renderer;
        
    if (engine.input.is_key_just_pressed(Key.KEY_A))
    {
    }
    if (engine.input.is_key_just_pressed(Key.KEY_SPACE))
    {
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
        renderer.spritebatch.draw(&tex.tex, 32,32, 128, 128);
    }
    renderer.spritebatch.end(); 
}