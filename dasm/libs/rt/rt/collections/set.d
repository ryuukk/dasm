module rt.collections.set;

import rt.memz;
import rt.dbg;

import rt.collections.array;



package struct Optional(T)
{
    static enum undefined = Optional.init;

    T value;
    bool defined = false;
}


struct SparseSet(SparseT)
{
    enum page_size = 4096;

    Array!( Optional!(SparseT[]) ) sparse;
    Array!SparseT dense;
    SparseT entity_mask;
    Allocator* allocator;

    void create_with(Allocator* allocator, SparseT emask)
    {
        sparse = Array!( Optional!(SparseT[]) ).createWith(allocator);
        dense = Array!(SparseT).createWith(allocator);
        assert(sparse.capacity == 16, "cpt 16");
        assert(dense.capacity == 16, "cpt 16");

        entity_mask = emask;
        this.allocator = allocator;
    }

    size_t page(SparseT entt)
    {
        assert(allocator, "no alloc");
        //return size_type{(to_integral(entt) & traits_type::entity_mask) / page_size};
        return (entt & entity_mask) / page_size;
    }

    size_t offset(SparseT entt)
    {
        assert(allocator, "no alloc");
        //return size_type{to_integral(entt) & (page_size - 1)};
        return entt & (page_size - 1);
    }

    SparseT index(SparseT sparse)
    {
        assert(allocator, "no alloc");
        assert((contains(sparse)), "contains index");

        return this.sparse.get(page(sparse)).value[offset(sparse)];
    }

    bool contains(SparseT sparse)
    {
        assert(allocator, "no alloc");
        // TODO: not sure about the null on array thing
        // i just replaced with length  rn
        auto curr = page(sparse);
        
        // bool one = 
        //      curr < this.sparse.length;
        // bool two =
        //      this.sparse.get(curr).defined == true;
        // bool three =
        //      this.sparse.get(curr).value[offset(sparse)] != SparseT.max;

        // return (one && two && three);

        if (curr >= this.sparse.length) 
        {
            // LINFO("nope {}", sparse);
            return false;
        }

        auto s = &this.sparse[curr];
        return 
         s.defined == true &&
         s.value[offset(sparse)] != SparseT.max;
    }

    void add(SparseT sparse)
    {
        assert(allocator, "no alloc");
        assert(!contains(sparse), "no contains");
  
        // assure(page(entt))[offset(entt)] = packed.size()

        auto pos = page(sparse);
        auto off = offset(sparse);

        assure(pos)[off] = cast(SparseT) dense.length;
        
        dense.add(sparse);
    }

    void remove(SparseT sparse)
    {
        assert(allocator, "no alloc");
       assert(contains(sparse), "contains");

       auto curr = page(sparse);
       auto pos = offset(sparse);
       auto last_dense = dense.get(dense.length - 1);

       dense.set(cast(size_t) this.sparse.get(curr).value[pos], last_dense);
       this.sparse.get(page(last_dense)).value[offset(last_dense)] = this.sparse.get(curr).value[pos];
       this.sparse.get(curr).value[pos] = SparseT.max;

       dense.pop();
    }

    SparseT[] assure(size_t pos)
    {
        assert(allocator, "no alloc");
        if (pos >= sparse.length()) {
            //printf("resize! %llu\n", pos);
            auto start_pos = sparse.length();
            sparse.resize(pos + 1);
            sparse.expandToCapacity();
            for(auto i = start_pos; i < sparse.capacity; i ++)
                sparse._items[i] = Optional!(SparseT[]).undefined;
            
        }

        if(sparse.get(pos).defined == false) 
        {
            //printf("alloc bad %llu\n", pos);
            auto new_page = sparse.allocator.alloc_array!SparseT(page_size); 
            new_page[0 .. $] = SparseT.max;
            sparse.set(pos, Optional!(SparseT[])(new_page, true));
        }

        return sparse.get(pos).value;
    }

    size_t len()
    {
        assert(allocator, "no alloc");
        return dense.length;
    }
}