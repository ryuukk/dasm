module world.map;

import rt.math;
import rt.collections.array;
import rt.collections.hashmap;
import rt.dbg;
import rt.memz;
import rt.math;

import dawn.gfx;
import dawn.ecs;
import dawn.mesh;
import dawn.renderer;
import dawn.assets;
import dawn.texture;
import dawn.model;
import dawn.ecs;

import world.entities;
import world.renderer;

// TODO: i don't like this
bool fs_loaded;
bool vs_loaded;
bool fs_compiled;
bool vs_compiled;
bool fs_load_error;
bool vs_load_error;
char[] fs;
char[] vs;


struct Tile
{
    int x;
    int y;
    int type;
    int entity_id;
    bool no_walk;
}

enum CHUNK_SIZE = 128;
enum TILE_SIZE  = 1;
struct Chunk
{
    enum NUM_VERTICES = 9;

    int chunkX;
    int chunkY;
    int worldX;
    int worldY;

    Mesh mesh;
    Material mat;
    bool dirty;
    float[] _vertices;
    int[] _indicies;
    int numVertices;
    Map* map;

    mat4 transform;

    void create(Map* map, int chunkX, int chunkY)
    {
        this.map = map;
        this.chunkX = chunkX;
        this.chunkY = chunkY;

        worldX = chunkX * CHUNK_SIZE * TILE_SIZE;
        worldY = chunkY * CHUNK_SIZE * TILE_SIZE;

        auto tiles = CHUNK_SIZE * CHUNK_SIZE;
        auto vertCount  = CHUNK_SIZE * CHUNK_SIZE * 4;
        auto indexCount = CHUNK_SIZE * CHUNK_SIZE * 6;
        numVertices = vertCount;

        _vertices = engine.allocator.alloc_array!float(vertCount * NUM_VERTICES);
        _indicies = engine.allocator.alloc_array!int(indexCount);


        int vOffset = 0;
        int iOffset = 0;

        for (int i = 0; i < tiles; i++)
        {
            _indicies[iOffset + 0] = (2 + vOffset);
            _indicies[iOffset + 1] = (0 + vOffset);
            _indicies[iOffset + 2] = (1 + vOffset);
            
            _indicies[iOffset + 3] = (1 + vOffset);
            _indicies[iOffset + 4] = (3 + vOffset);
            _indicies[iOffset + 5] = (2 + vOffset);

            vOffset += 4;
            iOffset += 6;
        }
        for (int x = 0; x < CHUNK_SIZE; x++)
        {
            for (int y = 0; y < CHUNK_SIZE; y++)
            {
                set_height(x, y, 0.0);
            }                
        }
        VertexAttributes attrs;
        attrs.add(VertexAttribute.position3D());
        attrs.add(VertexAttribute.normal());
        attrs.add(VertexAttribute.tex_coords(0));
        attrs.add(VertexAttribute.tex_index());
        mesh.create(false, vertCount, indexCount, attrs);

        mesh.vb.set_data(_vertices, 0, cast(int) _vertices.length);
        mesh.ib.set_data(_indicies, 0, cast(int) _indicies.length);

        transform = mat4.createTranslation(worldX,0, worldY);
    }

    void dispose()
    {
        mesh.dispose();
    }

    void set_height(int x, int y, float height)
    {
        dirty = true;
        int index = (x + y * CHUNK_SIZE) * 4 * NUM_VERTICES;
        int wx = x * TILE_SIZE;
        int wy = y * TILE_SIZE;
        int ts = TILE_SIZE;
        
        int acc = 0;
        // 1
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            acc++;
        }
        // 2
        {
            // pos
            _vertices[index + acc++] = wx + ts;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            acc++;
        }
        // 3
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            acc++;
        }
        // 4
        {
            // pos
            _vertices[index + acc++] = wx+ts;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            acc++;
        }
    }



    int getTileIndex(int x, int y)
    {
        return (x + y * CHUNK_SIZE) * 4 * NUM_VERTICES;
    }

    void upload()
    {
        mesh.vb.set_data(_vertices, 0, cast(int) _vertices.length);
    }
}

struct TileInfo
{
    int start_index;
    int length;
}

struct Map
{
    Tile[] tiles;
    int width;
    int height;

    Registry registry;

    Mesh mesh;
    ShaderProgram program;
    Texture2D texture;
    ubyte[] pixel_buffer;

    ModelAsset* model;
    ModelInstance instance;
    AnimationController controller;

    EntityRenderer entity_renderer;

    float test_rotation = 0;

    Mesh cube_mesh;

    float[] vertices;
    

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

    void create(int width, int height)
    {
        this.width = width;
        this.height = height;

        registry.create(engine.allocator);
        

        int numVertices = (width * height) * ( (3 + 3 + 2) * 16 );

        VertexAttributes attrs;
        attrs.add(VertexAttribute.position3D());
        attrs.add(VertexAttribute.normal());
        attrs.add(VertexAttribute.tex_coords(0));

        mesh.create(false, numVertices, 0, attrs);

        vertices = engine.allocator.alloc_array!float(numVertices);
        mesh.vb.set_data(vertices, 0, cast(int)vertices.length);

        // create tmp tex
        pixel_buffer = engine.allocator.alloc_array!ubyte(2048 * 2048 * 4);
        for (int x = 0; x < 2048; x++)
        for (int y = 0; y < 2048; y++)
        {
            int index = x + y * 2048;
            pixel_buffer[index + 0] = cast(ubyte)rand_range(0, 255);
            pixel_buffer[index + 1] = cast(ubyte)rand_range(0, 255);
            pixel_buffer[index + 2] = cast(ubyte)rand_range(0, 255);
            pixel_buffer[index + 3] = 255;
        }
        texture = create_texture(2048, 2018, pixel_buffer.ptr);

        create_cube_mesh(&cube_mesh);

        reload_shader();

        model = engine.cache.load!(ModelAsset)("res/models/male.dat");
        entity_renderer.create();


        create_player();
        create_cubes();
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

        engine.allocator.free(pixel_buffer.ptr);
        program.dispose();
        texture.dispose();
        mesh.dispose();
    }

    int lastt;
    void tick(int time, int dt)
    {
        if (time - lastt > 1000)
        {
            LINFO("FPS: {}  {}", engine.fps, engine.tick_time);
            lastt = time;
        }

        if (engine.input.is_key_just_pressed(Key.KEY_SPACE))
        {
            LINFO("reload map shader");
            reload_shader();
        }

        if (vs_loaded && fs_loaded)
        {

            ShaderProgram newp;
            newp.compile_shaders(vs, fs);
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

        if (!instance.model && model.base.is_ready())
        {
            instance.load(&model.mdl, engine.allocator);
            controller.target = &instance;
        }

        if (!program.is_compiled)
            return;

        auto camera = &engine.renderer.camera;

        // program.bind();
        // // program.set_uniformf("u_time", now().seconds());
        // program.set_uniform_mat4("u_projViewTrans", camera.combined);
        // program.set_uniform_mat4("u_worldTrans", mat4.identity());
        // program.set_uniform4f("u_cameraPosition", camera.position.x, camera.position.y, camera.position.z, 1.1001f / (camera.far * camera.far));

        // texture.bind();
        // program.set_uniformi("u_diffuseTexture", 0);
        // program.set_uniform4f("u_diffuseUVTransform", 0, 0, 1, 1);


        test_rotation += (dt / 1000.0);

        // engine.renderer.state.set_depth_state(DepthState.Default);

        // if (instance.model)
        // {
        //     instance.transform =
        //     mat4.set(v3(0,0,0), quat.fromAxis(1,0,0, PIDIV2)) *
        //      mat4.set(v3(0, 0 ,0), quat.fromAxis(0, 0, 1, test_rotation), v3(1,1,1));

        //     Animation* anim = &instance.animations[4];
        //     controller.animate(anim.id);
        //     controller.update((dt / 1000.0));
        //     instance.calculate_transforms();
        //     entity_renderer.render(&instance);
        // }

        // enum SIZE = 6;
        // for (int x = -SIZE;  x < SIZE; x++)
        // for (int y = -SIZE;  y < SIZE; y++)
        // {
        //     mat4 t = mat4.set(v3(x * 2, -1, y * 2) + v3(1,0,1), quat.fromAxis(0,1,0, test_rotation), v3(1.75,1,1.75));
        //     entity_renderer.render(&cube_mesh, t);
        // }

        // entity_renderer.flush(&engine.renderer.camera);


        system_input(time, dt);
        system_movement(time, dt);


        system_render_map(time, dt);
        system_render(time, dt);


        system_load_model(time, dt);
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


    void system_input(int time, int dt)
    {
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
    
    void system_movement(int time, int dt)
    {
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

                    if(net.last_tick_id < last_tick_id)
                    {
                        LINFO("skip: {} {}", net.last_tick_id, last_tick_id);
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

    void system_load_model(int time, int dt)
    {
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

    void system_render_map(int time, int dt)
    {
        if (program.is_compiled == false) return;
        auto camera = &engine.renderer.camera;
        program.bind();   
        // program.set_uniformf("u_time", now().seconds());
        program.set_uniform_mat4("u_projViewTrans", camera.combined);
        program.set_uniform_mat4("u_worldTrans", mat4.identity());
        program.set_uniform4f("u_cameraPosition", camera.position.x, camera.position.y, camera.position.z, 1.1001f / (camera.far * camera.far));
        program.set_uniform4f("u_fogColor", 0,0,0,1);

        texture.bind();
        program.set_uniformi("u_diffuseTexture", 0);
        program.set_uniform4f("u_diffuseUVTransform", 0, 0, 1, 1);

        import dawn.gl;
        // mesh.render(&program, GL_TRIANGLES);

        debug check_gl_error();
    }

    void system_render(int time, int dt)
    {
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

            entity_renderer.render(&cube_mesh, 
                mat4.set(
                    trans.pos,
                    quat.fromAxis(0,1,0, trans.rot),
                    v3(trans.scale, trans.scale, trans.scale)
                )            
            );
        }
        entity_renderer.flush(&engine.renderer.camera);
    }
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

