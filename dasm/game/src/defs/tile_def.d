module defs.tile_def;

import rt.memz;
import rt.collections.hashmap;

struct TileDef
{
    int type;
    string id;
    char[256] texture;
    bool no_walk;   
}


TileDef[] tile_defs = 
[
    { type:  0, id: "debug", texture: "res/textures/tileset/debug.png", },
    { type:  1, id: "deeper_ocean", texture: "res/textures/tileset/deeper_ocean.png", },
    { type:  2, id: "shallow_ocean", texture: "res/textures/tileset/shallow_ocean.png", },
    { type:  3, id: "coast", texture: "res/textures/tileset/coast.png", },
    { type:  4, id: "beach", texture: "res/textures/tileset/beach.png", },
    { type:  5, id: "grassland", texture: "res/textures/tileset/grassland.png", },
    { type:  6, id: "lake", texture: "res/textures/tileset/lake.png", },
    { type:  7, id: "lakeshore", texture: "res/textures/tileset/lakeshore.png", },
    { type:  8, id: "marsh", texture: "res/textures/tileset/marsh.png", },
    { type:  9, id: "ocean", texture: "res/textures/tileset/ocean.png", },
    { type: 10, id: "river", texture: "res/textures/tileset/river.png", },
    { type: 11, id: "scorched", texture: "res/textures/tileset/scorched.png", },
    { type: 12, id: "shrubland", texture: "res/textures/tileset/shrubland.png", },
    { type: 13, id: "subtropical_desert", texture: "res/textures/tileset/subtropical_desert.png", },
    { type: 14, id: "taiga", texture: "res/textures/tileset/taiga.png", },
    { type: 15, id: "temperate_deciduous_forest", texture: "res/textures/tileset/temperate_deciduous_forest.png", },
    { type: 16, id: "temperate_desert", texture: "res/textures/tileset/temperate_desert.png", },
    { type: 17, id: "temperate_rain_forest", texture: "res/textures/tileset/temperate_rain_forest.png", },
    { type: 18, id: "tropical_rain_forest", texture: "res/textures/tileset/tropical_rain_forest.png", },
    { type: 19, id: "tropical_seasonal_forest", texture: "res/textures/tileset/tropical_seasonal_forest.png", },
    { type: 20, id: "tundra", texture: "res/textures/tileset/tundra.png", },
    { type: 21, id: "bare", texture: "res/textures/tileset/bare.png", },
    { type: 22, id: "snow", texture: "res/textures/tileset/snow.png", },
];

HashMap!(int, TileDef*) defs;
bool initialized;

void initialize(Allocator* allocator)
{
    if (initialized) return;
    initialized = true;

    defs.create(allocator);

    for (int i = 0; i < tile_defs.length; i++)
    {
        auto td = &tile_defs[i];
        defs.set(td.type, td);
    }
}