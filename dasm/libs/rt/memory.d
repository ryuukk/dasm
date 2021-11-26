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
        uint32_t bucket = (clz(size - 1) ^ 31) + 1;
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

int clz(uint x)
{
    assert(x > 0);
    
    static ubyte[32] debruijn32 = [
        0, 31, 9, 30, 3, 8, 13, 29, 2, 5, 7, 21, 12, 24, 28, 19,
        1, 10, 4, 14, 6, 22, 25, 20, 11, 15, 23, 26, 16, 27, 17, 18
    ];
    x |= x>>1;
    x |= x>>2;
    x |= x>>4;
    x |= x>>8;
    x |= x>>16;
    x++;
    return debruijn32[x*0x076be629>>27];
}
