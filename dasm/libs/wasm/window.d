module window;

import wasm;


void create_window(int width, int height)
{
    WAJS_setup_canvas(width, height);
}