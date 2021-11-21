module object;
version(WASM):


alias size_t = uint;
alias ptrdiff_t = int;


alias sizediff_t = ptrdiff_t; //For backwards compatibility only.

alias hash_t = size_t; //For backwards compatibility only.
alias equals_t = bool; //For backwards compatibility only.

alias string  = immutable(char)[];
alias wstring = immutable(wchar)[];
alias dstring = immutable(dchar)[];


// ldc defines this, used to find where wasm memory begins
private extern extern(C) ubyte __heap_base;
//                                           ---unused--- -- stack grows down -- -- heap here --
// this is less than __heap_base. memory map 0 ... __data_end ... __heap_base ... end of memory
private extern extern(C) ubyte __data_end;

// llvm intrinsics {
	/+
		mem must be 0 (it is index of memory thing)
		delta is in 64 KB pages
		return OLD size in 64 KB pages, or size_t.max if it failed.
	+/
	pragma(LDC_intrinsic, "llvm.wasm.memory.grow.i32")
	private int llvm_wasm_memory_grow(int mem, int delta);


	// in 64 KB pages
	pragma(LDC_intrinsic, "llvm.wasm.memory.size.i32")
	private int llvm_wasm_memory_size(int mem);
// }



extern(C) int _Dmain(string[] args);
export extern(C) void _start() { _Dmain(null); }
extern(C) bool _xopEquals(in void*, in void*) { return false; } // assert(0);



pragma(LDC_intrinsic, "llvm.memcpy.p0i8.p0i8.i#")
    void llvm_memcpy(T)(void* dst, const(void)* src, T len, bool volatile_ = false);

export extern(C) void* memcpy(void* dest, const void* src, size_t n) {
	llvm_memcpy(dest, src, n);
	return dest;
}

extern(C) int memcmp(const(void)* s1, const(void*) s2, size_t n) {
	auto b = cast(ubyte*) s1;
	auto b2 = cast(ubyte*) s2;

	foreach(i; 0 .. n) {
		if(auto diff = b -  b2)
			return diff;
	}
	return 0;
}

extern(C):
struct Interface {
	TypeInfo_Class classinfo;
	void*[] vtbl;
	size_t offset;
}

class Object {}
class TypeInfo  {
	const(TypeInfo) next() const { return this; }
	size_t size() const { return 1; }

	bool equals(void* a, void* b) { return false; }
}

class TypeInfo_Class : TypeInfo {
	ubyte[] m_init;
	string name;
	void*[] vtbl;
	Interface*[] interfaces;
	TypeInfo_Class base;
	void* dtor;
	void function(Object) ci;
	uint flags;
	void* deallocator;
	void*[] offti;
	void function(Object) dctor;
	immutable(void)* rtInfo;

	override size_t size() const { return size_t.sizeof; }
}

class TypeInfo_Const : TypeInfo {
	size_t getHash(in void*) nothrow { return 0; }
	TypeInfo base;
	override size_t size() const { return base.size; }
	override const(TypeInfo) next() const { return base; }
}

class TypeInfo_Pointer : TypeInfo {
	TypeInfo m_next;
}

class TypeInfo_Array : TypeInfo {
	TypeInfo value;
	override size_t size() const { return 2*size_t.sizeof; }
	override const(TypeInfo) next() const { return value; }
}

class TypeInfo_StaticArray : TypeInfo {
	TypeInfo value;
	size_t len;
	override size_t size() const { return value.size * len; }
    override const(TypeInfo) next() const { return value; }

	override bool equals(void* p1, void* p2) {
		size_t sz = value.size;

		for (size_t u = 0; u < len; u++)
		{
		    if (!value.equals(p1 + u * sz, p2 + u * sz))
		    {
			return false;
		}
		}
		return true;
	}

}

class TypeInfo_Struct : TypeInfo {
	string name;
	void[] m_init;
	void* xtohash;
	bool     function(in void*, in void*) xopEquals;
	int      function(in void*, in void*) xopCmp;
	void* xtostring;
	uint flags;
	union {
		void function(void*) dtor;
		void function(void*, const TypeInfo_Struct) xdtor;
	}
	void function(void*) postblit;
	uint align_;
	immutable(void)* rtinfo;
	override size_t size() const { return m_init.length; }

    override bool equals(in void* p1, in void* p2) @trusted
    {
        if (!p1 || !p2)
            return false;
        else if (xopEquals)
            return (*xopEquals)(p1, p2);
        else if (p1 == p2)
            return true;
        else
            // BUG: relies on the GC not moving objects
            return memcmp(p1, p2, m_init.length) == 0;
    }

}

extern(C) bool _xopCmp(in void*, in void*) { return false; }

extern(C) int _adEq2(void[] a1, void[] a2, TypeInfo ti)
{
	import dbg;
	if(ti is null) log("fuck3");

    if (a1.length != a2.length)
        return 0;               // not equal
    if (!ti.equals(&a1, &a2))
        return 0;
    return 1;
}


extern(C) void _d_arraybounds_slice(string file, uint line, size_t lower, size_t upper, size_t length)
{
}

 extern(C)    void _d_arraybounds_index(string file, uint line, size_t index, size_t length)
    {
    }