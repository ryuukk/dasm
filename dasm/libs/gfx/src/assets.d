module assets;

import collections.hashmap;
import mem = memory;
import filesystem;
import dbg;

import texture;

struct Resource
{
    enum State{EMPTY, READY, FAILURE}
    
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
    char[256] path;
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

    void file_loaded(ulong size, const(ubyte)* buffer, bool ok)
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
            ++failed_dep_count;
        }
        this.size = cast(uint)size;

        assert(empty_dep_count > 0);
        --empty_dep_count;
        check_state();
        async_op = FS.invalid_handle;
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
    import texture;

    Resource base;
    Texture2D tex;

    void create(char[256] path, ResourceCache* cache)
    {
        base.create(path, cache);
        base.vt_load = &load;
    }

    bool load(uint size, const(ubyte)* buffer)
    {
        writeln("Tex: load: {} at {}", size, buffer);
        import image;

        IFImage a = read_image(buffer[0 .. size], 4);
        scope (exit)
            a.free();

        if (a.e)
        {
            panic("*** decode error: {}", IF_ERROR[a.e]);
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
    }

    void process()
    {
        uint idtoremove = 0;
        Resource* resource = null;
        foreach(v; map)
        {
            if (v.value.ref_count == 0)
            {
                idtoremove = v.key; 
                resource = v.value; 
            }
        }
        if (idtoremove > 0)
        {
            writeln("Remove: {}:{}", idtoremove, resource.path);
            map.erase(idtoremove);
            resource.do_unload();
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
            auto res =  cast(T*) allocator.allocate(T.sizeof);
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

