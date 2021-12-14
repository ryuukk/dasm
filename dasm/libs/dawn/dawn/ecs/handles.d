module dawn.ecs.handles;

import dawn.ecs;

import rt.dbg;
import rt.memz;
import rt.collections.hashmap;
import rt.collections.array;
import rt.collections.set;


struct Handles(HandleType, IndexType, VersionType)
{
    HandleType[] handles;
    IndexType append_cursor;
    Optional!(IndexType) last_destroyed;
    Allocator* allocator;

    void create_with(Allocator* allocator, int capacity = 32)
    {
        this.allocator = allocator;

        handles = allocator.alloc_array!(HandleType)(capacity);
        last_destroyed = Optional!(IndexType).undefined;
        append_cursor = 0;
    }

    void dispose()
    {
        allocator.free(handles.ptr);
    }


    IndexType extractId(HandleType handle)
    {
        assert(allocator);
        // return @truncate(IndexType, handle & registry.entity_traits.entity_mask);
        return  cast(IndexType) ((handle & entity_mask) );
    }

    VersionType extractVersion(HandleType handle)
    {
        assert(allocator);
        // return @truncate(VersionType, handle >> registry.entity_traits.entity_shift);
        return cast(VersionType) ( (handle >> entity_shift) );
    }

    HandleType forge( IndexType id, VersionType versionn)
    {
        assert(allocator);
        // return id | @as(HandleType, version) << registry.entity_traits.entity_shift;
        return id | (cast(HandleType) versionn) << entity_shift;
    }


    HandleType create()  
    {
        assert(allocator);
        if (last_destroyed.defined == false) {
            // ensure capacity and grow if needed
            if ( (handles.length - 1) == append_cursor) 
            {
                auto newm = allocator.alloc_array!(HandleType)(handles.length * 2);
                memcpy(newm.ptr, handles.ptr, handles.length * HandleType.sizeof);
                free(handles.ptr);
                handles = newm;
            }

            auto id = append_cursor;
            auto handle = forge(append_cursor, 0);
            handles[id] = handle;

            append_cursor += 1;
            return handle;
        }

        auto versionn = extractVersion(handles[last_destroyed.value]);
        auto destroyed_id = extractId(handles[last_destroyed.value]);

        auto handle = forge(last_destroyed.value, versionn);
        handles[last_destroyed.value] = handle;

        last_destroyed = (destroyed_id == invalid_id) ? 
                            Optional!(IndexType).undefined :
                            Optional!(IndexType)(destroyed_id, true);

        return handle;
    }

    void remove(HandleType handle)
    {
        assert(allocator);
        auto id = extractId(handle);
        if (id > append_cursor || handles[id] != handle)
            return panic("RemovedInvalidHandle");

        auto next_id = (last_destroyed.defined) ? last_destroyed.value : invalid_id;
        if (next_id == id) panic("ExhaustedEntityRemoval");

        auto versionn = extractVersion(handle);

        // NOW TODO: check cast
        handles[id] = forge(cast(IndexType) next_id, versionn += 1);

        last_destroyed = Optional!(IndexType)(id, true);
    }

    bool alive(HandleType handle)
    {
        assert(allocator);
        auto id = extractId(handle);
        return (id < append_cursor) && (handles[id] == handle);
    }
}