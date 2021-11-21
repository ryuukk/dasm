module game.window;


version(WASM)
{
    import wasm;

    void create_window(int width, int height)
    {
        
        WAJS_setup_canvas(width, height);
    }
}
else
{
    void create_window(int width, int height)
    {

    }
}