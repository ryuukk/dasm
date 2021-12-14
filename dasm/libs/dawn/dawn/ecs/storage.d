module dawn.ecs.storage;

import dawn.ecs;

import rt.dbg;
import rt.memz;
import rt.collections.hashmap;
import rt.collections.array;
import rt.collections.set;



struct ComponentStorage(Component, entity_t)
{
    // TODO: in zig-ecs they have to create a dummy component with a field u1
    // because of some weird thing about empty struct
    // this problem doesn't exist with D, i'll have to create tests with empty struct!!!!
    const(char)* name;
    size_t id;

    int magic = 666;

    SparseSet!(entity_t)* set;   
    Array!(Component) instances;
    Allocator* allocator;
    /// doesnt really belong here...used to denote group ownership
    size_t superr = 0;
    void delegate(ComponentStorage*) safe_dispose;
    void delegate(ComponentStorage*, entity_t, entity_t, bool) safeSwap;
    void delegate(ComponentStorage*, entity_t) safeRemoveIfContains;

    // TODO: implement signals
    //Signal!(entity_t) construction;
    //Signal!(entity_t) update;
    //Signal!(entity_t) destruction;

    static ComponentStorage* createPtr(Allocator* allocator)
    {
        ComponentStorage* ret = allocator.create!ComponentStorage();
        ret.set = allocator.create!(SparseSet!entity_t);
        ret.set.create_with(allocator, entity_mask);
        assert(ret.set.dense.capacity == 16);
        assert(ret.set.sparse.capacity == 16);
        // TODO: check empty struct
        ret.instances = Array!(Component).createWith(allocator);
        ret.allocator = allocator;
        ret.superr = 0;
        ret.safe_dispose = (ComponentStorage* c) {
            c.instances.dispose();
        };
        ret.safeSwap = (ComponentStorage* c, entity_t a, entity_t b , bool instances_only) {
            if(!instances_only)
            {
                
            }
        };
        ret.safeRemoveIfContains = (ComponentStorage* c, entity_t e) {
            if (c.contains(e))
            {
                c.remove(e);
            }
        };

        return ret;
    }

    void add(entity_t entity, Component component)
    {
        assert(magic == 666);
        // TODO: check empty struct when i sort this stuff out
        instances.add(component);
        set.add(entity);
        // TODO: signal construction
    }

    Component* get(entity_t entity)
    {
        assert(contains(entity));
        return &instances._items[set.index(entity)];
    }

    bool contains(entity_t entity)
    {
        return set.contains(entity);
    }

    void remove(entity_t entity)
    {
        // TODO: signal destruction
        instances.removeSwap(set.index(entity));
        set.remove(entity);
    }

    void removeIfContains(entity_t entity)
    {
        // TODO: need figure out why this
        static if( is(Component == bool) )
        {
            safeRemoveIfContains(&this, entity);
        }
        else
        {
            if (contains(entity))
            {
                remove(entity);
            }
        }
    }

    size_t len()
    {
        return set.len();
    }
}
