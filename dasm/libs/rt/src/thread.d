module thread;


version (Windows)
{
    import core.sys.windows.winsock2;
    import core.sys.windows.windows;
    import core.sys.windows.threadaux;

    private extern (Windows) alias btex_fptr = uint function(void*);
    private extern (C) ulong _beginthreadex(void*, uint, btex_fptr, void*, uint, uint*) nothrow @nogc;
    extern (Windows) uint ThreadProc(void* lpParam)
    {
        Thread* p = cast(Thread*) lpParam;
        p.run();
        return 0;
    }
    extern (Windows) void Sleep(DWORD);

    extern (Windows) HRESULT SetThreadDescription(HANDLE hThread, PCWSTR lpThreadDescription);
}
else version (Posix)
{
    import core.sys.posix.fcntl;
    import core.sys.posix.pthread;
    import core.sys.posix.semaphore;
    import core.stdc.string;
    import core.stdc.stdio;

    extern (C) void* ThreadProc(void* pParam)
    {
        Thread* p = cast(Thread*) pParam;
        p.run();
        return null;
    }

    
    extern(C) int pthread_setname_np(pthread_t thread, const (char) *name);
}

struct Thread
{
    ulong thread_id = 0;
    void delegate(void*,Thread*) cb;
    const(char)* name = null;
    void* ctx;

    void create(void delegate(void*, Thread*) cb, void* ctx)
    {
        this.cb = cb;
        this.ctx = ctx;
    }

    bool start()
    {
        version (Windows)
        {
            ulong ret = cast(ulong) _beginthreadex(null, 0, &ThreadProc, cast(void*)&this, 0, null);

            if (ret == -1 || ret == 0)
                return false;

            wchar[256] tmp = 0;
            import core.stdc.stdlib: mbstowcs;

            mbstowcs(tmp.ptr, name, tmp.length);
            SetThreadDescription(cast(void*)ret, tmp.ptr);
            thread_id = ret;
        }
        else version (Posix)
        {
            ulong ptid = 0;
            int ret = pthread_create(&ptid, null, &ThreadProc, cast(void*)&this);
            if (ret != 0)
                return false;
            pthread_setname_np(ptid, name);
            thread_id = ptid;
        }
        return true;
    }

    void run()
    {
        cb(ctx,&this);
    }

    bool wait()
    {
        version (Windows)
        {
            if (WaitForSingleObject(cast(HANDLE) thread_id, INFINITE) != WAIT_OBJECT_0)
            {
                return false;
            }
        }
        else version (Posix)
        {
            if (pthread_join(cast(pthread_t) thread_id, null) != 0)
            {
                return false;
            }
        }
        return true;
    }

    bool terminate()
    {
        version (Windows)
        {
            return TerminateThread(cast(HANDLE) thread_id, 1) ? true : false;
        }
        else version (Posix)
        {
            return pthread_cancel(cast(pthread_t) thread_id) == 0 ? true : false;
        }
        else
            return true;
    }
}



void sleep_for(int ms)
{
    version (Windows)
    {
        Sleep(ms);
    }
    else version (Posix)
    {
        import core.sys.posix.unistd : sleep;

        sleep(ms / 1000);
    }
    else version (WASM)
    {
        
    }
    else static assert(0);
}