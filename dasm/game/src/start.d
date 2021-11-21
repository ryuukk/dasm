module game.start;

import dbg;

import window;
import gl;
import memory;

void start()
{
    writelnf("Create canvas!");

    create_window(800, 600);

    writelnf("Canvas created!");
}

version(WASM)
{
    export extern(C) void WA_render()
    {
        render();
    }
}

struct Vertex
{
    float[2] pos;
}


void render()
{
   

	version(WASM)
    {
        import wasm;
        float f = (( WAJS_get_time() % 1000) / 1000.0f);
    }
    else float f = 0;

    
    Vertex a  = Vertex( [0,0] );
    Vertex b  = Vertex( [0,0] );
    auto c = a == b;
    if (c)
        writelnf("hi!!!");

    glViewport(0,0,800,600);
	glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(f, 0, 0, 1);
    
}
