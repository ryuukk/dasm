module collections.hashmap;

import dbg;
import memory;

struct HashMap(Key, Value,
        Hasher = HashFunc!(Key), Comparer = HashComp!(Key),
        ubyte MIN_HASH_TABLE_POWER = 3, ubyte RELATIONSHIP = 8)
{

    static struct Pair
    {
        Key key;
        Value value;
    }

    static struct Element
    {
        uint hash = 0;
        Element* next = null;
        Pair pair;
    }

    Element** hash_table = null;
    ubyte hash_table_power = 0;
    uint elements = 0;
    Allocator* allocator = null;

    static HashMap create(Allocator* alloc)
    {
        HashMap ret;
        ret.allocator = alloc;
        return ret;
    }

    private:
    void make_hash_table()
    {
        if (!allocator)
            allocator = &MALLOCATOR.base;

        auto s = (Element*).sizeof * (1 << MIN_HASH_TABLE_POWER);

        hash_table = cast(Element**) allocator.allocate(s);
        hash_table_power = MIN_HASH_TABLE_POWER;
        elements = 0;
        for (int i = 0; i < (1 << MIN_HASH_TABLE_POWER); i++)
        {
            hash_table[i] = null;
        }
    }

    void erase_hash_table()
    {
        //ERR_FAIL_COND_MSG(elements, "Cannot erase hash table if there are still elements inside.");
        //memdelete_arr(hash_table);

        allocator.free(hash_table);
        hash_table = null;
        hash_table_power = 0;
        elements = 0;
    }

    void check_hash_table()
    {
        int new_hash_table_power = -1;

        if (cast(int) elements > ((1 << hash_table_power) * RELATIONSHIP))
        {
            /* rehash up */
            new_hash_table_power = hash_table_power + 1;

            while (cast(int) elements > ((1 << new_hash_table_power) * RELATIONSHIP))
            {
                new_hash_table_power++;
            }

        }
        else if ((hash_table_power > cast(int) MIN_HASH_TABLE_POWER) && (
                cast(int) elements < ((1 << (hash_table_power - 1)) * RELATIONSHIP)))
        {
            /* rehash down */
            new_hash_table_power = hash_table_power - 1;

            while (cast(int) elements < ((1 << (new_hash_table_power - 1)) * RELATIONSHIP))
            {
                new_hash_table_power--;
            }

            if (new_hash_table_power < cast(int) MIN_HASH_TABLE_POWER)
            {
                new_hash_table_power = MIN_HASH_TABLE_POWER;
            }
        }

        if (new_hash_table_power == -1)
        {
            return;
        }

        //Element **new_hash_table = memnew_arr(Element*, (cast(ulong)1 << new_hash_table_power));
        Element** new_hash_table = cast(Element**) allocator.allocate((Element*).sizeof * (cast(size_t) 1 << new_hash_table_power));
        //ERR_FAIL_COND_MSG(!new_hash_table, "Out of memory.");

        for (int i = 0; i < (1 << new_hash_table_power); i++)
        {
            new_hash_table[i] = null;
        }

        if (hash_table)
        {
            for (int i = 0; i < (1 << hash_table_power); i++)
            {
                while (hash_table[i])
                {
                    Element* se = hash_table[i];
                    hash_table[i] = se.next;
                    int new_pos = se.hash & ((1 << new_hash_table_power) - 1);
                    se.next = new_hash_table[new_pos];
                    new_hash_table[new_pos] = se;
                }
            }
            //memdelete_arr(hash_table);
            allocator.free(hash_table);
        }
        hash_table = new_hash_table;
        hash_table_power = cast(ubyte) new_hash_table_power;
    }

    const Element* get_element(const ref Key p_key)
    {

        if (!hash_table)
            return null;

        uint hash = Hasher.hash(p_key);
        uint index = hash & ((1 << hash_table_power) - 1);

        Element* e = cast(Element*) hash_table[index];

        while (e)
        {
            /* checking hash first avoids comparing key, which may take longer */
            if (e.hash == hash && Comparer.compare(e.pair.key, p_key))
            {
                /* the pair exists in this hashtable, so just update data */
                return e;
            }
            e = e.next;
        }

        return null;
    }

    Element* create_element(const ref Key p_key)
    {
        /* if element doesn't exist, create it */
        Element* e = cast(Element*) allocator.allocate(Element.sizeof);
        //ERR_FAIL_COND_V_MSG(!e, nullptr, "Out of memory.");
        uint hash = Hasher.hash(p_key);
        uint index = hash & ((1 << hash_table_power) - 1);
        e.next = hash_table[index];
        e.hash = hash;
        e.pair.key = cast(Key)p_key; // TODO: when i use pointer as key, i need this
        e.pair.value = Value.init;

        hash_table[index] = e;
        elements++;
        return e;
    }

    public:
    Element* set(const ref Key key, const ref Value value)
    {
        Element* e = null;
        if (!hash_table)
        {
            make_hash_table(); // if no table, make one
        }
        else
        {
            e = cast(Element*)(get_element(key));
        }

        /* if we made it up to here, the pair doesn't exist, create and assign */

        if (!e)
        {
            e = create_element(key);
            if (!e)
            {
                return null;
            }
            check_hash_table(); // perform mantenience routine
        }

        e.pair.value = cast(Value) value;
        return e;
    }

    ref Value get(const ref Key p_key)
    {
        Value* res = getptr(p_key);
        //CRASH_COND_MSG(!res, "Map key not found.");
        return *res;
    }

    Value* getptr(const ref Key p_key)
    {
        if (!hash_table)
        {
            return null;
        }

        Element* e = cast(Element*)(get_element(p_key));

        if (e)
        {
            return &e.pair.value;
        }

        return null;
    }

    bool erase(const ref Key p_key)
    {
        if (!hash_table)
        {
            return false;
        }

        uint hash = Hasher.hash(p_key);
        uint index = hash & ((1 << hash_table_power) - 1);

        Element* e = hash_table[index];
        Element* p = null;
        while (e)
        {
            /* checking hash first avoids comparing key, which may take longer */
            if (e.hash == hash && Comparer.compare(e.pair.key, p_key))
            {
                if (p)
                {
                    p.next = e.next;
                }
                else
                {
                    //begin of list
                    hash_table[index] = e.next;
                }

                allocator.free(e);
                elements--;

                if (elements == 0)
                {
                    erase_hash_table();
                }
                else
                {
                    check_hash_table();
                }
                return true;
            }

            p = e;
            e = e.next;
        }

        return false;
    }

    bool has(const ref Key p_key)
    {
        return getptr(p_key) != null;
    }

    uint size() const {
		return elements;
	}

	bool is_empty() const {
		return elements == 0;
	}

    void clear()
    {
		/* clean up */
		if (hash_table) {
			for (int i = 0; i < (1 << hash_table_power); i++) {
				while (hash_table[i]) {
					Element *e = hash_table[i];
					hash_table[i] = e.next;
                    allocator.free(e);
				}
			}
            allocator.free(hash_table); // TODO: check if that's the right way to delete T**
		}

		hash_table = null;
		hash_table_power = 0;
		elements = 0;
    }

    int opApply(int delegate(Pair*) dg)
    {
        if(!hash_table) return 0;

        int result;
        for (int i = 0; i < (1 << hash_table_power); i++) {
            Element* e = hash_table[i];
            while(e) {
                if ((result = dg(&e.pair)) != 0)
                    break;
                e = e.next;
            }
        }
        return result;
    }

    int opApply(int delegate(Key*, Value*) dg)
    {
        if(!hash_table) return 0;

        int result;
        for (int i = 0; i < (1 << hash_table_power); i++) {
            Element* e = hash_table[i];
            while(e) {
                if ((result = dg(&e.pair.key, &e.pair.value)) != 0)
                    break;
                e = e.next;
            }
        }
        return result;
    }

    void opIndexAssign(const ref Value value, const Key key) {
        set(key, value);
    }

    // TODO: how to handle error
    ref Value opIndex(const ref Key key) {
        if(!has(key)) panic("key not found");
        return get(key);
    }

}

struct HashFunc(T)
{
    static uint hash(const ref T v)
    {
        static if(is(T == U*, U) && __traits(isScalar, T)) 
        {
            return hash_one_uint64(cast(ulong) v);
        }
        else static if( is(T == int) || is(T == uint)) 
        {
            return cast(uint) v;
        }
        else static if( is(T == long) || is(T == ulong) ) 
        {
            return hash_one_uint64(cast(ulong) v);
        }
        else static if( is(T == float) || is(T == double) ) 
        {
            return hash_djb2_one_float(v);
        }
        else static if ( is (T == string) )
        {
            return cast(int) string_hash(v);
        }
        else static assert(0, "not supported");
    }
    /*
        static uint hash(const(char)* p_cstr)
        {
            return hash_djb2(p_cstr);
        }

        static uint hash(const ulong p_int)
        {
            return hash_one_uint64(p_int);
        }

        static uint hash(const long p_int)
        {
            return hash(cast(ulong)(p_int));
        }

        static uint hash(const float p_float)
        {
            return hash_djb2_one_float(p_float);
        }

        static uint hash(const double p_double)
        {
            return hash_djb2_one_float(p_double);
        }

        static uint hash(const uint p_int)
        {
            return p_int;
        }

        static uint hash(const int p_int)
        {
            return cast(uint) p_int;
        }

        static uint hash(const ushort p_int)
        {
            return p_int;
        }

        static uint hash(const short p_int)
        {
            return cast(uint) p_int;
        }

        static uint hash(const ubyte p_int)
        {
            return p_int;
        }

        static uint hash(const byte p_int)
        {
            return cast(uint) p_int;
        }

        static uint hash(const char p_uchar)
        {
            return cast(uint) p_uchar;
        }

        static uint hash(const wchar p_wchar)
        {
            return cast(uint) p_wchar;
        }

        static uint hash(const dchar p_uchar)
        {
            return cast(uint) p_uchar;
        }
    */
}

struct HashComp(T)
{
    static bool compare()(const ref T p_lhs, const ref T p_rhs)
    {
        static if(is(T == U*, U) && __traits(isScalar, T)) 
        {
            return p_lhs == p_rhs;
        }
        else static if( is(T == int) || is(T == uint)) 
        {
            return p_lhs == p_rhs;
        }
        else static if( is(T == ulong) || is(T == ulong)) 
        {
            return p_lhs == p_rhs;
        }
        else static if( is(T == float) || is(T == double) ) 
        {
            return (p_lhs == p_rhs) || (is_nan(p_lhs) && is_nan(p_rhs));
        } 
        else static if ( is (T == string) )
        {
            return (p_lhs == p_rhs);
        }
        
        else static assert(0, "not supported");
    }
}

private static ulong string_hash(const(char)[] name)
{
    size_t strlen(const char* txt)
    {
        size_t l = 0;
        while(txt[l] != '\0')
            l++;
        return l;
    }
    size_t length = strlen(name.ptr);
    ulong hash = 0xcbf29ce484222325;
    ulong prime = 0x00000100000001b3;

    for (size_t i = 0; i < length; i++)
    {
        ubyte value = name[i];
        hash = hash ^ value;
        hash *= prime;
    }
    return hash;
}

private static uint hash_djb2(const(char)* p_cstr)
{
    const(ubyte)* chr = cast(const(ubyte)*) p_cstr;
    uint hash = 5381;
    uint c;

    while ((c = *chr++) == 1)
    { // TODO: check == 1
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    }

    return hash;
}

private static ulong hash_djb2_one_float_64(double p_in, ulong p_prev = 5381)
{
    union U
    {
        double d;
        ulong i;
    }

    U u;

    // Normalize +/- 0.0 and NaN values so they hash the same.
    if (p_in == 0.0f)
    {
        u.d = 0.0;
    }
    else if (is_nan(p_in))
    {
        u.d = float.nan;
    }
    else
    {
        u.d = p_in;
    }

    return ((p_prev << 5) + p_prev) + u.i;
}

private static ulong hash_djb2_one_64(ulong p_in, ulong p_prev = 5381)
{
    return ((p_prev << 5) + p_prev) + p_in;
}

private static uint hash_one_uint64(const ulong p_int)
{
    ulong v = p_int;
    v = (~v) + (v << 18); // v = (v << 18) - v - 1;
    v = v ^ (v >> 31);
    v = v * 21; // v = (v + (v << 2)) + (v << 4);
    v = v ^ (v >> 11);
    v = v + (v << 6);
    v = v ^ (v >> 22);
    return cast(int) v;
}

private static uint hash_djb2_one_float(double p_in, uint p_prev = 5381)
{
    union U
    {
        double d;
        ulong i;
    }

    U u;

    // Normalize +/- 0.0 and NaN values so they hash the same.
    if (p_in == 0.0f)
    {
        u.d = 0.0;
    }
    else if (is_nan(p_in))
    {
        u.d = float.nan;
    }
    else
    {
        u.d = p_in;
    }

    return ((p_prev << 5) + p_prev) + hash_one_uint64(u.i);
}

bool is_nan(X)(X x) if (__traits(isFloating, X))
{
    version (all)
    {
        return x != x;
    }
    else
    {
        panic("not supported");
    }
}