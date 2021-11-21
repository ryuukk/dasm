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


void render()
{
	version(WASM)
    {
        import wasm;
        float f = (( WAJS_get_time() % 1000) / 1000.0f);
    }
    else float f = 0;

    glViewport(0,0,800,600);
	glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(f, 0, 0, 1);
}
