
version(WASM) import game.start;
else version(DESKTOP) import game.start;
else version(LOGIN) import login.start;
else version(SERVER) import server.start;

import object;
import dbg;

version(WASM)
{
    void main() 
    {
        log("main found");

        //start();
        float[2] aaaaa_a = 5; 
        float[2] aaaaa_b = 5;

        float[2] a = 5; 
        float[2] b = 5;

        
        bool ok = a == b;
        if(ok) log("ok");
        else log("no"); 
    }
}
else
{
    void main()
    {
        // start();

        float[2] a = 5; 
        float[2] b = 5;
        bool ok = a == b;
        if(ok) log("ok");
        else log("no"); 
    }
}