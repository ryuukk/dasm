import dbg;
import gfx;
import gl;
import math;
import time;
import memory;

import mesh;
import camera;
import assets;

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
ResourceCache cache;
ShaderProgram program;
Mesh cube_mesh;
mat4 transform = mat4.identity;
float a = 0;
Texture* tex;

void main()
{
	writeln("main() found");

	create_engine(800, 600, &on_start, &on_exit, &on_tick);
}


void on_start(Engine* e)
{    
    // load_file_async("res/fonts/kreon-regular.ttf", 0, (id, ptr, len, ok) {
    //     import memory;

    //     FontConfig font_config = {
    //         size: 14,
    //         outline: true,
    //         outline_size: 1,
    //         color: Colorf.WHITE,
    //         color_outline: Colorf.BLACK,
    //         gradient: false,
    //         file_data: cast(ubyte[])ptr[0 .. len],
    //     };

    //     fnt.load(MALLOCATOR.ptr(), font_config);

    //     writeln("Font: {}:{}", fnt.atlas_width, fnt.atlas_height);
        
    //     free(ptr);
    // });

	cache.create();
	
	tex = cache.load!(Texture)("res/hello.txt");

	assert(tex);

	program.create(shader_v, shader_f);
	assert(program.is_compiled, "can't compile shader");

	create_cube_mesh(&cube_mesh);
}

void on_exit(Engine* e)
{
	writeln("--end");
}

void on_tick(Engine* e, float dt)
{
	cache.process();

    if (engine.input.is_key_just_pressed(Key.KEY_A))
    {
        writeln("test");
    }
    if (engine.input.is_key_just_pressed(Key.KEY_SPACE))
    {
        writeln("Space!");
    }

	a += 5 * dt;
	transform = mat4.set(v3(0, 0, 0), quat.fromAxis(0, 1, 0, a), v3(1, 1, 1));

	renderer.camera.update();

	program.bind();
	program.set_uniform_mat4("u_mvp", &renderer.camera.combined);
	program.set_uniform_mat4("u_transform", &transform);
    

	cube_mesh.render(&program, GL_TRIANGLES);


    renderer.spritebatch.begin();
	
    renderer.spritebatch.end();    
}

version(NONE):
    import core.memory;
    extern (C) __gshared string[] rt_options = ["gcopt=initReserve:0 profle:1"];

    extern (C) void* gc_malloc(size_t sz, uint ba = 0, const TypeInfo = null)
    {
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : abort;

        printf("no gc_malloc\n");
        abort();
    }

    extern (C) void* gc_calloc(size_t sz, uint ba = 0, const TypeInfo = null)
    {
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : abort;

        printf("no gc_calloc\n");
        abort();
    }

    extern (C) auto gc_qalloc(size_t sz, uint ba = 0, const TypeInfo = null)
    {
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : abort;

        printf("no gc_qalloc\n");
        abort();
    }