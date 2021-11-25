import dbg;
import gfx;
import gl;
import math;
import time;

import mesh;
import camera;
import fs;

const(char)[] shader_v = "
	#ifdef GL_ES
	precision lowp float;
	#endif	
	uniform mat4 u_mvp;
	uniform mat4 u_transform;
	attribute vec4 a_position;
	attribute vec3 a_normal;
	varying vec3 v_col;
	void main()
	{
		v_col = a_normal;
		gl_Position = u_mvp * u_transform * a_position;
	}
";

const(char)[] shader_f = "
	#ifdef GL_ES
	precision lowp float;
	#endif	
	varying vec3 v_col;
	void main()
	{
		gl_FragColor = vec4(v_col, 1.0);
	}
";


Manager assets;
ShaderProgram program;
Mesh cube_mesh;
Camera cam;
mat4 transform = mat4.identity;
float a = 0;

void main()
{
	writeln("main() found");

	create_engine(800, 600, &on_start, &on_exit, &on_tick);

	Handle* handle = assets.load("res/hello.txt");	
}


void on_start(Engine* e)
{
	cam = Camera.init_perspective(60, engine.width, engine.height);
	cam.near = 0.1;
	cam.far = 35.0;
	//cam.position = v3(0, 10, 6) * 0.6;
	//cam.rotate(v3(1,0,0), -45);

	cam.position = v3(0, 10, 5) * 0.6;
	cam.look_at(0, 0, 0);

	program.create(shader_v, shader_f);
	assert(program.is_compiled, "can't compile shader");

	create_cube_mesh(&cube_mesh);

	writeln("Cube vb.buffer:{} vb.vao:{}", cube_mesh.vb.buffer_handle, cube_mesh.vb.vao_handle);
	writeln("Cube ib.buffer:{}", cube_mesh.ib.handle);

	// import memory;
	// auto m = malloc(5);
	// uint buffer = 999;
	// glGenBuffers(1, &buffer);
	// writeln("Buffer: {}", buffer);
}

void on_exit(Engine* e)
{
}

void on_tick(Engine* e, float dt)
{
	glViewport(0, 0, 800, 600);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glClearColor(0.2, 0.2, 0.2, 1);

	glEnable(GL_DEPTH_TEST);


	foreach(Event* e; engine.queue)
	{
		switch (e.type)
		{
			case EventType.INPUT_TOUCH_DOWN:
				writeln("INPUT_TOUCH_DOWN: {} -> {}:{}", cast(Mouse)e.touch_down.button, e.touch_down.screen_x, e.touch_down.screen_y);
			break;
			case EventType.INPUT_TOUCH_UP:
				writeln("INPUT_TOUCH_UP: {} -> {}:{}", cast(Mouse)e.touch_up.button, e.touch_up.screen_x, e.touch_up.screen_y);
			break;

			default: break;
		}
	}


	a += 5 * dt;
	transform = mat4.set(v3(0, 0, 0), quat.fromAxis(0, 1, 0, a), v3(1, 1, 1));

	cam.update();

	program.bind();
	program.set_uniform_mat4("u_mvp", &cam.combined);
	program.set_uniform_mat4("u_transform", &transform);

	cube_mesh.render(&program, GL_TRIANGLES);
}
