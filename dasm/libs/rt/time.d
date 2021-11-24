module time;

version(WASM)
{
    import wasm;
}
else
{
    import core.stdc.stdio;
}


uint get_time()
{
    version(WASM) return WAJS_get_time();
    else return 0;
}

uint get_elapsed_time()
{
    version(WASM) return WAJS_get_elapsed_time();
    else return 0;
}
