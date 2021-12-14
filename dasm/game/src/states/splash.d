module states.splash;

import app;

import rt.dbg;
import rt.math;
import rt.time;
import rt.memz;
import rt.dbg;

import dawn.gfx;
import dawn.renderer;
import dawn.gl;
import dawn.mesh;
import dawn.camera;
import dawn.assets;
import dawn.font;


void splash_init(State* state)
{
    LINFO("Splash: init");
    
}

void splash_render(State* state, float dt)
{
    set_state(StateID.GAMEPLAY);
}
