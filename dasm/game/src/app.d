import dbg;
import window;
import gl;
import math;

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

    uint vertex_shader = glCreateShader(GL_VERTEX_SHADER);
    writeln("Vertex Shader: {}", vertex_shader);

	glShaderSource(vertex_shader, 1, &vertex_shader_text, null);
	glCompileShader(vertex_shader);

	uint fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
    writeln("Fragment Shader: {}", fragment_shader);
	glShaderSource(fragment_shader, 1, &fragment_shader_text, null);
	glCompileShader(fragment_shader);

	program = glCreateProgram();
    writeln("Program: {}", program);


	glAttachShader(program, vertex_shader);
	glAttachShader(program, fragment_shader);
	glLinkProgram(program);

    writeln("Program supposed to be linked");

	uMVP_location = glGetUniformLocation(program, "uMVP");
	aPos_location = glGetAttribLocation(program, "aPos");
	aCol_location = glGetAttribLocation(program, "aCol");

	glGenBuffers(1, &vertex_buffer);
	glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);

	glEnableVertexAttribArray(aPos_location);
	glVertexAttribPointer(aPos_location, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)0);
	glEnableVertexAttribArray(aCol_location);
	glVertexAttribPointer(aCol_location, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)(float.sizeof * 2));
}

version (WASM)
{
    export extern (C) void WA_render()
    {
        render();
    }
}


const(char)* vertex_shader_text = q{
	precision lowp float;
	uniform mat4 uMVP;
	attribute vec4 aPos;
	attribute vec3 aCol;
	varying vec3 vCol;
	void main()
	{
		vCol = aCol;
		gl_Position = uMVP * aPos;
	}};

const(char)* fragment_shader_text = q{
	precision lowp float;
	varying vec3 vCol;
	void main()
	{
		gl_FragColor = vec4(vCol, 1.0);
	}};


struct Vertex { float x, y, r, g, b; }
uint program, vertex_buffer;
int uMVP_location, aPos_location, aCol_location;

void render()
{
    version (WASM)
    {
        import wasm;

        float f = ((WAJS_get_time() % 1000) / 1000.0f);
    }
    else
        float f = 0;

    glViewport(0, 0, 800, 600);
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0.2, 0.2, 0.2, 1);

    Vertex[3] vertices =
	[
		Vertex( -0.6f, -0.4f, 1.0f, 0.0f, 0.0f ),
		Vertex(  0.6f, -0.4f, 0.0f, 0.0f, 1.0f ),
		Vertex(  0.0f,  0.6f, 1.0f, 1.0f, 1.0f ),
    ];
	vertices[0].r = 0.5f + sinf(f * 3.14159f * 2.0f) * 0.5f;
	vertices[1].b = 0.5f + cosf(f * 3.14159f * 2.0f) * 0.5f;

	glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
	glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

	GLfloat[4*4] mvp = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1 ];
	glUseProgram(program);
	glUniformMatrix4fv(uMVP_location, 1, GL_FALSE, mvp.ptr);
	glDrawArrays(GL_TRIANGLES, 0, 3);

}
