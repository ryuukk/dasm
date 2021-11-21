module dawn.src.time;

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
    return 0;
}
