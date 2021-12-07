module rt.sync;

version(Windows)
{
    pragma(lib, "kernel32.lib");

    import core.sys.windows.windef: PVOID, DWORD;
    import core.sys.windows.winbase: INFINITE, CreateSemaphore, CloseHandle, ReleaseSemaphore, WaitForSingleObject;
    

    alias RTL_SRWLOCK = PVOID;
    alias SRWLOCK = RTL_SRWLOCK;
    extern (Windows) void InitializeSRWLock(SRWLOCK* lock);
    extern (Windows) void AcquireSRWLockExclusive(SRWLOCK* lock);
    extern (Windows) void ReleaseSRWLockExclusive(SRWLOCK* lock);
}
else version(Posix)
{
    import core.sys.posix.pthread;
}


version(WASM)
{}
else
{
    import core.atomic: atomicStore, atomicOp;
}




align(8)
struct Mutex
{
    version(Windows)
    {
        ubyte[8] data;
    }
    else version(Posix)
    {
        pthread_mutex_t mutex;    
    }

    void create()
    {
        version(Windows)
        {
            static assert(data.sizeof >= SRWLOCK.sizeof, "Size is not enough");
            static assert(Mutex.alignof == SRWLOCK.alignof, "Alignment does not match");
            data = 0;
            InitializeSRWLock(cast(SRWLOCK*)data.ptr);
        }
        else version(Posix)
        {
            const int res = pthread_mutex_init(&mutex, null);
            assert(res == 0);
        }
    }

    void dispose()
    {
        version(Windows)
        {
            auto lock = cast(SRWLOCK*) data;
        }
        else version(Posix)
        {
            const int res = pthread_mutex_destroy(&mutex);
            assert(res == 0);
        }
    }

    void enter()
    {
        version(Windows)
        {
            SRWLOCK* lock = cast(SRWLOCK*)data;
            AcquireSRWLockExclusive(lock);
        }
        else version(Posix)
        {
	        const int res = pthread_mutex_lock(&mutex);
	        assert(res == 0);
        }
    }

    void exit()
    {
        version(Windows)
        {
            SRWLOCK* lock = cast(SRWLOCK*)data;
            ReleaseSRWLockExclusive (lock);
        }
        else version(Posix)
        {
            const int res = pthread_mutex_unlock(&mutex);
            assert(res == 0);
        }
    }
}

struct Semaphore
{
    version(Windows)
    {
        void* id;
    }
    else version(Posix)
    {
        struct _id
        {
            pthread_mutex_t mutex;
            pthread_cond_t cond;
            /* volatile */ shared int count;
        }
        _id id;
    }

    void create(int initc = 0, int maxc = 0xffFF)
    {
        version(Windows)
        {
	        id = CreateSemaphore(null, initc, maxc, null);
        }
        else version(Posix)
        {
            atomicStore(id.count, initc);
            int res = pthread_mutex_init(&id.mutex, null);
            assert(res == 0);
            res = pthread_cond_init(&id.cond, null);
            assert(res == 0);
        }
    }

    void dispose()
    {
        version(Windows)
        {
            CloseHandle(id);
        }
        else version(Posix)
        {
            int res = pthread_mutex_destroy(&id.mutex);
            assert(res == 0);
            res = pthread_cond_destroy(&id.cond);
            assert(res == 0);
        }
    }

    
	void signal()
    {
        version(Windows)
        {
            ReleaseSemaphore(id, 1, null);
        }
        else version(Posix)
        {
            int res = pthread_mutex_lock(&id.mutex);
            assert(res == 0);
            res = pthread_cond_signal(&id.cond);
            assert(res == 0);

            atomicOp!"+="(id.count, 1);

            res = pthread_mutex_unlock(&id.mutex);
            assert(res == 0);
        }
    }

	void wait()
    {
        version(Windows)
        {
            WaitForSingleObject(id, INFINITE);
        }
        else version(Posix)
        {
            int res = pthread_mutex_lock(&id.mutex);
            assert(res == 0);
            
            while (id.count <= 0)
            {
                res = pthread_cond_wait(&id.cond, &id.mutex);
                assert(res == 0);
            }
            
            atomicOp!("-=")(id.count, 1);
            
            res = pthread_mutex_unlock(&id.mutex);
            assert(res == 0);
        }
    }
}