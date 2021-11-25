module memory;


version (WASM)
{
	import wasm;
}
else
{
	import stdc = core.stdc.stdio;
	import stdlib = core.stdc.stdlib;
	import stdc_str = core.stdc.string;
}

version (WASM)
{
	
	alias uint32_t = uint;

    __gshared uint32_t[32] freeHeads = 0;
    __gshared uint32_t[32] freeTails = 0;
    __gshared uint32_t freePages = 0;
    __gshared uint32_t freeStart = 0;
    __gshared uint32_t[65536] pageBuckets = 0;


    export extern(C) void* malloc(size_t size) {
        if (size < 4) size = 4;
        uint32_t bucket = (bsr(size - 1) ^ 31) + 1;
        if (freeHeads[bucket] == 0 && freeTails[bucket] == 0) {
            uint32_t wantPages = (bucket <= 16) ? 1 : (1 << (bucket - 16));
            if (freePages < wantPages) {
            uint32_t currentPages = llvm_wasm_memory_size(0);
            if (freePages == 0) freeStart = currentPages << 16;
            uint32_t plusPages = currentPages;
            if (plusPages > 256) plusPages = 256;
            if (plusPages < wantPages - freePages) plusPages = wantPages - freePages;
            if (llvm_wasm_memory_grow(0, plusPages) == -1) assert(0);
            else update_memory_view();
            freePages += plusPages;
            }
            pageBuckets[freeStart >> 16] = bucket;
            freeTails[bucket] = freeStart;
            freeStart += wantPages << 16;
            freePages -= wantPages;
        }
        if (freeHeads[bucket] == 0) {
            freeHeads[bucket] = freeTails[bucket];
            freeTails[bucket] += 1 << bucket;
            if ((freeTails[bucket] & 0xFFFF) == 0) freeTails[bucket] = 0;
        }
        uint32_t result = freeHeads[bucket];
        freeHeads[bucket] = (cast(uint32_t*)(result))[0];
        return cast(void*)(result);
    }

    export extern(C) void free(void* ptr) {
        uint32_t p = cast(uint32_t)(ptr);
        size_t bucket = pageBuckets[p >> 16];
        (cast(uint32_t*)(p))[0] = freeHeads[bucket];
        freeHeads[bucket] = p;
    }

}
else
{
	void* malloc(size_t size)
	{
		return stdlib.malloc(size);
	}

	void free(void* ptr)
	{
		stdlib.free(ptr);
	}

	void* calloc(size_t nmemb, size_t size)
	{
		return stdlib.calloc(nmemb, size);
	}

	void* realloc(void* ptr, size_t size)
	{
		return stdlib.realloc(ptr, size);
	}
}

void* memset(void* s, int c, size_t n)
{
	auto d = cast(ubyte*) s;
	while(n) {
		*d = cast(ubyte) c;
		n--;
	}
	return s;
}

int memcmp(
    const(void)* s1, /* First string. */
    const(void)* s2, /* Second string. */
    size_t n) /* Length to compare. */
{
    ubyte u1, u2;

    for (; n--; s1++, s2++)
    {
        u1 = *cast(ubyte*) s1;
        u2 = *cast(ubyte*) s2;
        if (u1 != u2)
        {
            return (u1 - u2);
        }
    }
    return 0;
}

version (WASM)
{
	
}
else
{
//	void* memcpy(void* dst, const void* src, size_t n)
//	{
//		stdc_str.memcpy(dst, src, n);
//		return dest;
//	}
}


void[] alloc(size_t size)
{
	assert(size > 0);
	void* ptr = malloc(size);
	if (!ptr)
		assert(0, "Out of memory!");
	return ptr[0 .. size];
}

T[] alloc_array(T)(size_t count)
{
	assert(count > 0, "can't allocate empty array");
	return cast(T[]) alloc(T.sizeof * count);
}


package:

int bsr(uint v) pure
{
    pragma(inline, false);  // so intrinsic detection will work
    return softBsr!uint(v);
}

/// ditto
int bsr(ulong v) pure
{
    static if (size_t.sizeof == ulong.sizeof)  // 64 bit code gen
    {
        pragma(inline, false);   // so intrinsic detection will work
        return softBsr!ulong(v);
    }
    else
    {
        /* intrinsic not available for 32 bit code,
         * make do with 32 bit bsr
         */
        const sv = Split64(v);
        return (sv.hi == 0)?
            bsr(sv.lo) :
            bsr(sv.hi) + 32;
    }
}

private alias softBsf(N) = softScan!(N, true);
private alias softBsr(N) = softScan!(N, false);

/* Shared software fallback implementation for bit scan foward and reverse.
If forward is true, bsf is computed (the index of the first set bit).
If forward is false, bsr is computed (the index of the last set bit).
-1 is returned if no bits are set (v == 0).
*/
private int softScan(N, bool forward)(N v) pure
    if (is(N == uint) || is(N == ulong))
{
    // bsf() and bsr() are officially undefined for v == 0.
    if (!v)
        return -1;

    // This is essentially an unrolled binary search:
    enum mask(ulong lo) = forward ? cast(N) lo : cast(N)~lo;
    enum inc(int up) = forward ? up : -up;

    N x;
    int ret;
    static if (is(N == ulong))
    {
        x = v & mask!0x0000_0000_FFFF_FFFFL;
        if (x)
        {
            v = x;
            ret = forward ? 0 : 63;
        }
        else
            ret = forward ? 32 : 31;

        x = v & mask!0x0000_FFFF_0000_FFFFL;
        if (x)
            v = x;
        else
            ret += inc!16;
    }
    else static if (is(N == uint))
    {
        x = v & mask!0x0000_FFFF;
        if (x)
        {
            v = x;
            ret = forward ? 0 : 31;
        }
        else
            ret = forward ? 16 : 15;
    }
    else
        static assert(false);

    x = v & mask!0x00FF_00FF_00FF_00FFL;
    if (x)
        v = x;
    else
        ret += inc!8;

    x = v & mask!0x0F0F_0F0F_0F0F_0F0FL;
    if (x)
        v = x;
    else
        ret += inc!4;

    x = v & mask!0x3333_3333_3333_3333L;
    if (x)
        v = x;
    else
        ret += inc!2;

    x = v & mask!0x5555_5555_5555_5555L;
    if (!x)
        ret += inc!1;

    return ret;
}
private union Split64
{
    ulong u64;
    struct
    {
        version (LittleEndian)
        {
            uint lo;
            uint hi;
        }
        else
        {
            uint hi;
            uint lo;
        }
    }

    pragma(inline, true)
    this(ulong u64) @safe pure nothrow @nogc
    {
        if (__ctfe)
        {
            lo = cast(uint) u64;
            hi = cast(uint) (u64 >>> 32);
        }
        else
            this.u64 = u64;
    }
}