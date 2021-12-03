module collections.set;

import memory;
import dbg;

import collections.array;



package struct Optional(T)
{
    enum undefined = Optional.init;

    private T value;
    private bool defined = false;

    //void opAssign ( T rhs )
    //{
    //    defined = true;
    //    value = rhs;
    //}
}


struct SparseSet(SparseT)
{
    enum page_size = 4096;

    Array!( Optional!(SparseT[]) ) sparse;
    Array!SparseT dense;
    SparseT entity_mask;
    Allocator* allocator;

    static SparseSet create(Allocator* allocator)
    {
        SparseSet ret;
        ret.sparse = Array!( Optional!(SparseT[]) ).createWith(allocator);
        ret.dense = Array!(SparseT).createWith(allocator);
        assert(ret.sparse.capacity == 16);
        assert(ret.dense.capacity == 16);

        ret.entity_mask = 0xFFFFFFFF;
        ret.allocator = allocator;
        return ret;
    }

    size_t page(SparseT entt)
    {
        //return size_type{(to_integral(entt) & traits_type::entity_mask) / page_size};
        return  cast(size_t) (entt & entity_mask) / page_size;
    }

    size_t offset(SparseT entt)
    {
        //return size_type{to_integral(entt) & (page_size - 1)};
        return entt & (page_size - 1);
    }

    SparseT index(SparseT sparse)
    {
        assert((contains(sparse)));

        return this.sparse.get(page(sparse)).value[offset(sparse)];
    }

    bool contains(SparseT sparse)
    {
        // TODO: not sure about the null on array thing
        // i just replaced with length  rn
        auto curr = page(sparse);
        return curr < this.sparse.length  &&
        this.sparse.get(curr).defined == true &&
        this.sparse.get(curr).value[offset(sparse)] != SparseT.max;
    }

    void add(SparseT sparse)
    {

        assert(!contains(sparse));
  
        // assure(page(entt))[offset(entt)] = packed.size()

        size_t pos = page(sparse);
        size_t off = offset(sparse);

        assure(pos)[off] = cast(SparseT) dense.length;
        
        dense.add(sparse);
    }

    void remove(SparseT sparse)
    {
       assert(contains(sparse));

       auto curr = page(sparse);
       auto pos = offset(sparse);
       auto last_dense = dense.get(dense.length - 1);

       dense.set(cast(size_t) this.sparse.get(curr).value[pos], last_dense);
       this.sparse.get(page(last_dense)).value[offset(last_dense)] = this.sparse.get(curr).value[pos];
       this.sparse.get(curr).value[pos] = SparseT.max;

       dense.pop();
    }

    SparseT[] assure(size_t pos) {
        if (pos >= sparse.length) {
            //printf("resize! %llu\n", pos);
            auto start_pos = sparse.length;
            sparse.resize(pos + 1);
            sparse.expandToCapacity();
            for(int i = 0; i < sparse.capacity; i ++)
                sparse._items[i] = Optional!(SparseT[])();
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
        return dense.length;
    }
}