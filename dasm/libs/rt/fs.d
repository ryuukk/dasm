module fs;

import dbg;
import mem = memory;


version(WASM)
{
    extern(C) void load_file_async(string name, int id, scope void delegate (int id, void* ptr, int len) cb);
}
else
{
    extern(C) void load_file_async(string name, int id, scope void delegate (int id, void* ptr, int len) cb)
    {

    }

}

struct Handle
{
    bool used;
    bool loaded;
    void* data;
    int data_len;
    int id = -1;
    void* user;
}

struct Manager
{
    Handle[64] handles;

    Handle* next()
    {
        for (int i = 0; i < handles.length; i++)
        {
            Handle* handle = &handles[i];
            if (handle.used == false)
            {
                handle.id = i;
                return handle;
            }
        }
        return null;
    }

    void free(Handle* handle)
    {
        if (handle.data)
        {
            // TODO: use proper allocator
            mem.free(handle.data);
        }

        handle.loaded = false;
        handle.used = false;
        handle.data = null;
        handle.data_len = 0;
        handle.user = null;
    }

    Handle* load(string path)
    {
        Handle* handle = next();
        if (handle)
        {
            handle.used = true;

            load_file_async(path, handle.id, &on_cb);
            
            return handle;
        }
        return null;
    }

    extern (C) void on_cb(int id, void* ptr, int len)
    {
        assert(ptr != null);
        assert(len > 0);

        Handle* handle = &handles[id];
        handle.loaded = true;
        handle.data = ptr;
        handle.data_len = len;

        writeln("Id: {}:{} PTR: {} L: {}", handle.id, id, ptr, len);

        string str = cast(string) ptr[0 .. len];
        writeln("Data content:\n{}", str);
    }
}