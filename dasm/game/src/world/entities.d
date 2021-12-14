module world.entities;

import rt.math;

import dawn.assets;
import dawn.model;


import world.map;

version(NONE):


enum EntityKind 
{
    BASIC,
    PROJECTILE,
    GAMEOBJECT,
    PLAYER,
}

struct Entity
{
    EntityKind kind;
    int id;
    int type;
    v2 pos;
    float rot = 0;
    float scale = 1;
    Map* map;
    Tile* tile;
}

struct Projectile
{
    Entity base = {kind: EntityKind.PROJECTILE};
    
}

struct GameObject
{
    Entity base = {kind: EntityKind.GAMEOBJECT};
    alias base this;
    
    bool dead;
    int level;
    int hp;
    int hp_max;

    int mp;
    int mp_max;

    int str;
    int agi;
    int vit;
    int wis;

    int last_tick_time;
    int last_tick_id = -1;
    v2 pos_at_tick;
    v2 pos_tick;
    v2 vel;

    ModelAsset* model;
    AnimationController anim_control;
}


struct Player
{
    GameObject base = {base: {kind: EntityKind.PLAYER}};
}


bool add_to(Entity* entity, Map* map, v2 pos)
{

    if (entity.kind == EntityKind.GAMEOBJECT)
    {
        GameObject* go = cast(GameObject*) entity;
        go.pos_at_tick = pos;
        go.pos_tick = pos;
    }

    entity.map = map;
    entity.tile = map.get_tile(cast(int)pos.x, cast(int)pos.y);
    if (!entity.tile) return false;

    entity.pos = pos;
    return true;
}