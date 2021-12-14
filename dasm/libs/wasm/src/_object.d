module object;

version(WASM):


/+
    # !!!!!!

    This file is a meess, this is a workaround because thre is a compiler issue with static float array comparisons,
    they doesn't work with -betterC

    So until that issue is sorted out, we'll have to rely on this mess of a file
+/

import mem = rt.memz;
import rt.dbg;
import wasm = wasm;

export extern extern(C) byte __heap_base;
int heap_base;

// TODO: 32bit / 64bit, don't forget tochange that
alias size_t = uint;
alias ptrdiff_t = int;

alias sizediff_t = ptrdiff_t; //For backwards compatibility only.

alias hash_t = size_t; //For backwards compatibility only.
alias equals_t = bool; //For backwards compatibility only.

alias string  = immutable(char)[];
alias wstring = immutable(wchar)[];
alias dstring = immutable(dchar)[];

/+
    mem must be 0 (it is index of memory thing)
    delta is in 64 KB pages
    return OLD size in 64 KB pages, or size_t.max if it failed.
+/
pragma(LDC_intrinsic, "llvm.wasm.memory.grow.i32")
extern(C) int llvm_wasm_memory_grow(int mem, int delta);


// in 64 KB pages
pragma(LDC_intrinsic, "llvm.wasm.memory.size.i32")
extern(C) int llvm_wasm_memory_size(int mem);


extern(C) int _Dmain(string[] args);
int __heap_base__aligned;
export extern(C) void _start(int heap_base)
{
    
    int addr =  cast(int) cast(int*) &__heap_base;
    int alignedFOUR = addr &= -4;
    __heap_base__aligned = alignedFOUR;
    writeln("_start called, heap_base: {} {} {}", heap_base, *cast(int*) __heap_base, __heap_base__aligned);
    _Dmain(null);
}

extern(C) bool _xopEquals(in void*, in void*)
{ 
    assert(0);
}

// extern(C) int memcmp(const(void)* s1, const(void*) s2, size_t len) {
//     ubyte *p = cast(ubyte*)s1;
//     ubyte *q = cast(ubyte*)s2;
//     int charCompareStatus = 0;
//     //If both pointer pointing same memory block
//     if (s1 == s2)
//     {
//         return charCompareStatus;
//     }
//     while (len > 0)
//     {
//         if (*p != *q)
//         {
//             //compare the mismatching character
//             charCompareStatus = (*p >*q)?1:-1;
//             break;
//         }
//         len--;
//         p++;
//         q++;
//     }
//     return charCompareStatus;
// }

extern(C) bool _xopCmp(in void*, in void*) 
{
    assert(0);
    //return false;
}


extern(C) void _d_arraybounds_slice(string file, uint line, size_t lower, size_t upper, size_t length)
{
    writeln("out of bounds");
    assert(0);
}

extern(C) void _d_arraybounds_index(string file, uint line, size_t index, size_t length)
{
    writeln("out of bounds");
    assert(0);
}

extern(C) void _d_arraybounds(string file, size_t line) { //, size_t lwr, size_t upr, size_t length) {
    writeln("out of bounds");
    assert(0);
}

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
    {
        static if (__traits(isStaticArray, at(lhs, 0))) // "Fix" for -betterC
        {
            if (at(lhs, i)[] != at(rhs, i)[]) // T1[N] != T2[N] doesn't compile with -betterC.
                return false;
        }
        else
        {
            if (at(lhs, i) != at(rhs, i))
                return false;
        }
    }
    return true;
}

bool __equals(T1, T2)(scope T1[] lhs, scope T2[] rhs)
if (!__traits(isScalar, T1) || !__traits(isScalar, T2))
{
    if (lhs.length != rhs.length)
    {
        return false;
    }
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
                static if (__traits(isStaticArray, at(lhs, 0))) // "Fix" for -betterC
                {
                    if (at(lhs, i)[] != at(rhs, i)[]) // T1[N] != T2[N] doesn't compile with -betterC.
                        return false;
                }
                else
                {
                    if (at(lhs, i) != at(rhs, i))
                        return false;
                }
            }
            return true;
        }
    }
    else
    {

    foreach (const i; 0 .. lhs.length)
    {
        static if (__traits(isStaticArray, at(lhs, 0))) // "Fix" for -betterC
        {
            if (at(lhs, i)[] != at(rhs, i)[]) // T1[N] != T2[N] doesn't compile with -betterC.
                return false;
        }
        else
        {
            if (at(lhs, i) != at(rhs, i))
                return false;
        }
    }
        return true;
    }
}

pragma(inline, true)
ref at(T)(T[] r, size_t i) @trusted
    // exclude opaque structs due to https://issues.dlang.org/show_bug.cgi?id=20959
    if (!(is(T == struct) && !is(typeof(T.sizeof))))
{
    static if (is(immutable T == immutable void))
        return (cast(ubyte*) r.ptr)[i];
    else
        return r.ptr[i];
}

template BaseType(T)
{
    static if (__traits(isStaticArray, T))
        alias BaseType = BaseType!(typeof(T.init[0]));
    else static if (is(immutable T == immutable void))
        alias BaseType = ubyte;
    else static if (is(T == E*, E))
        alias BaseType = size_t;
    else
        alias BaseType = T;
}

template useMemcmp(T1, T2)
{
    static if (T1.sizeof != T2.sizeof)
        enum useMemcmp = false;
    else
    {
        alias B1 = BaseType!T1;
        alias B2 = BaseType!T2;
        enum useMemcmp = __traits(isIntegral, B1) && __traits(isIntegral, B2)
           && !( (B1.sizeof < 4 || B2.sizeof < 4) && __traits(isUnsigned, B1) != __traits(isUnsigned, B2) );
    }
}



TTo[] __ArrayCast(TFrom, TTo)(return scope TFrom[] from)
{
   const fromSize = from.length * TFrom.sizeof;
   const toLength = fromSize / TTo.sizeof;

   if ((fromSize % TTo.sizeof) != 0)
   {
        //onArrayCastError(TFrom.stringof, fromSize, TTo.stringof, toLength * TTo.sizeof);
        wasm.abort();
        assert(0);
   }

   struct Array
   {
       size_t length;
       void* ptr;
   }
   auto a = cast(Array*)&from;
   a.length = toLength; // jam new length
   return *cast(TTo[]*)a;
}


extern(C) void _d_array_slice_copy(void* dst, size_t dstlen, void* src, size_t srclen, size_t elemsz) {
    auto d = cast(ubyte*) dst;
    auto s = cast(ubyte*) src;
    auto len = dstlen * elemsz;

    while(len) {
        *d = *s;
        d++;
        s++;
        len--;
    }

}

extern(C) void __switch_error()(string file = __FILE__, size_t line = __LINE__)
{
    //__switch_errorT(file, line);
    wasm.abort();
}

extern(C) int __switch(T, caseLabels...)(/*in*/ const scope T[] condition) pure nothrow @safe @nogc
{
    // This closes recursion for other cases.
    static if (caseLabels.length == 0)
    {
        return int.min;
    }
    else static if (caseLabels.length == 1)
    {
        return __cmp(condition, caseLabels[0]) == 0 ? 0 : int.min;
    }
    // To be adjusted after measurements
    // Compile-time inlined binary search.
    else static if (caseLabels.length < 7)
    {
        int r = void;
        enum mid = cast(int)caseLabels.length / 2;
        if (condition.length == caseLabels[mid].length)
        {
            r = __cmp(condition, caseLabels[mid]);
            if (r == 0) return mid;
        }
        else
        {
            // Equivalent to (but faster than) condition.length > caseLabels[$ / 2].length ? 1 : -1
            r = ((condition.length > caseLabels[mid].length) << 1) - 1;
        }

        if (r < 0)
        {
            // Search the left side
            return __switch!(T, caseLabels[0 .. mid])(condition);
        }
        else
        {
            // Search the right side
            return __switch!(T, caseLabels[mid + 1 .. $])(condition) + mid + 1;
        }
    }
    else
    {
        // Need immutable array to be accessible in pure code, but case labels are
        // currently coerced to the switch condition type (e.g. const(char)[]).
        pure @trusted nothrow @nogc asImmutable(scope const(T[])[] items)
        {
            assert(__ctfe); // only @safe for CTFE
            immutable T[][caseLabels.length] result = cast(immutable)(items[]);
            return result;
        }
        static immutable T[][caseLabels.length] cases = asImmutable([caseLabels]);

        // Run-time binary search in a static array of labels.
        return __switchSearch!T(cases[], condition);
    }
}

extern(C) int __cmp(T)(scope const T[] lhs, scope const T[] rhs) @trusted
    if (__traits(isScalar, T))
{
    // Compute U as the implementation type for T
    static if (is(T == ubyte) || is(T == void) || is(T == bool))
        alias U = char;
    else static if (is(T == wchar))
        alias U = ushort;
    else static if (is(T == dchar))
        alias U = uint;
    else static if (is(T == ifloat))
        alias U = float;
    else static if (is(T == idouble))
        alias U = double;
    else static if (is(T == ireal))
        alias U = real;
    else
        alias U = T;

    static if (is(U == char))
    {
        import core.internal.string : dstrcmp;
        return dstrcmp(cast(char[]) lhs, cast(char[]) rhs);
    }
    else static if (!is(U == T))
    {
        // Reuse another implementation
        return __cmp(cast(U[]) lhs, cast(U[]) rhs);
    }
    else
    {
        version (BigEndian)
        static if (__traits(isUnsigned, T) ? !is(T == __vector) : is(T : P*, P))
        {
            if (!__ctfe)
            {
                int c = mem.memcmp(lhs.ptr, rhs.ptr, (lhs.length <= rhs.length ? lhs.length : rhs.length) * T.sizeof);
                if (c)
                    return c;
                static if (size_t.sizeof <= uint.sizeof && T.sizeof >= 2)
                    return cast(int) lhs.length - cast(int) rhs.length;
                else
                    return int(lhs.length > rhs.length) - int(lhs.length < rhs.length);
            }
        }

        immutable len = lhs.length <= rhs.length ? lhs.length : rhs.length;
        foreach (const u; 0 .. len)
        {
            static if (__traits(isFloating, T))
            {
                immutable a = lhs.ptr[u], b = rhs.ptr[u];
                static if (is(T == cfloat) || is(T == cdouble)
                    || is(T == creal))
                {
                    // Use rt.cmath2._Ccmp instead ?
                    auto r = (a.re > b.re) - (a.re < b.re);
                    if (!r) r = (a.im > b.im) - (a.im < b.im);
                }
                else
                {
                    const r = (a > b) - (a < b);
                }
                if (r) return r;
            }
            else if (lhs.ptr[u] != rhs.ptr[u])
                return lhs.ptr[u] < rhs.ptr[u] ? -1 : 1;
        }
        return (lhs.length > rhs.length) - (lhs.length < rhs.length);
    }
}

// This function is called by the compiler when dealing with array
// comparisons in the semantic analysis phase of CmpExp. The ordering
// comparison is lowered to a call to this template.
extern(C) int __cmp(T1, T2)(T1[] s1, T2[] s2)
if (!__traits(isScalar, T1) && !__traits(isScalar, T2))
{
    alias U1 = Unqual!T1;
    alias U2 = Unqual!T2;

    static if (is(U1 == void) && is(U2 == void))
        static @trusted ref inout(ubyte) at(inout(void)[] r, size_t i) { return (cast(inout(ubyte)*) r.ptr)[i]; }
    else
        static @trusted ref R at(R)(R[] r, size_t i) { return r.ptr[i]; }

    // All unsigned byte-wide types = > dstrcmp
    immutable len = s1.length <= s2.length ? s1.length : s2.length;

    foreach (const u; 0 .. len)
    {
        static if (__traits(compiles, __cmp(at(s1, u), at(s2, u))))
        {
            auto c = __cmp(at(s1, u), at(s2, u));
            if (c != 0)
                return c;
        }
        else static if (__traits(compiles, at(s1, u).opCmp(at(s2, u))))
        {
            auto c = at(s1, u).opCmp(at(s2, u));
            if (c != 0)
                return c;
        }
        else static if (__traits(compiles, at(s1, u) < at(s2, u)))
        {
            if (at(s1, u) != at(s2, u))
                return at(s1, u) < at(s2, u) ? -1 : 1;
        }
        else
        {
            // TODO: fix this legacy bad behavior, see
            // https://issues.dlang.org/show_bug.cgi?id=17244
            static assert(is(U1 == U2), "Internal error.");
            auto c = (() @trusted => mem.memcmp(&at(s1, u), &at(s2, u), U1.sizeof))();
            if (c != 0)
                return c;
        }
    }
    return (s1.length > s2.length) - (s1.length < s2.length);
}


template Unqual(T : const U, U)
{
    static if (is(U == shared V, V))
        alias Unqual = V;
    else
        alias Unqual = U;
}


// binary search in sorted string cases, also see `__switch`.
private int __switchSearch(T)(/*in*/ const scope T[][] cases, /*in*/ const scope T[] condition) pure nothrow @safe @nogc
{
    size_t low = 0;
    size_t high = cases.length;

    do
    {
        auto mid = (low + high) / 2;
        int r = void;
        if (condition.length == cases[mid].length)
        {
            r = __cmp(condition, cases[mid]);
            if (r == 0) return cast(int) mid;
        }
        else
        {
            // Generates better code than "expr ? 1 : -1" on dmd and gdc, same with ldc
            r = ((condition.length > cases[mid].length) << 1) - 1;
        }

        if (r > 0) low = mid + 1;
        else high = mid;
    }
    while (low < high);

    // Not found
    return -1;
}


// TypeInfo stuff

struct Interface
{
    TypeInfo_Class classinfo;
    void*[] vtbl;
    size_t offset;
}

class Object
{

}

class TypeInfo
{
    const(TypeInfo) next() const
    {
        return this;
    }

    size_t size() const
    {
        return 1;
    }

    bool equals(void* a, void* b)
    {
        return false;
    }

    int compare(in void* p1, in void* p2) const
    {
        return 0;
    }

    void swap(void* p1, void* p2) const
    {
        assert(0);
    }
}

class TypeInfo_Class : TypeInfo
{
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

    override size_t size() const
    {
        return size_t.sizeof;
    }
}

class TypeInfo_Const : TypeInfo
{
    size_t getHash(in void*) nothrow
    {
        return 0;
    }

    TypeInfo base;
    override size_t size() const
    {
        return base.size();
    }

    override const(TypeInfo) next() const
    {
        return base.next();
    }

    override bool equals(void* p1, void* p2)
    {
        return base.equals(p1, p2);
    }
}

class TypeInfo_Pointer : TypeInfo
{
    TypeInfo m_next;

    override size_t size() const
    {
        return (void*).sizeof;
    }

    override bool equals(in void* p1, in void* p2)
    {
        return *cast(void**) p1 == *cast(void**) p2;
    }

    override const(TypeInfo) next() const
    {
        return m_next;
    }

}

class TypeInfo_Array : TypeInfo
{
    TypeInfo value;
    override size_t size() const
    {
        return (void[]).sizeof;
    }

    override const(TypeInfo) next() const
    {
        return value;
    }

    override bool equals(void* p1, void* p2)
    {
        void[] a1 = *cast(void[]*) p1;
        void[] a2 = *cast(void[]*) p2;

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

class TypeInfo_StaticArray : TypeInfo
{
    TypeInfo value;
    size_t len;
    override size_t size() const
    {
        return value.size() * len;
    }

    override const(TypeInfo) next() const
    {
        return value;
    }

    override bool equals(void* p1, void* p2)
    {
        size_t sz = value.size;
        for (size_t u = 0; u < len; u++)
        {
            if (!value.equals(p1 + u * sz, p2 + u * sz))
                return false;
        }
        return true;
    }

}

class TypeInfo_Enum : TypeInfo
{

    TypeInfo base;
    string name;
    void[] m_init;

    override bool equals(void* p1, void* p2)
    {
        return base.equals(p1, p2);
    }

    override size_t size() const
    {
        return base.size();
    }

    override const(TypeInfo) next() const
    {
        return base.next();
    }

}

class TypeInfo_Function : TypeInfo
{

    TypeInfo next;
    string deco;

    override size_t size() const
    {
        return 0;
    }
}

class TypeInfo_Struct : TypeInfo
{
    string name;
    void[] m_init;
    void* xtohash;
    bool function(in void*, in void*) xopEquals;
    int function(in void*, in void*) xopCmp;
    void* xtostring;
    uint flags;
    union
    {
        void function(void*) dtor;
        void function(void*, const TypeInfo_Struct) xdtor;
    }

    void function(void*) postblit;
    uint align_;
    immutable(void)* rtinfo;

    override size_t size() const
    {
        return m_init.length;
    }

    override bool equals(in void* p1, in void* p2)
    {
        if (!p1 || !p2)
            return false;
        else if (xopEquals)
            return (*xopEquals)(p1, p2);
        else if (p1 == p2)
            return true;
        else
        {
            assert(0);
            // BUG: relies on the GC not moving objects
            // return mem.memcmp(p1, p2, m_init.length) == 0;
        }
    }

}

class TypeInfo_Delegate : TypeInfo
{
    TypeInfo next;
    string deco;
    override size_t size() const
    {
        alias dg = int delegate();
        return dg.sizeof;
    }

    override bool equals(in void* p1, in void* p2)
    {
        auto dg1 = *cast(void delegate()*) p1;
        auto dg2 = *cast(void delegate()*) p2;
        return dg1 == dg2;
    }
}

class TypeInfo_Tuple : TypeInfo
{

    TypeInfo[] elements;
    override size_t size() const
    {
        assert(0);
    }

    override bool equals(in void* p1, in void* p2)
    {
        assert(0);
    }
}

class TypeInfo_Invariant : TypeInfo
{
    size_t getHash(in void*) nothrow
    {
        return 0;
    }

    TypeInfo base;
    override size_t size() const
    {
        return base.size;
    }

    override const(TypeInfo) next() const
    {
        return base;
    }
}

class TypeInfo_Shared : TypeInfo
{
    size_t getHash(in void*) nothrow
    {
        return 0;
    }

    TypeInfo base;
    override size_t size() const
    {
        return base.size;
    }

    override const(TypeInfo) next() const
    {
        return base;
    }
}

class TypeInfo_Inout : TypeInfo
{
    size_t getHash(in void*) nothrow
    {
        return 0;
    }

    TypeInfo base;
    override size_t size() const
    {
        return base.size;
    }

    override const(TypeInfo) next() const
    {
        return base;
    }
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

extern (C) int _adEq2(void[] a1, void[] a2, TypeInfo ti)
{
    if (a1.length != a2.length)
        return 0; // not equal
    if (!ti.equals(&a1, &a2))
        return 0;
    return 1;
}

extern (C) void* _d_dynamic_cast(Object o, TypeInfo_Class c)
{
    void* res = null;
    size_t offset = 0;
    if (o && _d_isbaseof2(typeid(o), c, offset))
    {
        res = cast(void*) o + offset;
    }
    return res;
}

extern (C) int _d_isbaseof2(scope TypeInfo_Class oc, scope const TypeInfo_Class c, scope ref size_t offset) @safe
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
    }
    while (oc);

    return false;
}

extern (C) byte[] _d_arrayappendcTX(const TypeInfo ti, ref byte[] px, size_t n) @trusted
{
    assert(0);
}

extern (C) void[] _d_arrayappendT(const TypeInfo ti, ref byte[] x, byte[] y)
{
    auto length = x.length;
    auto tinext = ti.next;
    auto sizeelem = tinext. /*t*/ size; // array element size
    _d_arrayappendcTX(ti, x, y.length);
    mem.memcpy(x.ptr + length * sizeelem, y.ptr, y.length * sizeelem);

    // do postblit
    //__doPostblit(x.ptr + length * sizeelem, y.length * sizeelem, tinext);
    return x;
}

// from spasm

void _d_array_init_i16(ushort* a, size_t n, ushort v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_i32(uint* a, size_t n, uint v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_i64(ulong* a, size_t n, ulong v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_float(float* a, size_t n, float v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_double(double* a, size_t n, double v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_real(real* a, size_t n, real v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_pointer(void** a, size_t n, void* v)
{
    auto p = a;
    auto end = a + n;
    while (p !is end)
        *p++ = v;
}

void _d_array_init_mem(void* a, size_t na, void* v, size_t nv)
{
    auto p = a;
    auto end = a + na * nv;
    while (p !is end)
    {
        version (LDC)
        {
            import ldc.intrinsics;

            llvm_memcpy(p, v, nv, 0);
        }
        else
            memcpy(p, v, nv);
        p += nv;
    }
}