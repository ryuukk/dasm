module world.map;

import rt.math;
import rt.collections.array;
import rt.collections.hashmap;
import rt.dbg;
import rt.memz;
import rt.math;
import rt.filesystem;

import dawn.gfx;
import dawn.ecs;
import dawn.mesh;
import dawn.renderer;
import dawn.assets;
import dawn.texture;
import dawn.model;
import dawn.ecs;

import world.tiles;
import world.renderer;

import tiles_bank = defs.tile_def;

// TODO: i don't like this
bool fs_loaded;
bool vs_loaded;
bool fs_compiled;
bool vs_compiled;
bool fs_load_error;
bool vs_load_error;
char[] fs;
char[] vs;

struct UV
{
    float x; float y;
}
enum _uv(int x, int y)
{
    UV ret = void;
    ret.x = x / 112.0;
    ret.y = y / 48.0;
    return ret;
}
UV[] autotile_uvs = [
    _uv(0,0), _uv(1,0), _uv(2,0),_uv(3,0),_uv(4,0),_uv(5,0),_uv(6,0), 
    _uv(0,1), _uv(1,1), _uv(2,1),_uv(3,1),_uv(4,1),_uv(5,1),_uv(6,1), 
    _uv(0,2), _uv(1,2), _uv(2,2),_uv(3,2),_uv(4,2),_uv(5,2),_uv(6,2), 
];

float cam_pos_h = 8.16;
float cam_pos_d = 5.12;

struct TexArrayBufferAsset
{
    import dawn.image;
    Resource base;

    int targetDepth;
    bool added;

    IFImage img;
    
    void create(char[256] path, ResourceCache* cache)
    {
        base.create(path, cache);
        base.vt_load = &load;
        base.vt_unload = &unload;
    }

    void unload(Resource* resource)
    {
        img.free();
    }

    bool load(uint size, const(ubyte)* buffer)
    {
        img = read_image(buffer[0 .. size]);
        if (img.e)
        {
            LERRO("decode error: {} file: {}", IF_ERROR[img.e], base.path);
            return false;
        }
        return true;
    }
}

struct Map
{
    Tile[] tiles;
    Chunk[] chunks;
    bool[] collision;
    int width;
    int height;
    int num_chunks_x;
    int num_chunks_y;

    Registry registry;

    ShaderProgram program;
    Material material;
    Texture2D texture;
    ubyte[] debug_tex_buffer = cast(ubyte[]) import("res/textures/tileset/debug.png");

    ModelAsset* model;
    EntityRenderer entity_renderer;

    float test_rotation = 0;

    Mesh cube_mesh;

    // net state
    entity_t player;
    int player_net_id;

    int last_tick_id;
    int last_tick_time;

    ubyte[1024 * 12] buffer_snd = 0;
    enum ConnectState { DISCONNECTED, CONNECTING, CONNECTED }
    ConnectState state;
    char[32] access_token = 0;
    float connect_timer = -1;
    char[12] host = "127.0.0.1";
    ushort port = 7979;

    HashMap!(int, int) tile_type_to_tex_depth;
    HashMap!(int, TexArrayBufferAsset*) loaded_texs;
    int next_texture_depth = 0;

    void create(int width, int height)
    {
        tiles_bank.initialize(engine.allocator);
        tile_type_to_tex_depth.create(engine.allocator);
        loaded_texs.create(engine.allocator);
        this.width = width;
        this.height = height;

        tiles = engine.allocator.alloc_array!(Tile)(width * height);
        collision = engine.allocator.alloc_array!(bool)(width * height);

        tiles[] = Tile.init;
        collision[] = false;
        
        num_chunks_x = width < CHUNK_SIZE ? 1 : width / CHUNK_SIZE;
        num_chunks_y = height < CHUNK_SIZE ? 1 : height / CHUNK_SIZE;
        chunks = engine.allocator.alloc_array!(Chunk)(num_chunks_x * num_chunks_y);
        chunks[] = Chunk.init;

        for (int i = 0; i < chunks.length; i++)
        {
            int x = i % num_chunks_x;
            int y = i / num_chunks_x;
            chunks[i].create(&this, x, y);

            LINFO("create chunk at {}:{} {}", x, y, chunks[i].mesh.autobind);
        }
        

        LINFO("created map of size: {}:{} chunks: {}:{}", width, height, num_chunks_x, num_chunks_y);


        registry.create(engine.allocator);
        
        // create dbg tex
        import dawn.image: read_image;
        auto im = read_image(debug_tex_buffer, 4);
        scope(exit) im.free();


        // size = 112:48
        texture = create_texture_array(112, 48, 256);
        add_texture(&texture, 0, im.buf8.ptr);
        debug check_gl_error();

        create_cube_mesh(&cube_mesh);

        reload_shader();

        model = engine.cache.load!(ModelAsset)("res/models/male.dat");
        entity_renderer.create();


        create_player();
        // create_cubes();
    }

    void reload_shader()
    {
        engine.cache.fs.get_content_async( "res/shaders/map.fs", (l, b, ok) {
            if (ok)
            {
                fs_load_error = false;
                fs_loaded = true;
                if (fs.ptr) engine.allocator.free(fs.ptr);
                fs = dupe(engine.allocator, cast(char[]) b[0 .. l]); 
            }
            else
            {
                fs_load_error = true;
            }
        });
        engine.cache.fs.get_content_async( "res/shaders/map.vs", (l, b, ok) {
            if (ok)
            {
                vs_load_error = false;
                vs_loaded = true;
                if (vs.ptr) engine.allocator.free(vs.ptr);
                vs = dupe(engine.allocator, cast(char[]) b[0 .. l]); 
            }
            else
            {
                vs_load_error = true;
            }
        });
    }

    void dispose()
    {
        registry.dispose();
        engine.allocator.free(tiles.ptr);
        program.dispose();
        texture.dispose();
        cube_mesh.dispose();

        foreach(pair; loaded_texs)
        {
            pair.value.base.decrement_ref_count();
        }
        loaded_texs.clear();
        tile_type_to_tex_depth.clear();

        entity_renderer.dispose();
    }

    int lastt;
    void tick(int time, int dt)
    {
        if (time - lastt > 5000)
        {
            LINFO("FPS: {}  {}", engine.fps, engine.tick_time);
            lastt = time;
        }

        if (engine.input.is_key_just_pressed(Key.KEY_SPACE))
        {
            LINFO("reload map shader");
            reload_shader();
        }

        if (engine.input.is_key_just_pressed(Key.KEY_F))
        {
            static int type = 0;
            scope(exit) type++;
            if (type >= tiles_bank.tile_defs.length) type = 0;
            
            LINFO("fill map with index: {}", type);
            
            for (int x = 0; x < width; x++)
            for (int y = 0; y < height; y++)
            {
                set_tile(x, y, type);
            }
        }

        if (vs_loaded && fs_loaded)
        {

            ShaderProgram newp;
            newp.create(vs, fs);
            if (newp.is_compiled)
            {
                if (program.is_compiled)
                {
                    LINFO("dispose old shader {}", program.program);
                    program.dispose();
                }

                LINFO("new map shader compiled {}", newp.program);
                program = newp;
                fs_compiled = true;
                vs_compiled = true;
            }
            else 
            {
                LERRO("unnable to compile new map shader\n{}", newp.log);
                fs_compiled = false;
                vs_compiled= false;    
            }

            fs_loaded = false;
            vs_loaded = false;
        }

        foreach(pair; loaded_texs)
        {
            if (pair.value.base.is_ready() && !pair.value.added)
            {
                pair.value.added = true;
                
                add_texture(&texture, pair.value.targetDepth, pair.value.img.buf8.ptr);
            }
        }

        test_rotation += (dt / 1000.0);

        system_input(&this, time, dt);
        system_movement(&this, time, dt);
        system_camera(&this, time, dt);

        system_render_map(&this, time, dt);
        system_render(&this, time, dt);

        system_load_model(&this, time, dt);
    }

    void set_tile(int x, int y, int type)
    {
        auto tile = get_tile(x, y);
        if (!tile) return;

        tile.type = type;

        // TODO: the plan
        //  - get tile def
        //  - get texture asset
        //  - get textureIndex
        //  - update auto tiling

        int texIndex = 0;
        if (tile_type_to_tex_depth.has(type))
        {
            texIndex = tile_type_to_tex_depth[type];
        }
        else 
        {
            // TODO: handle errors
            
            if (loaded_texs.has(type))
            {
                auto asset = loaded_texs[type];
                texIndex = asset.targetDepth;
            }
            else
            {
                auto data = tiles_bank.defs[type];
                
                texIndex = next_texture_depth;

                next_texture_depth++;
                auto targetDepth = texIndex;
                auto asset = engine.cache.load!(TexArrayBufferAsset)(data.texture);
                asset.targetDepth = targetDepth;
                loaded_texs.set(type, asset);
            }
        }
        

        auto chunk = get_chunk(x, y);
        
        int localX = cast(int) (x % cast(float)CHUNK_SIZE);
        int localY = cast(int) (y % cast(float)CHUNK_SIZE);

        auto sizeX = 16.0 / 112.0;
        auto sizeY = 16.0 / 48.0;
        
        chunk.set(localX, localY, texIndex, sizeX, sizeY, sizeX*2, sizeY*2);
    }

    Chunk* get_chunk(int x, int y)
    {
        if (x < 0 || x >= width || y < 0 || y >= height)
            return null;

        int chunkPosX = cast(int) (num_chunks_x * (x / cast(float) width));
        int chunkPosY = cast(int) (num_chunks_y * (y / cast(float) height));

        int i = chunkPosX + chunkPosY * num_chunks_x;
        return &chunks[i];
    }

    Tile* get_tile(int x, int y)
    {
        if (x < 0 || x >= width || y < 0 || y >= height)
            return null;

        int i = x + y * width;
        return &tiles[i];
    }

    bool update_auto_tile(Tile* tile, int x, int y, int type)
    {
        bool match(int x, int y, int type)
        {
            auto t = get_tile(x, y);
            if (!t) return false;
            
            return tile.type == type;
        }
        // TODO: i had to swap top and bottom for UV, i must know what's going on really
        // AUTOTILE 4 BITS
        ubyte top    = match(x, y + 1, type);
        ubyte left   = match(x - 1, y, type);
        ubyte right  = match(x + 1, y, type);
        ubyte bottom = match(x, y - 1, type);
        int id     = top + 2 * left + 4 * right + 8 * bottom;
        if (tile.autotile_id != id)
        {
            tile.autotile_id = id;
            return true;
        }
        return false;
    }

    bool isInside(int x, int y)
    {
        if (x < 0 || x >= width || y < 0 || y >= height)
            return false;
        return true;
    }

    void create_player()
    {
        entity_t entity = registry.create_entity();
        registry.add(entity, CTransform( v3(0,0,0), 0.0, 1.0 ) );
        registry.add(entity, CLoadModel(entity, engine.cache.load!(ModelAsset)("res/models/male.dat")));
        registry.add(entity, FControllable());
        registry.add(entity, CPlayer());
        registry.add(entity, CVelocity());
        registry.add(entity, CNetworked());
    }

    void create_cubes()
    {
        enum SIZE = 8;
        int count;
        for (int x = -SIZE;  x < SIZE; x++)
        for (int y = -SIZE;  y < SIZE; y++)
        {
            entity_t entity = registry.create_entity();
            registry.add(entity, CTransform( v3(x, -1, y) , 0.0, 1.0 ) );
            registry.add(entity, CCube());
            count++;
        }
        LINFO("added: {} cubes", count);
    }
}

void system_input(Map* map, int time, int dt)
{
    auto registry = &map.registry;
    foreach(view, e; registry.view!(Includes!(FControllable, CPlayer, CVelocity, CModel)))
    {
        auto player = view.get!(CPlayer)(e);
        auto vel = view.get!(CVelocity)(e);
        auto mdl = view.get!(CModel)(e);

        // update key state
        foreach(Event* e; engine.queue)
        {
            switch (e.type) with (EventType)
            {
                case INPUT_KEY_DOWN:
                    if (e.key_down.key == Key.KEY_W)
                        player.up = true;
                    else if (e.key_down.key == Key.KEY_A)
                        player.left = true;
                    else if (e.key_down.key == Key.KEY_S)
                        player.down = true;
                    else if (e.key_down.key == Key.KEY_D)
                        player.right = true;
                break;
                case INPUT_KEY_UP:
                    if (e.key_up.key == Key.KEY_W)
                        player.up = false;
                    else if (e.key_up.key == Key.KEY_A)
                        player.left = false;
                    else if (e.key_up.key == Key.KEY_S)
                        player.down = false;
                    else if (e.key_up.key == Key.KEY_D)
                        player.right = false;
                break;
                default:break;
            }
        }

        // apply to velocity
        bool moved = (player.up || player.down || player.right || player.left);
        if (moved)
        {
            vel.value.x =  (player.right ? 1 : 0) - (player.left ? 1 : 0);
            vel.value.y = (player.down ? 1 : 0) - (player.up ? 1 : 0);
            
            if (mdl.ctrl.target && !mdl.ctrl.animate("Armature|run_00"))
                LERRO("can't find animation idle");
        }
        else
        {
            vel.value = v2(0,0);

            if (mdl.ctrl.target && !mdl.ctrl.animate("Armature|idle_1h"))
                LERRO("can't find animation idle");
        }
    }
}

void system_movement(Map* map, int time, int dt)
{
    auto registry = &map.registry;
    foreach(view, e; registry.view!(Includes!(CTransform, CVelocity, CNetworked)))
    {
        auto trs = view.get!(CTransform)(e);
        auto vel = view.get!(CVelocity)(e);
        auto net = view.get!(CNetworked)(e);
        auto is_player = registry.has!(CPlayer)(e);
        auto is_controlled = registry.has!(FControllable)(e);

        // if it's us, just do it            
        if (is_player && is_controlled)
        {
            v2 dt_vel = vel.value * (dt/1000.0) * 0.4 * 10;
            trs.pos += v3( dt_vel.x, 0, dt_vel.y);

            bool moving = !(dt_vel.x == 0 && dt_vel.y == 0);
            if (moving)
                trs.rot = -atan2f(vel.value.x, vel.value.y);
        }
        else // otherwise, apply interpolation
        { 
            // TODO: use last time?
            auto tickDT = time - net.last_tick_frame_time;
            bool moving = !(vel.value.x == 0 && vel.value.y == 0);
            if (moving)
            {
                trs.rot = -atan2f(vel.value.x, vel.value.y);

                if(net.last_tick_id < map.last_tick_id)
                {
                    LINFO("skip: {} {}", net.last_tick_id, map.last_tick_id);
                    vel.value = v2(0,0);
                    trs.pos = v3( net.tick_pos.x, 0, net.tick_pos.y );
                    // trs.rotation = net.tick_rot;
                }
                else
                {
                    v2 newp = net.pos_at_tick + (vel.value * tickDT);
                    trs.pos = v3(newp.x, 0, newp.y);
                    //trans.position = Vec3.lerp(net.pos_at_tick, net.tick_pos, last_tick_time);

                    // trs.rotation = net.rot_at_tick + (vel.r * tickDT);
                    //trans.rotation = lerp_deg(net.rot_at_tick, net.tick_rot, last_tick_time);
                }
            }
        }
    }
}

void system_camera(Map* map, int time, int dt)
{
    auto registry = &map.registry;
    foreach(view, e; registry.view!(Includes!(FControllable, CTransform)))
    {
        auto trs = view.get!(CTransform)(e);
        auto camera = &engine.renderer.camera;

        camera.position.x = trs.pos.x;
        camera.position.y = trs.pos.y + cam_pos_h;
        camera.position.z = trs.pos.z + cam_pos_d;
        camera.update();
    }
}

void system_load_model(Map* map, int time, int dt)
{
    auto registry = &map.registry;
    foreach (view, e; registry.view!(Includes!(CTransform, CLoadModel)))
    {
        CTransform* tr = view.get!(CTransform)(e);
        CLoadModel* lm = view.get!(CLoadModel)(e);

        if (lm.mdl.base.is_ready())
        {
            ModelAsset* model_asset = lm.mdl;

            CModel model;
            model.instance.load(&model_asset.mdl, engine.allocator);
            model.instance.transform = mat4.set(
                tr.pos,
                quat.fromAxis(0,1,0, tr.rot),
                v3(tr.scale, tr.scale, tr.scale)  
            );
            model.instance.calculate_transforms();


            registry.add(e, model);

            registry.remove!(CLoadModel)(e);

            LINFO("Loaded new model for: {}", e);
        }
    }
}

void system_render_map(Map* map, int time, int dt)
{
    if (map.program.is_compiled == false) return;

    import dawn.gl;
    import rt.str;

    auto chunks = map.chunks;
    auto program = &map.program;
    auto texture = &map.texture;

    for (int i = 0; i < chunks.length; i++)
    {
        auto chunk = &chunks[i];
        if (chunk.dirty)
        {
            LINFO("reupload dirty chunk at {}:{}", chunk.chunkX, chunk.chunkY);
            chunk.upload();
            chunk.dirty = false;
        }


        engine.renderer.state.set_polygon_state(PolygonState.None);
        auto camera = &engine.renderer.camera;
        program.bind();
        // program.set_uniformf("u_time", now().seconds());
        program.set_uniform_mat4("u_projViewTrans", camera.combined);
        program.set_uniform_mat4("u_worldTrans", chunk.transform);
        program.set_uniform4f("u_cameraPosition", camera.position.x, camera.position.y, camera.position.z, 1.1001f / (camera.far * camera.far));

    
        program.set_uniform4f("u_fogColor", 0,0,0,1);

        texture.bind();
        program.set_uniformi("u_diffuseTexture", 0);
        program.set_uniform4f("u_diffuseUVTransform", 0, 0, 1, 1);


        assert(chunk.mesh.autobind);

        chunk.mesh.render(program, GL_TRIANGLES);
        debug check_gl_error();
    }
}

void system_render(Map* map, int time, int dt)
{
    auto registry = &map.registry;
    auto entity_renderer = &map.entity_renderer;
    auto cube_mesh = &map.cube_mesh;

    engine.renderer.state.set_depth_state(DepthState.Default);

    foreach (it, e; registry.view!(Includes!(CTransform, CModel)))
    {
        auto trans = it.get!(CTransform)(e);
        auto mdl = it.get!(CModel)(e);
        if (mdl.ctrl.target == null)
            mdl.ctrl.target = &mdl.instance;

        mdl.ctrl.update(dt/1000.0);

        // fix rotation because model is broken
        auto rot = quat.mult(quat.fromAxis(1,0,0, PIDIV2),  quat.fromAxis(0,0,1, trans.rot));
        
        mdl.instance.transform = mat4.set(trans.pos, rot, v3(trans.scale, trans.scale, trans.scale));
        entity_renderer.render(&mdl.instance);
    }
    
    foreach (it, e; registry.view!(Includes!(CTransform, CCube)))
    {
        auto trans = it.get!(CTransform)(e);
        auto cube = it.get!(CCube)(e);


        trans.rot += (dt / 1000.0);

        entity_renderer.render(cube_mesh, 
            mat4.set(
                trans.pos,
                quat.fromAxis(0,1,0, trans.rot),
                v3(trans.scale, trans.scale, trans.scale)
            )            
        );
    }
    entity_renderer.flush(&engine.renderer.camera);        
}

struct CModel
{
    ModelInstance instance;
    AnimationController ctrl;
}

struct CCube
{}

struct CLoadModel
{
    entity_t entity;
    ModelAsset* mdl;
}

struct CTransform
{
    v3 pos;
    float rot = 0.0;
    float scale = 1.0;
}

struct CPlayer
{
    // input state
    bool up;
    bool down;
    bool left;
    bool right;
}

struct CNetworked
{
    int last_tick_frame_time;
    int last_tick_id = -1;
    v2 tick_pos;
    v2 pos_at_tick;
}

struct FControllable{}

struct CVelocity
{
    v2 value;
}

