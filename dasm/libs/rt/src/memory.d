module memory;

import dbg;

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
	alias uint8_t = ubyte;

    __gshared uint32_t[32] freeHeads = 0;
    __gshared uint32_t[32] freeTails = 0;
    __gshared uint32_t freePages = 0;
    __gshared uint32_t freeStart = 0;
    __gshared uint32_t[65536] pageBuckets = 0;


    // TODO: clz is probably wrong!
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

            auto g = llvm_wasm_memory_grow(0, plusPages);
            if (g == -1) 
                assert(0, "you can't");
            else 
                update_memory_view();
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

	extern(C) void *memcpy(void* dest, const(void)* src, size_t n)
	{
		ubyte *d = cast(ubyte*) dest;
		const (ubyte) *s = cast(const(ubyte)*)src;
		for (; n; n--) *d++ = *s++;
		return dest;
	}
	
	extern(C) void *memmove(void *dest, const void *src, size_t n)
	{
		uint8_t* from = cast(uint8_t*) src;
		uint8_t* to = cast(uint8_t*) dest;

		if (from == to || n == 0)
			return dest;
		if (to > from && to-from < cast(int)n) {
			/* to overlaps with from */
			/*  <from......>         */
			/*         <to........>  */
			/* copy in reverse, to avoid overwriting from */
			int i;
			for(i=n-1; i>=0; i--)
				to[i] = from[i];
			return dest;
		}
		if (from > to && from-to < cast(int)n) {
			/* to overlaps with from */
			/*        <from......>   */
			/*  <to........>         */
			/* copy forwards, to avoid overwriting from */
			size_t i;
			for(i=0; i<n; i++)
				to[i] = from[i];
			return dest;
		}
		memcpy(dest, src, n);
		return dest;
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

	alias memmove = stdc_str.memmove;
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

    public import core.stdc.string: memcpy;
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




__gshared MallocAllocator MALLOCATOR = MallocAllocator();

// TODO: handle failures
struct Allocator
{
	void* function(Allocator*, size_t) vt_allocate;
	void* function(Allocator*, void*, size_t) vt_reallocate;
	void function(Allocator*, void*) vt_free;

	Allocator* ptr() return
	{
		return &this;
	}

	// INTERFACE

	void* allocate(size_t size)
	{
		assert(size > 0);
		return vt_allocate(&this, size);
	}
	
	void* reallocate(void* ptr, size_t size)
	{
		assert(size > 0);
		return vt_reallocate(&this, ptr, size);
	}

	// prefer safe_delete(T)(ref T* ptr)
	void free(void* ptr)
	{
		assert(ptr != null);
		vt_free(&this, ptr);
	}

	// END INTERFACE

	void safe_delete(T)(ref T* ptr)
	{
		if(ptr)
		{
			free(ptr);
			ptr = null;
		}
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

	T[] reallocate_array(T)(T* ptr, size_t count)
	{
		assert(count > 0, "can't reallocate empty array");

		auto size = T.sizeof * count;
		auto ret = reallocate(ptr, size);
		return cast(T[]) ret[0 .. size];
	}

	T* create_noinit(T, Args...)(Args args = Args.init)
	{
		static assert(is(T == struct), "it's not a struct");

		void* ptr = allocate(T.sizeof);
		if (!ptr)
			assert(0, "Out of memory!");

		return cast(T*) ptr;
	}

	T* create(T, Args...)(Args args = Args.init)
	{
		static assert(is(T == struct), "it's not a struct");

		auto ptr = cast(T*) malloc(T.sizeof);
		if (!ptr)
			assert(0, "Out of memory!");

		(*ptr) = T(args);
		return ptr;
	}
}

struct MallocAllocator
{
	Allocator base = Allocator( 
		&MallocAllocator.allocate,
		&MallocAllocator.reallocate,
		&MallocAllocator.free,
	);
	alias base this;

	static void* allocate(Allocator* self, size_t size)
	{
		assert(size > 0);

		return .malloc(size);
	}
	
	static void* reallocate(Allocator* self, void* ptr, size_t size)
	{
		assert(size > 0);
        version(DESKTOP)
		    return .realloc(ptr, size);
        else
            assert(0, "not supported");
	}

	static void free(Allocator* self, void* ptr)
	{
		assert(ptr != null);
		.free(ptr);
	}
}


T[] dupe(T)(Allocator* a, T[] orig)
{
	assert(orig.length != 0);

	T[] ret = a.alloc_array!T(orig.length);

	memcpy(ret.ptr, orig.ptr, orig.length * T.sizeof);

	return ret;
}



package:

int clz(size_t x)
{
    if (x == 0) return 32;
    
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