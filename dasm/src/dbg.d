module dbg;


import string;

version (WASM)
{
    import wasm;
}
else
{
    import core.stdc.stdio;
}


void log(const char* txt)
{
    version(WASM)
    {
        WAJS_log(txt, str_len(txt));

        
    }
    else
    {
        printf("%s\n", txt);
    }
}