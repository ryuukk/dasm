import dbg;
import window;
import gl;
import math;
import time;

import mesh;

const(char)[] shader_v = q{
	precision lowp float;
	uniform mat4 uMVP;
	attribute vec4 aPos;
	attribute vec3 aCol;
	varying vec3 vCol;
	void main()
	{
		vCol = aCol;
		gl_Position = uMVP * aPos;
	}
};

const(char)[] shader_f = q{
	precision lowp float;
	varying vec3 vCol;
	void main()
	{
		gl_FragColor = vec4(vCol, 1.0);
	}
};

ShaderProgram program;
float a;


void test(T)(T value)
{

}

void main()
{
    writeln("main() found");
    start();
}

void start()
{
    writelnf("Create canvas!");

    create_window(800, 600);

    writelnf("Canvas created!");


	program.create(shader_v, shader_f);
	
	assert(program.is_compiled);
}


void render()
{
    float f = ((get_time() % 1000) / 1000.0f);

    glViewport(0, 0, 800, 600);
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0.2, 0.2, 0.2, 1);


}

version (WASM)
{
    export extern (C) void WA_render()
    {
        render();
    }
}