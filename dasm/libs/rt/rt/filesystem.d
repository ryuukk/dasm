module rt.filesystem;

import rt.dbg;
import rt.sync;
import rt.time;
import rt.str;
import mem = rt.memory;
import rt.collections.hashmap;
import rt.collections.array;

version (WASM)
{
    import wasm;
}
else
{
    version = HAS_THREADS;
}

version (Windows)
{
    import core.sys.windows.windef : HANDLE, LPDWORD, DWORD,
        SECURITY_ATTRIBUTES, GENERIC_READ, FILE_SHARE_READ, FILE_ATTRIBUTE_NORMAL;
    import core.sys.windows.winbase : OPEN_EXISTING, INVALID_HANDLE_VALUE,
        GetFileSize, CreateFileA, CloseHandle,
        ReadFile;
}
else version (Posix)
{
    import core.stdc.stdio : fopen, ftell, fseek, fread, fclose, FILE, SEEK_SET, SEEK_END;
}

struct OutputStream
{
    ubyte* data;
    size_t capacity;
    size_t size;

    void dispose()
    {
        if (data)
            mem.free(data);
    }

    bool empty()
    {
        return size == 0;
    }

    void reserve(int s)
    {
        if (s <= capacity)
            return;
        ubyte* tmp = cast(ubyte*) mem.malloc(s);

        mem.memcpy(tmp, data, capacity);

        mem.free(data);
        data = tmp;
        capacity = s;
    }

    void resize(int s)
    {
        size = s;
        if (s <= capacity)
            return;
        ubyte* tmp = cast(ubyte*) mem.malloc(s);
        mem.memcpy(tmp, data, capacity);
        mem.free(data);
        data = tmp;
        capacity = s;
    }
}

struct InputFile
{
    void* handle;

    void dispose()
    {
        assert(!handle);
    }

    bool open(string path)
    {
        version (Windows)
        {
            handle = cast(HANDLE) CreateFileA(path.ptr, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
            return INVALID_HANDLE_VALUE != handle;
        }
        else version (Posix)
        {
            handle = cast(void*) fopen(path.ptr, "rb");
            return handle != null;
        }
        else
            assert(0);
    }

    void close()
    {
        version (Windows)
        {
            if (INVALID_HANDLE_VALUE != cast(HANDLE) handle)
            {
                CloseHandle(cast(HANDLE) handle);
                handle = cast(void*) INVALID_HANDLE_VALUE;
            }
        }
        else version (Posix)
        {
            if (handle)
            {
                fclose(cast(FILE*) handle);
                handle = null;
            }
        }
        else
        {

        }
    }

    int size()
    {
        version (Windows)
        {
            assert(INVALID_HANDLE_VALUE != handle);
            return GetFileSize(cast(HANDLE) handle, null);
        }
        else version (Posix)
        {
            assert(null != handle);
            size_t pos = ftell(cast(FILE*) handle);
            fseek(cast(FILE*) handle, 0, SEEK_END);
            size_t size = cast(size_t) ftell(cast(FILE*) handle);
            fseek(cast(FILE*) handle, pos, SEEK_SET);
            return cast(int) size;
        }
        else
            assert(0);
    }

    bool read(void* buffer, size_t size)
    {
        version (Windows)
        {
            assert(INVALID_HANDLE_VALUE != handle);
            DWORD readed = 0;
            int success = ReadFile(cast(HANDLE) handle, buffer, cast(DWORD) size, cast(LPDWORD)&readed, null);
            return success && size == readed;
        }
        else version (Posix)
        {
            assert(null != handle);
            size_t read = fread(buffer, size, 1, cast(FILE*) handle);
            return read == 1;
        }
        else
            assert(0);
    }
}

struct FS
{
    alias content_cb_t = void delegate(uint, const(ubyte)*, bool);
    static AsyncHandle invalid_handle = {value: 0xffFFffFF};
    struct AsyncHandle
    {
        uint value = 0;
        bool is_valid()
        {
            return value != 0xffFFffFF;
        }
    }

    struct AsyncItem
    {
        enum Flags
        {
            FAILED = 1 << 0,
            CANCELED = 1 << 1
        }

        content_cb_t cb;
        OutputStream data;
        char[256] path;
        ubyte flags = 0;
        uint id = 0;

        bool is_failed()
        {
            return (flags & Flags.FAILED) == true;
        }

        bool is_canceled()
        {
            return (flags & Flags.CANCELED) == true;
        }
    }

    char[256] base_path = 0;
    Array!AsyncItem queue;
    Array!AsyncItem finished;
    uint work_counter = 0;
    
    version (HAS_THREADS)
    {
        import rt.thread;

        Thread task;
        Mutex mutex;
        Semaphore semaphore;
    }
    
    uint last_id;
    bool done;

    void create()
    {
        queue.create(mem.MALLOCATOR.ptr());
        finished.create(mem.MALLOCATOR.ptr());

        version (HAS_THREADS)
        {
            mutex.create();
            semaphore.create();
            task.name = "fs_worker";
            task.create((ctx, t) {
                FS* fs = cast(FS*) ctx;
                assert(fs, "fs null");

                while (!fs.done)
                {
                    fs.semaphore.wait();
                    if (fs.done)
                        break;

                    char[256] path = 0;
                    {
                        fs.mutex.enter();
                        scope (exit)
                            fs.mutex.exit();

                        assert(!fs.queue.empty(), "queue empty");

                        path = fs.queue[0].path;
                        if (fs.queue[0].is_canceled())
                        {
                            fs.queue.remove_at(0);
                            continue;
                        }
                    }

                    OutputStream data;
                    bool success = fs.get_content_sync(cast(string) path, &data);
                    {
                        fs.mutex.enter();
                        scope (exit)
                            fs.mutex.exit();

                        if (!fs.queue[0].is_canceled())
                        {
                            fs.finished.add(fs.queue[0]);
                            fs.finished.back().data = data;
                            if (!success)
                            {
                                fs.finished.back().flags |= AsyncItem.Flags.FAILED;
                            }
                        }
                        fs.queue.remove_at(0);
                    }
                }
            }, &this);

            task.start();
        }
    }

    void dispose()
    {
        done = true;
        version (HAS_THREADS)
        {
            task.terminate();
            mutex.dispose();
            semaphore.dispose();
        }
        queue.dispose();
        finished.dispose();
    }

    bool get_content_sync(string path, ubyte[] buffer)
    {
        assert(path.length > 0);

        InputFile file;

        auto fullpath = path; // TODO: concat with base batch

        if (!file.open(cast(string) fullpath))
        {
            writeln("can't open {}", fullpath.ptr);
            return false;
        }

        auto filesize = file.size();
        assert(buffer.length > filesize);

        if (!file.read(buffer.ptr, filesize))
        {
            file.close();
            return false;
        }
        file.close();
        return true;
    }

    bool get_content_sync(string path, OutputStream* stream)
    {
        assert(path.length > 0);

        InputFile file;

        auto fullpath = path; // TODO: concat with base batch

        if (!file.open(cast(string) fullpath))
        {
            writeln("can't open {}", fullpath.ptr);
            return false;
        }

        auto filesize = file.size();
        stream.resize(filesize);

        if (!file.read(stream.data, stream.size))
        {
            file.close();
            return false;
        }
        file.close();
        return true;
    }

    AsyncHandle get_content_async(string path, content_cb_t callback)
    {
        assert(path.length > 0);
        assert(path.length <= 256);

        version (HAS_THREADS)
            mutex.enter();
        version (HAS_THREADS)
            scope (exit)
                mutex.exit();

        ++work_counter;
        AsyncItem* item = queue.add_get(AsyncItem());
        ++last_id;
        if (last_id == 0)
            ++last_id;
        item.id = last_id;

        auto len = str_len(path.ptr);
        mem.memcpy(item.path.ptr, path.ptr, len);
        item.path[len] = '\0';

        item.cb = callback;

        version (HAS_THREADS)
            semaphore.signal();

        version (WASM)
            load_file_async(path, item.id, &on_wasm_cp);

        return AsyncHandle(item.id);
    }

    version (WASM) extern (C) void on_wasm_cp(uint id, void* ptr, int len, bool ok)
    {
        scope(exit) if (ok)mem.free(ptr);

        int index = -1;
        foreach (i, ref AsyncItem q; queue)
        {
            if (q.id == id)
            {
                index = i;
                if (q.is_canceled())
                {
                    writeln("canceled {}", id);
                    break;
                }
                if (!ok)
                {
                    writeln("failed {}", id);
                    q.flags |= AsyncItem.Flags.FAILED;
                }
                else
                {
                    q.data.resize(len);
                    mem.memcpy(q.data.data, ptr, len);
                }

                finished.add(q);
                break;
            }
        }
        assert(index >= 0);

        queue.remove_at(index);
    }

    void cancel(AsyncHandle async)
    {
        version (HAS_THREADS)
            mutex.enter();
        version (HAS_THREADS)
            scope (exit)
                mutex.exit();

        foreach (ref AsyncItem item; queue)
        {
            if (item.id == async.value)
            {
                item.flags |= AsyncItem.Flags.CANCELED;
                --work_counter;
                return;
            }
        }
        foreach (ref AsyncItem item; finished)
        {
            if (item.id == async.value)
            {
                item.flags |= AsyncItem.Flags.CANCELED;
                return;
            }
        }
    }

    void process_callbacks()
    {
        StopWatch timer;
        timer.start();
        for (;;)
        {

            version (HAS_THREADS)
                mutex.enter();
            if (finished.empty())
            {
                version (HAS_THREADS)
                    mutex.exit();
                break;
            }

            AsyncItem item = finished[0];
            finished.remove_at(0);
            assert(work_counter > 0);
            --work_counter;

            version (HAS_THREADS)
                mutex.exit();

            if (!(item.is_canceled()))
            {
                item.cb(cast(uint)item.data.size, item.data.data, !item.is_failed());
            }

            item.data.dispose();

            if (timer.elapsed().msecs() > 1)
            {
                break;
            }
        }
    }
}
