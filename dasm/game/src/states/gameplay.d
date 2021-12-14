module states.gameplay;

import app;

import rt.dbg;

import dawn.gfx;
import dawn.ecs;
import dawn.mesh;
import dawn.renderer;
import dawn.assets;
import dawn.texture;
import dawn.model;
import rt.math;
import rt.memz;
import rt.collections.array;
import rt.collections.hashmap;
import rt.time;

import world.map;
import world.entities;


Map map;
int last_update;

void gameplay_init(State* state)
{
    LINFO("Gameplay: init");
    map.create(128, 128);
    last_update = now().msecs_i(); 
}

void gameplay_render(State* state, float dt)
{
    int time = now().msecs_i();
    int dt_ms = time - last_update;

    map.tick(time, dt_ms);

    last_update = time;
}
