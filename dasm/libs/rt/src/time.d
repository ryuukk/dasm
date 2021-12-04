module time;

import dbg;

version(WASM)
{
    import wasm;
}
else
{
    import core.stdc.stdio;
}


uint get_time()
{
    version(WASM) return WAJS_get_time();
    else return cast(uint) now().msecs();
}

uint get_elapsed_time()
{
    version(WASM) return WAJS_get_elapsed_time();
    else return 0;
}


ulong ticks()
{
    version (Windows)
    {
        import core.sys.windows.windows : QueryPerformanceCounter;
        import core.sys.windows.windows : LARGE_INTEGER;

        LARGE_INTEGER counter;
        QueryPerformanceCounter(&counter);
        return counter.QuadPart;
    }
    else version (Posix)
    {
        import core.sys.posix.time : clock_gettime;
        import core.sys.posix.time : timespec;
        import core.sys.posix.time : CLOCK_MONOTONIC;

        timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);

        ulong ticks = 0;
        ticks += now.tv_sec;
        ticks *= 1_000_000_000;
        ticks += now.tv_nsec;
        return ticks;
    }
    else
    {
        import wasm;
        return WAJS_ticks();
    }
}

ulong frequency()
{
    version (Windows)
    {
        import core.sys.windows.windows : QueryPerformanceFrequency;
        import core.sys.windows.windows : LARGE_INTEGER;

        LARGE_INTEGER frequency;
        QueryPerformanceFrequency(&frequency);
        return frequency.QuadPart;
    }
    else version (Posix)
    {
        return 1_000_000_000;
    }
    else
    {
        // TODO: is that the right amount?
        // ticks on wasm seems to return a very low value..
        return 1_000_000_000;
    }
}

struct StopWatch
{
    ulong start_ticks = 0;
    ulong stop_ticks = 0;

    void reset()
    {
        start_ticks = 0;
        stop_ticks = 0;
    }

    void restart()
    {
        reset();
        start();
    }

    bool is_running()
    {
        return start_ticks != 0;
    }

    bool is_stopped()
    {
        return stop_ticks != 0;
    }

    void start()
    {
        start_ticks = ticks();
    }

    void stop()
    {
        stop_ticks = ticks();
    }

    Timespan elapsed()
    {
        if (is_running() == false) return Timespan(0, frequency());

        auto t = (is_stopped() ? stop_ticks : ticks()) - start_ticks;
        return Timespan(t, frequency());
    }
}

struct Timespan
{
    ulong ticks;
    ulong frequency;

    double nano()
    {
        return ((ticks * 1000.0) / frequency) * 1_000_000;
    }

    double msecs()
    {
        return (ticks * 1000.0) / frequency;
    }

    int msecs_i()
    {
        return cast(int) ( (ticks * 1000.0) / frequency );
    }

    double seconds()
    {
        return ((ticks * 1000.0) / frequency) / 1000;
    }
}

Timespan now()
{
    return Timespan(ticks(), frequency());
}