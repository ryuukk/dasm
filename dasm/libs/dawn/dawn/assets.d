module dawn.assets;

import rt.collections.hashmap;
import mem = rt.memory;
import rt.filesystem;
import rt.dbg;

import dawn.texture;

struct Resource
{
    enum State{ EMPTY, READY, FAILURE }
    
    void delegate(Resource*) vt_on_before_ready;
    void delegate(Resource*) vt_unload;
    bool delegate(uint, const(ubyte)*) vt_load;

    void delegate(State, State, Resource*)  cb;

    State current_state;
    State desired_state;
    
    uint ref_count;
    ushort empty_dep_count;
    ushort failed_dep_count;
    ResourceCache* cache;
    uint size;
    char[256] path = 0;
    FS.AsyncHandle async_op;
    bool hooked;


    void create(char[256] path, ResourceCache* cache)
    {
        this.path = path;
        this.cache = cache;
        empty_dep_count = 1;
        current_state = State.EMPTY;
        desired_state = State.EMPTY;
        async_op = FS.invalid_handle;
    }

    void dispose()
    {

    }

    bool is_empty()
    {
        return current_state == State.EMPTY;
    }

    bool is_ready()
    {
        return current_state == State.READY;
    }
    bool is_failure()
    {
        return current_state == State.FAILURE;
    }

    uint increase_ref_count()
    {
        return ++ref_count;
    }

    uint decreate_ref_count()
    {
        assert(ref_count > 0);
        --ref_count;
        if (ref_count == 0 && cache.is_unload_enabled) {
            do_unload();
        }
        return ref_count;
    }

    void do_unload()
    {
        if (async_op.is_valid())
        {
            cache.fs.cancel(async_op);
            async_op = FS.invalid_handle;
        }

        hooked = false;
        desired_state = State.EMPTY;
        
        if (vt_unload)
            vt_unload(&this);

        assert(empty_dep_count <= 1);

        size = 0;
        empty_dep_count = 1;
        failed_dep_count = 0;
        check_state();
    }

    void do_load()
    {
        if (desired_state == State.READY) return;
        desired_state = State.READY;

        if (async_op.is_valid()) return;

        assert(current_state != State.READY);

        async_op = cache.fs.get_content_async(cast(string) path, &file_loaded);
    }

    void file_loaded(uint size, const(ubyte)* buffer, bool ok)
    {
        assert(async_op.is_valid());
        if (desired_state != State.READY) return;

        assert(current_state != State.READY);
        assert(empty_dep_count == 1);

        if (!ok)
        {
            LERRO("Could not open {}", path);

            assert(empty_dep_count > 0);
            --empty_dep_count;
            ++failed_dep_count;
            check_state();
            async_op = FS.invalid_handle;
            return;
        }

        if (!vt_load(cast(uint)size, buffer))
        {
            LERRO("Failed to load asset {}", path);
            ++failed_dep_count;
        }
        this.size = cast(uint)size;

        assert(empty_dep_count > 0);
        --empty_dep_count;
        check_state();
        async_op = FS.invalid_handle;
    }

    void add_dependency(Resource* dependent_resource)
    {
        assert(desired_state != State.EMPTY);

        dependent_resource.cb = &on_state_changed;
        if (dependent_resource.is_empty()) ++empty_dep_count;
        if (dependent_resource.is_failure()) {
            ++failed_dep_count;
        }
        check_state();
    }

    void remove_dependency(Resource* dependent_resource)
    {
        assert(desired_state != State.EMPTY);

        dependent_resource.cb = null;
        if (dependent_resource.is_empty()) ++empty_dep_count;
        if (dependent_resource.is_failure()) {
            ++failed_dep_count;
        }

        check_state();
    }
    

    void on_state_changed(State old_state, State new_state, Resource* rf)
    {
        assert(old_state != new_state);
        assert(current_state != State.EMPTY || desired_state != State.EMPTY);

        if (old_state == State.EMPTY)
        {
            assert(empty_dep_count > 0);
            --empty_dep_count;
        }
        if (old_state == State.FAILURE)
        {
            assert(failed_dep_count > 0);
            --failed_dep_count;
        }

        if (new_state == State.EMPTY) ++empty_dep_count;
        if (new_state == State.FAILURE) ++failed_dep_count;

        check_state();
    }

    void check_state()
    {
        auto old_state = current_state;
        if (failed_dep_count > 0 && current_state != State.FAILURE)
        {
            current_state = State.FAILURE;
            //#ifdef LUMIX_DEBUG
                //invoking = true;
            //#endif
            if (cb)
                cb(old_state, current_state, &this);
            //#ifdef LUMIX_DEBUG
                //invoking = false;
            //#endif
        }

        if (failed_dep_count == 0)
        {
            if (empty_dep_count == 0 && current_state != State.READY &&
                desired_state != State.EMPTY)
            {
                if (vt_on_before_ready)
                    vt_on_before_ready(&this);
                const bool state_changed = empty_dep_count != 0 
                    || current_state == State.READY 
                    || desired_state == State.EMPTY;
                
                if (state_changed) {
                    return;
                }

                if (failed_dep_count != 0) {
                    check_state();
                    return;
                }

                current_state = State.READY;
                //#ifdef LUMIX_DEBUG
                    //  invoking = true;
                //#endif
                if (cb)
                    cb(old_state, current_state, &this);
                //#ifdef LUMIX_DEBUG
                    //  invoking = false;
                //#endif
            }

            if (empty_dep_count > 0 && current_state != State.EMPTY)
            {
                current_state = State.EMPTY;
                //#ifdef LUMIX_DEBUG
                    //  invoking = true;
                //#endif
                if (cb)
                    cb(old_state, current_state, &this);
                //#ifdef LUMIX_DEBUG
                    //  invoking = false;
                //#endif
            }
        }
    }
}

struct Texture
{
    import dawn.texture;
    
    Resource base;
    Texture2D tex;

    void create(char[256] path, ResourceCache* cache)
    {
        base.create(path, cache);
        base.vt_load = &load;
        base.vt_unload = &unload;
    }

    void unload(Resource* res)
    {
        tex.dispose();
    }

    bool load(uint size, const(ubyte)* buffer)
    {
        LINFO("texture: {} size: {} bytes", base.path, size);
        import dawn.image;

        IFImage a = read_image(buffer[0 .. size], 4);
        scope (exit)
            a.free();

        if (a.e)
        {
            LERRO("decode error: {} file: {}", IF_ERROR[a.e], base.path);
        }
        else
        {
            PixelFormat format;
            auto c = a.c;
            if (c == 4)
                format = PixelFormat.Rgba;
            else if (c == 3)
                format = PixelFormat.Rgb;
            else
                assert(0);

            tex = create_texture(a.w, a.h, a.buf8.ptr, format);

            return true;
        }
        return false;
    }
}

struct ModelAsset
{
    import dawn.model;
    
    Resource base;
    Model mdl;

    void create(char[256] path, ResourceCache* cache)
    {
        base.create(path, cache);
        base.vt_load = &load;
    }

    bool load(uint size, const(ubyte)* buffer)
    {
        import rt.readers;
        LINFO("model: {} size: {} bytes", base.path, size);

        PReader reader;
        reader._data = buffer[0 .. size];

        ubyte h = reader.read_ubyte();
        ubyte l = reader.read_ubyte();
        string id = reader.read_cstring();

        mdl = Model();
        mdl.load(reader, base.cache.allocator);
        return true;
    }
}


struct FontAsset
{
    import dawn.font;
    
    Resource base;
    FontAtlas fnt;
    Texture* tex;

    void create(char[256] path, ResourceCache* cache)
    {
        base.create(path, cache);
        base.vt_load = &load;
        base.vt_unload = &unload;
        base.vt_on_before_ready = &before_ready;
    }

    void before_ready(Resource* res)
    {
        fnt.atlas = tex.tex;
    }

    void unload(Resource* res)
    {
        // TODO: i should test this
        // it's a dependency
        tex.base.decreate_ref_count();
    }

    bool load(uint size, const(ubyte)* buffer)
    {
        import rt.readers;
        LINFO("font: {} size: {} bytes", base.path, size);

        PReader reader;
        reader._data = buffer[0 .. size];

        // version
        ubyte ver = reader.read_ubyte();
        assert(ver == 1);

        // info
        fnt.line_height = reader.read_int();
        fnt.ascent = reader.read_int();
        fnt.descent = reader.read_int();
        fnt.space_x_advance = reader.read_int();
        fnt.down = reader.read_int();
        fnt.x_height = reader.read_int();
        fnt.cap_height = reader.read_int();

        // glyps
        int numG = reader.read_int();
        for(int i = 0; i < numG; i++)
        {
            auto g = &fnt.glyphs[i];
            g.id = reader.read_uint();
            g.character =  cast(char) reader.read_int();
            g.width = reader.read_ubyte();
            g.height = reader.read_ubyte();
            g.brearing_x = reader.read_byte();
            g.brearing_y = reader.read_byte();
            g.advance = reader.read_byte();
            g.u = reader.read_float();
            g.v = reader.read_float();
            g.u2 = reader.read_float();
            g.v2 = reader.read_float();

            ubyte numK = reader.read_ubyte();
            for (int j = 0; j < numK; j++)
            {
                auto c = reader.read_int();
                auto v = reader.read_byte();
                g.kerning_value[c] = v;
            }
        }

        fnt.atlas_width = reader.read_int();
        fnt.atlas_height = reader.read_int();
        auto fntPathL = reader.read_int();
        auto fntPathS = cast(char[])reader.read_slice(fntPathL);

        // TODO: i really need to fix that mess of a path/str
        char[256] fntPath = 0;
        mem.memcpy(fntPath.ptr, fntPathS.ptr, fntPathL);
        tex = base.cache.load!(Texture)(fntPath);

        base.add_dependency(cast(Resource*)tex);

        return true;
    }
}




struct ResourceCache
{
    HashMap!(uint, Resource*) map;
    mem.Allocator* allocator;
    FS fs;
    bool is_unload_enabled = true;

    void create()
    {
        fs.create();
        allocator = mem.MALLOCATOR.ptr();
        map.allocator = allocator;
    }

    void process()
    {
        uint idtoremove = 0;
        Resource* resource = null;
        foreach(v; map)
        {
            if (v.value.is_empty() == true && v.value.ref_count == 0)
            {
                idtoremove = v.key; 
                resource = v.value; 
            }
        }
        if (idtoremove > 0)
        {
            LINFO("Remove: {}:{}", idtoremove, resource.path);
            map.erase(idtoremove);
            //resource.do_unload();
        }

        fs.process_callbacks();
    }

    T* load(T)(char[256] path)
    {
        uint key = murmum_hash_2(path.ptr, cast(int) path.length, 666);

        Resource* ret = null;

        if (map.has(key))
            ret = map[key];

        if (ret == null)
        {
            auto ss = T.sizeof;
            auto res =  cast(T*) allocator.allocate(ss);
            (*res) = T();
            
            ret = cast(Resource*) res;

            res.create(path, &this);
            map.set(key, ret);
        }

        if (ret.is_empty() && ret.desired_state == Resource.State.EMPTY)
        {
            ret.do_load();
        }

        ret.increase_ref_count();

        return cast(T*) ret;
    }
}


uint murmum_hash_2(const(void)* key, int len, uint seed)
{
    assert(len > 0);
    assert(key != null);

    /* 'm' and 'r' are mixing constants generated offline.
     They're not really 'magic', they just happen to work well.  */

    const uint m = 0x5bd1e995;
    const int r = 24;

    /* Initialize the hash to a 'random' value */

    uint h = seed ^ len;

    /* Mix 4 bytes at a time into the hash */

    const(ubyte)* data = cast(const(ubyte)*) key;

    while (len >= 4)
    {
        uint k = *cast(uint*) data;

        k *= m;
        k ^= k >> r;
        k *= m;

        h *= m;
        h ^= k;

        data += 4;
        len -= 4;
    }

    /* Handle the last few bytes of the input array  */

    switch (len)
    {
    case 3:
        h ^= data[2] << 16;
        break;
    case 2:
        h ^= data[1] << 8;
        break;
    case 1:
        h ^= data[0];
        h *= m;
        break;
    default:
    }

    /* Do a few final mixes of the hash to ensure the last few
  // bytes are well-incorporated.  */

    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;

    return h;
}




version(NONE):
unittest
{
    import rt.memory;
    import rt.time;
    import rt.thread;
    Allocator* allocator = MALLOCATOR.ptr();
    ResourceCache cache;
    cache.create();

    StopWatch sw;
    sw.start();


    struct AssetOne 
    {
        Resource base;
    }

    struct AssetTwo 
    {
        Resource base;
    }

    while (sw.elapsed.msecs < 10_000)
    {
        cache.process();
        sleep_for(10);
    }
}