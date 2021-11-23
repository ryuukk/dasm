module object;
version(WASM):

import wasm = wasm;

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


size_t grow_memory(size_t pages) {
	return llvm_wasm_memory_grow(0, pages);
}




extern(C) int _Dmain(string[] args);
export extern(C) void _start() { _Dmain(null); }
extern(C) bool _xopEquals(in void*, in void*) { return false; } // assert(0);


pragma(LDC_intrinsic, "llvm.memcpy.p0i8.p0i8.i#")
    void llvm_memcpy(T)(void* dst, const(void)* src, T len, bool volatile_ = false);

extern(C) void *memcpy(void* dest, const(void)* src, size_t n)
{
	ubyte *d = cast(ubyte*) dest;
	const (ubyte) *s = cast(const(ubyte)*)src;
	for (; n; n--) *d++ = *s++;
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


extern(C) private void* memset(void* s, int c, size_t n) {
	auto d = cast(ubyte*) s;
	while(n) {
		*d = cast(ubyte) c;
		n--;
	}
	return s;
}


alias AliasSeq(T...) = T;
static foreach(type; AliasSeq!(byte, char, dchar, double, float, int, long, short, ubyte, uint, ulong, ushort, void, wchar)) {
	mixin(q{
		class TypeInfo_}~type.mangleof~q{ : TypeInfo {
			override size_t size() const { return type.sizeof; }
			override bool equals(void* a, void* b) {

				static if(is(type == void))
					return false;
				else
				return (*(cast(type*) a) == (*(cast(type*) b)));
			}
		}
		class TypeInfo_A}~type.mangleof~q{ : TypeInfo_Array {
			override const(TypeInfo) next() const { return typeid(type); }
			override bool equals(void* av, void* bv) {

				type[] a = *(cast(type[]*) av);
				type[] b = *(cast(type[]*) bv);


				static if(is(type == void))
					return false;
				else {
					for(int i = 0; i < a.length; i++)
						if(a[i] != b[i]) return false;
					return true;
				}
			}
		}
	});
}

struct Interface {
	TypeInfo_Class classinfo;
	void*[] vtbl;
	size_t offset;
}

class Object {
    bool opEquals(Object o)
    {
        return this is o;
    }
}

class TypeInfo  {
	const(TypeInfo) next() const { return this; }
	size_t size() const { return 1; }

	bool equals(void* a, void* b) { 
		writelnf("##### missing equals from TypeInfo somewhere!!!");
		return false; 
	}
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

	
	override bool equals(void* p1, void* p2) {
		return base.equals(p1, p2);
	}
}

class TypeInfo_Pointer : TypeInfo {
	TypeInfo m_next;

	override size_t size() const { return (void*).sizeof; }
	override bool equals(in void* p1, in void* p2) 
    {
        return *cast(void**)p1 == *cast(void**)p2;
    }
	override const(TypeInfo) next() const { return m_next; }

}

class TypeInfo_Array : TypeInfo {
	TypeInfo value;
	override size_t size() const { return (void[]).sizeof; }
	override const(TypeInfo) next() const { return value; }

	override bool equals(void* p1, void* p2) {
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        if (a1.length != a2.length)
            return false;
        size_t sz = value.size;
        for (size_t i = 0; i < a1.length; i++)
        {
            if (!value.equals(a1.ptr + i * sz, a2.ptr + i * sz))
                return false;
        }
        return true;
	}
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
                return false;
        }
        return true;
	}

}

class AAA : TypeInfo
{
	
    TypeInfo base;
}

import dbg;

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

    override bool equals(in void* p1, in void* p2)
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

extern(C) void* _d_dynamic_cast(Object o, TypeInfo_Class c) {
	void* res = null;
	size_t offset = 0;
	if (o && _d_isbaseof2(typeid(o), c, offset))
	{
		res = cast(void*) o + offset;
	}
	return res;
}

extern(C)
int _d_isbaseof2(scope TypeInfo_Class oc, scope const TypeInfo_Class c, scope ref size_t offset) @safe

{
    if (oc is c)
        return true;

    do
    {
        if (oc.base is c)
            return true;

        // Bugzilla 2013: Use depth-first search to calculate offset
        // from the derived (oc) to the base (c).
        foreach (iface; oc.interfaces)
        {
            if (iface.classinfo is c || _d_isbaseof2(iface.classinfo, c, offset))
            {
                offset += iface.offset;
                return true;
            }
        }

        oc = oc.base;
    } while (oc);

    return false;
}


extern(C) void _d_assert(string file, uint line) {
	import dbg;
	writelnf("D_ASSERT: ", file, line);
	wasm.abort();
}






// The compiler lowers `lhs == rhs` to `__equals(lhs, rhs)` for
// * dynamic arrays,
// * (most) arrays of different (unqualified) element types, and
// * arrays of structs with custom opEquals.

 // The scalar-only overload takes advantage of known properties of scalars to
 // reduce template instantiation. This is expected to be the most common case.
bool __equals(T1, T2)(scope const T1[] lhs, scope const T2[] rhs)
@nogc nothrow pure @trusted
if (__traits(isScalar, T1) && __traits(isScalar, T2))
{
    if (lhs.length != rhs.length)
        return false;

    static if (T1.sizeof == T2.sizeof
        // Signedness needs to match for types that promote to int.
        // (Actually it would be okay to memcmp bool[] and byte[] but that is
        // probably too uncommon to be worth checking for.)
        && (T1.sizeof >= 4 || __traits(isUnsigned, T1) == __traits(isUnsigned, T2))
        && !__traits(isFloating, T1) && !__traits(isFloating, T2))
    {
        if (!__ctfe)
        {
            // This would improperly allow equality of integers and pointers
            // but the CTFE branch will stop this function from compiling then.
            import core.stdc.string : memcmp;
            return lhs.length == 0 ||
                0 == memcmp(cast(const void*) lhs.ptr, cast(const void*) rhs.ptr, lhs.length * T1.sizeof);
        }
    }

    foreach (const i; 0 .. lhs.length)
        if (lhs.ptr[i] != rhs.ptr[i])
            return false;
    return true;
}

bool __equals(T1, T2)(scope T1[] lhs, scope T2[] rhs)
if (!__traits(isScalar, T1) || !__traits(isScalar, T2))
{
    if (lhs.length != rhs.length)
        return false;

    if (lhs.length == 0)
        return true;

    static if (useMemcmp!(T1, T2))
    {
        if (!__ctfe)
        {
            static bool trustedMemcmp(scope T1[] lhs, scope T2[] rhs) @trusted @nogc nothrow pure
            {
                pragma(inline, true);
                import core.stdc.string : memcmp;
                return memcmp(cast(void*) lhs.ptr, cast(void*) rhs.ptr, lhs.length * T1.sizeof) == 0;
            }
            return trustedMemcmp(lhs, rhs);
        }
        else
        {
            foreach (const i; 0 .. lhs.length)
            {
                if (at(lhs, i) != at(rhs, i))
                    return false;
            }
            return true;
        }
    }
    else
    {
        foreach (const i; 0 .. lhs.length)
        {
            if (at(lhs, i) != at(rhs, i))
                return false;
        }
        return true;
    }
}
