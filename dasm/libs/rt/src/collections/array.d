module collections.array;

import memory;
import dbg;

struct Array(T)
{
    Allocator* allocator;

    T* _items;
    private size_t _count = 0;
    size_t capacity = 0;

    static Array createWith(Allocator* allocator, size_t capacity = 16)
    {
        Array ret;
        ret.allocator = allocator;
        ret._count = 0;
        ret.capacity = capacity;
        ret._items = cast(T*) allocator.allocate(capacity * T.sizeof);
        return ret;
    }

    void create(Allocator* allocator, size_t capacity = 16)
    {
        this.allocator = allocator;
        this._count = 0;
        this.capacity = capacity;    
        _items =cast(T*) allocator.allocate(capacity * T.sizeof);    
    }

    void dispose()
    {
        allocator.free(_items);
        allocator = null;
    }

    size_t length()
    {
        return _count;
    }

    bool empty()
    {
        return _count == 0;
    }

    ref T opIndex(size_t index)
    {
        if ((index < 0) || (index >= _count))
            panic("out of bound");
        return _items[index];
    }

    void opIndexAssign(T value, in size_t index)
    {
        if (index >= _count)
            panic("out of bound");
        _items[index] = value;
    }


    // utility foreach
    void for_each(scope void delegate(T) dg)
    {
        for (int i = 0; i < _count; i++)
            dg(_items[i]);
    }


    // foreach
    int opApply(int delegate(ref T) dg)
    {
        int result;
        //foreach (ref T item; _items)
        for (int i = 0; i < _count; i++)
            if ((result = dg(_items[i])) != 0)
                break;
        return result;
    }

    int opApply(int delegate(size_t, ref T) dg)
    {
        int result;
        //foreach (ref T item; _items)
        for (size_t i = 0; i < _count; i++)
            if ((result = dg(i, _items[i])) != 0)
                break;
        return result;
    }

    // --

    T get(size_t index)
    {
        if ((index < 0) || (index >= _count))
            panic("out of bound");
        return _items[index];
    }

    void set(size_t index, ref T value)
    {
        if (index >= _count)
            panic("out of bound");
        _items[index] = value;
    }

    void ensureTotalCapacity(size_t new_capacity)
    {
        assert(allocator, "allocator is null");

        size_t better_capacity = capacity;
        if (better_capacity >= new_capacity) return;

        while (true) {
            better_capacity += better_capacity / 2 + 8;
            if (better_capacity >= new_capacity) break;
        }

        size_t originalLength = capacity;
        size_t diff = new_capacity - capacity;

        // TODO This can be optimized to avoid needlessly copying undefined memory.
        T* new_memory = cast(T*) allocator.reallocate(_items, better_capacity * T.sizeof);
        _items = new_memory;
        capacity = better_capacity;
        
        if (diff > 0)
        {
            // todo: fill stuff with default values
            for (size_t i = originalLength; i < originalLength + diff; i++)
            {
                _items[i] = T.init;
            }
        }
    }

    void expandToCapacity()
    {
        _count = capacity;
    }

    void resize(size_t newSize)
    {
        ensureTotalCapacity(cast(int)newSize);
        _count = cast(int) newSize;
    }

    void clear()
    {
        for (int i = 0; i < _count; i++)
        {
            _items[i] = T.init;
        }

        _count = 0;
    }

    T* add_get(T item)
    {
        auto length = capacity;
        if (_count + 1 > length)
        {
            //auto expand = (length < 1000) ? (length + 1) * 4 : 1000;
            auto expand = (length + 1) * 4;

            ensureTotalCapacity(length + expand);
        }

        auto pos = _count;
        _items[_count++] = item;
        return &_items[pos];
    }

    void add(T item)
    {
        auto length = capacity;
        if (_count + 1 > length)
        {
            //auto expand = (length < 1000) ? (length + 1) * 4 : 1000;
            auto expand = (length + 1) * 4;

            ensureTotalCapacity(length + expand);
        }

        _items[_count++] = item;
    }

    void add_all(ref Array!T items)
    {
        // todo: optimize, should be a memcpy
        for (int i = 0; i < items.length(); i++)
            add(items[i]);
    }

    void insert(size_t index, T item)
    {
        assert(index < _count);

		if (_count == capacity)
        {
            ensureTotalCapacity(max(8, cast(size_t)(capacity * 1.75f)));
        }
		
        //System.arraycopy(items, index, items, index + 1, size - index);
        memcpy(_items, _items + 1, _count - index);
		_count++;
		_items[index] = item;
    }

    bool remove(T item)
    {
        for (int i = 0; i < _count; i++)
        {
            if (_items[i] == item)
            {
                return remove_at(i);
            }
        }
        return false;
    }


    // TODO: add tests for both of them
    T removeSwap(size_t index)
    {
        if (length - 1 == index) return pop();
        
         auto old_item = _items[index];
         _items[index] = pop();
         return old_item;
    }

    T pop()
    {
        auto val = _items[length - 1];
        _count -= 1;
        return val;
    }

    int index_of(T item)
    {
        for (int i = 0; i < _count; i++)
            if (_items[i] == item)
                return i;
        return -1;
    }
    
    bool contains(T item)
    {
        for (int i = 0; i < _count; i++)
            if (_items[i] == item)
                return true;
        return false;
    }

    bool remove_at(size_t index)
    {
        T val = _items[index];
        _count--;

        static if (__traits(isPOD, T))
        {
            memmove(_items + index, // dest
                    _items + index + 1, // src
                    (_count - index) * T.sizeof); // num bytes
        }
        else
        {
            for (auto j = index; j < _count; j++)
            {
                _items[j] = _items[j + 1];
            }
        }
        return true;
    }

    bool remove_back()
    {
        return remove_at(_count - 1);
    }

    T[] get_slice()
    {
        return _items[0 .. _count];
    }

    ref T back()
    {
        assert(_count > 0);
        return _items[_count - 1];
    }
}

package:

size_t max(size_t a, size_t b)
{
    return a < b ? b : a;
}