module dawn.ecs;

// FUCK ECS

import rt.dbg;
import rt.memz;
import rt.collections.hashmap;
import rt.collections.array;
import rt.collections.set;

import dawn.ecs.handles;
import dawn.ecs.storage;
import dawn.ecs.views;


// commit: f9cf1322ddaf1e9b80349fcc2623babb79f83538
// https://github.com/prime31/zig-ecs

// TODO: create a traits definition and put all that, so i can costumize things
// --- DO NOT EDIT
version(WASM)
{
    alias entity_t = uint;
    alias Index = ushort;
    alias Version = ushort;
}
else
{
    alias entity_t = ulong;
    alias Index = uint;
    alias Version = uint;
}
// TODO: redo optional, and double check this
enum invalid_id = entity_mask;// IndexType.max;

enum entity_mask = Index.max;
enum version_mask = Version.max;
enum entity_shift = Index.sizeof * 8;
// ---

alias Storage(T) = ComponentStorage!(T, entity_t);
alias Registry = RegistryImpl!(entity_t, Index, Version);


struct Optional(T)
{
    static enum undefined = Optional.init;

    T value;
    bool defined = false;
}

struct TypeStore
{
    HashMap!(uint, void*) map;
    Allocator* allocator;

    static TypeStore create(Allocator* allocator)
    {
        TypeStore ret;
        ret.map.create(allocator);
        ret.allocator = allocator;
        return ret;
    }
}

struct GroupData
{
     ulong hash;
     ubyte size;
     /// optional. there will be an entity_set for non-owning groups and current for owning
     SparseSet!(entity_t) entity_set;
     uint[] owned;
     uint[] include;
     uint[] exclude;
     Registry* registry;
     size_t current;

     void create_w(Allocator* allocator, Registry* registry, ulong hash, uint[] owned, uint[] include, uint[] exclude)
     {
         this.hash = hash;
         this.size = cast(ubyte) (owned.length + include.length + exclude.length);
         this.registry = registry;
         if(owned.length == 0)
            entity_set.create_with(allocator, entity_mask);
        this.owned = dupe(allocator, owned);
        this.include = dupe(allocator, include);
        this.exclude = dupe(allocator, exclude);
        this.current = 0;
     }
}

struct RegistryImpl(EntityType, IndexType, VersionType)
{
    HashMap!(entity_t, size_t) components;
    HashMap!(uint, size_t) contexts;
    Array!(GroupData*) groups;
    TypeStore singletons;
    Allocator* allocator;

    Handles!(EntityType, IndexType, VersionType) entity_handles;

    // static RegistryImpl create(Allocator* allocator)
    // {
    //     RegistryImpl ret;
    //     ret.components = HashMap!(entity_t, size_t).create(allocator);
    //     ret.contexts = HashMap!(uint, size_t).create(allocator);
    //     ret.groups = Array!(GroupData*).createWith(allocator);
    //     ret.singletons = TypeStore.create(allocator);
    //     ret.entities = allocator.alloc_array!(EntityType)(32);
    //     ret.last_destroyed.value = entity_mask;
    //     ret.last_destroyed.defined = false;
    //     ret.allocator = allocator;    
    //     return ret;
    // }

    void create(Allocator* allocator)
    {
        this.allocator = allocator;

        components.create(allocator);
        contexts.create(allocator);
        groups = Array!(GroupData*).createWith(allocator);
        singletons = TypeStore.create(allocator);
        entity_handles.create_with(allocator);
    }

    void dispose()
    {
        not_implemented();
    }

    bool valid(entity_t entity)
    {
        return entity_handles.alive(entity);
    }

    entity_t create_entity()
    {
        return entity_handles.create();
    }

    void destroy_entity(entity_t entity)
    {
        assert(valid(entity));
        remove_all(entity);
        entity_handles.remove(entity);    
    }

    void remove_all(entity_t entity)
    {
        assert(valid(entity));

        foreach(kv; components)
        {
            auto store = cast(Storage!(bool)*) kv.value;
            store.removeIfContains(entity);
        }
    }

    void add(T)(entity_t entity, T value = T.init)
    {
        assert(valid(entity));
        auto s = assure!T();
        s.add(entity, value);
    }

    void remove(T)(entity_t entity)
    {
        assert(valid(entity));
        auto s = assure!T();
        s.remove(entity);
    }

    T* get(T)(entity_t entity)
    {
        assert(valid(entity));
        auto s = assure!T();
        assert(s);

        return s.get(entity);
    }

    bool has(T)(entity_t entity)
    {
        assert(valid(entity), "unvalid");
        auto s = assure!T();
        assert(s, "no assure");
        return s.contains(entity);

    }

    Storage!(T)* assure(T)()
    {
        auto type_id = type_id!T;

        if(components.has(type_id))
        {
            auto ptr = components.get(type_id);
            return cast(Storage!(T)*) ptr;
        }

        LINFO("create storage for: {} -> {}", T.stringof, type_id);

        auto comp_set = Storage!(T).createPtr(allocator);
        comp_set.id = type_id;
        comp_set.name = type_name!T;
        auto comp_set_ptr = cast(size_t)(comp_set);
        components.set(type_id, comp_set_ptr);
        return comp_set;
    }

    auto view(Includes)()
    {
        return view!(Includes, Excludes!());
    }

    auto view(Includes, Excludes)()
    {
        static if (Includes.args.length == 1 && Excludes.args.length == 0)
        {
            auto storage = assure!(Includes.args[0]);
            return BasicView!(Includes.args[0]).create( storage );
        }
        else
        {

            size_t[Includes.args.length] includes_arr;
            static foreach (i, T; Includes.args)
            {
                assure!(T)();
                includes_arr[i] = type_id!(T);
            }
            size_t[Excludes.args.length] excludes_arr;
            static foreach (i, T; Excludes.args)
            {
                assure!(T)();
                excludes_arr[i] = type_id!(T);
            }
            return MultiView!(Includes.args.length, Excludes.args.length).create(&this, includes_arr, excludes_arr);
        }
    }
    
    
    /*
    void view_it(Includes)(scope void delegate(Entity, Includes.args*) cb)
    {
        view_it!(Includes, Excludes!())(cb);
    }

    void view_it(Includes, Excludes)(scope void delegate(Entity, Includes.args) cb)
    {
        auto v = view!(Includes, Excludes)();
        
        foreach(e; v)
        {
            // i need to get types from the Includes aliasseq, so i get the component and pass them in the delegate
            // i'm not sure how i can achieve it             
            Includes.args* args; 
            foreach(i, a; Includes.args)
            {
                args[i] = v.get!(a)(e);
            }
            cb(e, args);
        }
    }
*/
    // TODO: add support for groups
    //auto group(T, Includes, Excludes)()
    //{
    //}
}
struct Includes(Args...) { alias args = Args; }
struct Excludes(Args...) { alias args = Args; }
struct Results(Args...) { alias args = Args; }


template type_id(alias type)
{
    static if (entity_t.sizeof == 8)
        enum type_id = hashStringFnv64(__traits(identifier, type));
    else
        enum type_id = hashStringFnv32(__traits(identifier, type));

    ulong hashStringFnv64(string str)
    {
        enum ulong FNV_64_INIT = 0xcbf29ce484222325UL;
        enum ulong FNV_64_PRIME = 0x100000001b3UL;
        ulong rv = FNV_64_INIT;
        const len = str.length;
        for(int i = 0; i < len; i++) {
            rv ^= str[i];
            rv *= FNV_64_PRIME;
        }
        return rv;
    }

    uint hashStringFnv32(string str)
    {
        enum uint FNV_32_INIT = 0x811c9dc5;
        enum uint FNV_32_PRIME = 0x01000193;
        uint rv = FNV_32_INIT;
        const len = str.length;
        for(int i = 0; i < len; i++) {
            rv ^= str[i];
            rv *= FNV_32_PRIME;
        }
        return rv;
    }
}
template type_name(alias type)
{
    enum auto type_name = __traits(identifier, type);
}
/+
@("ecs")
unittest
{
    import std.stdio: writeln;

    struct Pos
    {
        int x, y;
    }

    struct Empty{}
    struct Pos01{float x, y;}
    struct Pos02{float x, y;}
    struct Pos03{float x, y;}
    struct Pos04{float x, y;}
    struct Pos05{float x, y;}
    struct Pos06{float x, y;}
    struct Pos07{float x, y;}
    struct Pos08{float x, y;}
    struct Pos09{float x, y;}
    struct Pos10{float x, y;}
    struct Pos11{float x, y;}
    struct Pos12{float x, y;}
    struct Pos13{float x, y;}
    struct Pos14{float x, y;}
    struct Pos15{float x, y;}
    struct Pos16{float x, y;}
    struct Pos17{float x, y;}
    struct Pos18{float x, y;}
    struct Pos19{float x, y;}

    Registry registry;
    registry.create(MALLOCATOR.ptr);
    for(int i = 0; i < 1_000_000; i++)
    {
        entity_t e = registry.create_entity();
        // LINFO("ENTITY: {}",e);
        assert(registry.valid(e));

        registry.add(e,Pos01(5,6));
        registry.add(e,Pos02(5,6));
        registry.add(e,Pos03(5,6));
        registry.add(e,Pos04(5,6));
        registry.add(e,Pos05(5,6));

        assert(registry.has!(Pos01)(e));
        assert(registry.has!(Pos02)(e));
        assert(registry.has!(Pos03)(e));
        assert(registry.has!(Pos04)(e));
        assert(registry.has!(Pos05)(e));
    }

    //registry.view_it!(Includes!(Pos01))( (Entity e, Pos01* p) {
    //} );
}
+/

@("ecs_stress")
unittest
{
    LINFO("ushort: {}", ushort.max);
    enum size = 1_000_000;
    LINFO("ecs_stress");

    struct A{}
    struct B{int[10] large;}

    Registry registry;
    registry.create(MALLOCATOR.ptr);

    Array!(entity_t) a;
    a.create(MALLOCATOR.ptr, size + 1);


    for(size_t i = 0; i < size; i++)
    {
        auto e = registry.create_entity();
        a.add(e); 

        registry.add(e, B());
        assert(registry.has!(B)(e));
    }

    LINFO("now check");

    foreach(entity_t e; a)
    {
        assert(registry.has!(B)(e), "doesn't has");
        registry.destroy_entity(e);
    }
    a.clear();    



        LINFO("big test");
    //while(true)
    {
        import rt.thread;
        import core.stdc.stdlib: rand, RAND_MAX;
        import core.stdc.stdio: printf;

        benchmark("ecs_stress", {

            {
                auto sa = registry.assure!(A)();
                auto sb = registry.assure!(B)();
                assert(sa.set.dense.length == 0);
                assert(sb.set.dense.length == 0);
            }
            
            int r = 1_000_000;
            for(int i = 0; i < r; i++)
            {
                auto e1 = registry.create_entity();
                registry.add(e1, A());
                bool randbool = rand() & 1;
                if(randbool)
                    registry.add(e1, B());
                a.add(e1);
            }
            printf("destroy %i\n", r);
            foreach(entity_t e; a)
            {
                registry.destroy_entity(e);
            }
            a.clear();
        });

        sleep_for(1000);
    }
    
}



/+

    +/