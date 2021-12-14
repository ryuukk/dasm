module dawn.ecs.views;

import dawn.ecs;

import rt.dbg;
import rt.memz;
import rt.collections.hashmap;
import rt.collections.array;
import rt.collections.set;


struct BasicView(T)
{
    Storage!(T)* storage;

    static BasicView create(Storage!(T)* s)
    {
        return BasicView(s);
    }

    T* get(T)(entity_t entity)
    {
        return storage.get(entity);
    }

    int opApply(scope int delegate(ref BasicView, entity_t) dg)
    {
        // TODO: should be reverse iteration

        int result = 0;
    
        foreach (entity_t item; storage.set.dense)
        {
            result = dg(this, item);
            if (result)
                break;
        }
        return result;
    }

    int opApply(scope int delegate(entity_t) dg)
    {
        // TODO: should be reverse iteration

        int result = 0;
    
        foreach (entity_t item; storage.set.dense)
        {
            result = dg(item);
            if (result)
                break;
        }
        return result;
    }
}

struct MultiView(size_t n_includes, size_t n_excludes)
{
    Registry* registry;
    size_t[n_includes] type_ids;
    size_t[n_excludes] exclude_type_ids;

    static MultiView create(Registry* reg, size_t[n_includes] includes, size_t[n_excludes] excludes)
    {
        return MultiView(reg, includes, excludes);
    }

    T* get(T)(entity_t entity)
    {
        return registry.assure!(T).get(entity);
    }
    
    bool valid(T)()
    {
        auto t = type_id!T;
        bool v = false;
        foreach (tid; type_ids)
        {
            if (t == tid)
            {
                v = true;
            }
        }

        foreach (tid; exclude_type_ids)
        {
            if(t == tid)
            {
                v = false;
                break;
            }
        }
        return v;
    }

    void sort()
    {
        size_t[n_includes] sub_items;
        for(int i = 0; i < type_ids.length; i++)
        {
            auto ptr = registry.components.get(type_ids[i]);
            auto storage = cast(Storage!(ubyte)*) ptr;
            sub_items[i] = storage.len();
        }

        sortSub(sub_items[0 .. $], type_ids[ 0 .. $], (size_t a, size_t b) {
            return a < b;
        });
    }
    
    int opApply(scope int delegate(ref MultiView, entity_t) dg)
    {
        sort();

        auto ptr = registry.components.get(type_ids[0]);
        auto entities = (cast(Storage!(ubyte)*) ptr).set.dense;

        size_t size = entities.length;
        int result = 0;

        for (size_t i = size; i-- > 0;)
        {
            auto entity = entities.get(i);
            auto valid = true;

            foreach(tid; type_ids)
            {
                auto sptr = registry.components.get(tid);
                auto has = (cast(Storage!(ubyte)*) sptr).contains(entity);
                if(!has) 
                {
                    valid = false;
                    goto keep;
                }
            }

            foreach(tid; exclude_type_ids)
            {
                auto sptr = registry.components.get(tid);
                auto has = (cast(Storage!(ubyte)*) sptr).contains(entity);
                if(has) 
                {
                    valid = false;
                    goto keep;
                }
            }

            keep:

            if(valid)
                result = dg(this, entity);
        }

        //foreach (item; array)
        //{
        //    result = dg(item);
        //    if (result)
        //        break;
        //}
    
        return result;
    }

    int opApply(scope int delegate(entity_t) dg)
    {
        sort();

        auto ptr = registry.components.get(type_ids[0]);
        auto entities = (cast(Storage!(ubyte)*) ptr).set.dense;

        size_t size = entities.length;
        int result = 0;

        for (size_t i = size; i-- > 0;)
        {
            auto entity = entities.get(i);
            auto valid = true;

            foreach(tid; type_ids)
            {
                auto sptr = registry.components.get(tid);
                auto has = (cast(Storage!(ubyte)*) sptr).contains(entity);
                if(!has) 
                {
                    valid = false;
                    goto keep;
                }
            }

            foreach(tid; exclude_type_ids)
            {
                auto sptr = registry.components.get(tid);
                auto has = (cast(Storage!(ubyte)*) sptr).contains(entity);
                if(has) 
                {
                    valid = false;
                    goto keep;
                }
            }

            keep:

            if(valid)
                result = dg(entity);
        }

        //foreach (item; array)
        //{
        //    result = dg(item);
        //    if (result)
        //        break;
        //}
    
        return result;
    }
}

struct BasicGroup
{
    Registry* registry;
    GroupData* group_data;
}

struct OwningGroup
{
    Registry* registy;
    GroupData* group_data;
    size_t* superr;
}

void sortSub(T1, T2)(T1[] items, T2[] sub_items, scope bool delegate(T1, T2) lessThan)
{
    size_t i = 1;
    while(i < items.length)
    {
        auto x = items[i];
        auto y = sub_items[i];
        size_t j = i;
        while(j > 0 && lessThan(x, items[j - 1]))
        {
            items[j] = items[j - 1];
            sub_items[j] = sub_items[j - 1];

            j -= 1;
        }
        items[j] = x;
        sub_items[j] = y;

        i += 1;
    }
}