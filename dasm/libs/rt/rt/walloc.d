module rt.walloc;


version(NONE):

// https://github.com/wingo/walloc

// right now it's not working
// i might have messed up in the porting process
// 
// run preprocessor before porting by hand:
// clang -m32 --target=wasm32 -nostdlib  -E walloc.c > src/walloc.c


alias uint size_t;
alias uint uintptr_t;
alias ubyte uint8_t;

 size_t max(size_t a, size_t b) {
  return a < b ? b : a;
}
 uintptr_t _align_(uintptr_t val, uintptr_t alignment) {
  return (val + alignment - 1) & ~(alignment - 1);
}

enum __builtin_trap()
{
    assert(0);
}

//_Static_assert((256) == (1 << 8), "eq");
//_Static_assert((65536) == (1 << 16), "eq");
//_Static_assert((65536) == (256 * 256), "eq");
//_Static_assert((8) == (1 << 3), "eq");
//_Static_assert((256) == (32 * 8), "eq");

struct chunk {
  byte[256] data;
};





enum chunk_kind {

  GRANULES_1, GRANULES_2, GRANULES_3, GRANULES_4, GRANULES_5, GRANULES_6, GRANULES_8, GRANULES_10, GRANULES_16, GRANULES_32,


  SMALL_OBJECT_CHUNK_KINDS,
  FREE_LARGE_OBJECT = 254,
  LARGE_OBJECT = 255
};

static const uint8_t[] small_object_granule_sizes =
[

  1, 2, 3, 4, 5, 6, 8, 10, 16, 32,

];

chunk_kind granules_to_chunk_kind(uint granules) {

  if (granules <= 1) return chunk_kind.GRANULES_1; if (granules <= 2) return chunk_kind.GRANULES_2; if (granules <= 3) return chunk_kind.GRANULES_3; if (granules <= 4) return chunk_kind.GRANULES_4; if (granules <= 5) return chunk_kind.GRANULES_5; if (granules <= 6) return chunk_kind.GRANULES_6; if (granules <= 8) return chunk_kind.GRANULES_8; if (granules <= 10) return chunk_kind.GRANULES_10; if (granules <= 16) return chunk_kind.GRANULES_16; if (granules <= 32) return chunk_kind.GRANULES_32;{}

  return chunk_kind.LARGE_OBJECT;
}

static uint chunk_kind_to_granules(chunk_kind kind) {
  switch (kind) with(chunk_kind) {

  case GRANULES_1: return 1; case GRANULES_2: return 2; case GRANULES_3: return 3; case GRANULES_4: return 4; case GRANULES_5: return 5; case GRANULES_6: return 6; case GRANULES_8: return 8; case GRANULES_10: return 10; case GRANULES_16: return 16; case GRANULES_32: return 32;{}

    default:
      return -1;
  }
}






struct page_header {
  uint8_t[256] chunk_kinds;
};

struct page {
  union {
    page_header header;
    chunk[256] chunks;
  };
};



// _Static_assert(((sizeof (struct page_header))) == (1 * 256), "eq");

static page* get_page(void *ptr) {
  return cast(page*) cast(byte*) ((cast(uintptr_t) ptr) & ~(65536 - 1));
}
static uint get_chunk_index(void *ptr) {
  return ((cast(uintptr_t) ptr) & (65536 - 1)) / 256;
}

struct freelist {
  freelist *next;
};

struct large_object {
  large_object *next;
  size_t size;
};

 void* get_large_object_payload(large_object *obj) {
  return (cast(byte*) obj) + ((large_object.sizeof));
}
 large_object* get_large_object(void *ptr) {
  return cast(large_object*) ((cast(byte*) ptr) - ( (large_object.sizeof)));
}

static freelist*[chunk_kind.SMALL_OBJECT_CHUNK_KINDS] small_object_freelists;
static large_object *large_objects;

static size_t walloc_heap_size;




static page*
allocate_pages(size_t payload_size, size_t *n_allocated) {
  size_t needed = payload_size + ((page_header.sizeof));
  size_t heap_size = llvm_wasm_memory_size(0) * 65536;
  uintptr_t base = heap_size;
  uintptr_t preallocated = 0, grow = 0;

  if (!walloc_heap_size) {


    uintptr_t heap_base = _align_(cast(uintptr_t)&__heap_base, 65536);
    preallocated = heap_size - heap_base;
    walloc_heap_size = preallocated;
    base -= preallocated;
  }

  if (preallocated < needed) {

    grow = _align_(max(walloc_heap_size / 2, needed - preallocated),
                 65536);
    do { if (!(grow)) __builtin_trap(); } while (0);
    if (llvm_wasm_memory_grow(0, grow >> 16) == -1) {
        writeln("error!!!");
      return null;
    }
    update_memory_view();
    walloc_heap_size += grow;
  }

  page *ret = cast(page *)base;
  size_t size = grow + preallocated;
  do { if (!(size)) __builtin_trap(); } while (0);
  do { if (!((size) == _align_((size), 65536))) __builtin_trap(); } while (0);
  *n_allocated = size / 65536;
  return ret;
}

static byte*
allocate_chunk(page *page, uint idx, chunk_kind kind) {
  page.header.chunk_kinds[idx] =cast(ubyte) kind;
  return page.chunks[idx].data.ptr;
}




static void maybe_repurpose_single_chunk_large_objects_head() {
  if (large_objects.size < 256) {
    uint idx = get_chunk_index(large_objects);
    byte *ptr = allocate_chunk(get_page(large_objects), idx, chunk_kind.GRANULES_32);
    large_objects = large_objects.next;
    freelist* head = cast(freelist *)ptr;
    head.next = small_object_freelists[chunk_kind.GRANULES_32];
    small_object_freelists[chunk_kind.GRANULES_32] = head;
  }
}



static int pending_large_object_compact = 0;
static large_object**
maybe_merge_free_large_object(large_object** prev) {
  large_object *obj = *prev;
  while (1) {
    byte *end = cast(byte*) get_large_object_payload(obj) + obj.size;
    do { if (!((cast(uintptr_t)end) == _align_((cast(uintptr_t)end), 256))) __builtin_trap(); } while (0);
    uint chunk = get_chunk_index(end);
    if (chunk < 1) {


      return prev;
    }
    page *page = get_page(end);
    if (page.header.chunk_kinds[chunk] != chunk_kind.FREE_LARGE_OBJECT) {
      return prev;
    }
    large_object *next = cast(large_object*) end;

    large_object **prev_prev = &large_objects;
    large_object *walk = large_objects;
    while (1) {
      do { if (!(walk)) __builtin_trap(); } while (0);
      if (walk == next) {
        obj.size += ((large_object.sizeof)) + walk.size;
        *prev_prev = walk.next;
        if (prev == &walk.next) {
          prev = prev_prev;
        }
        break;
      }
      prev_prev = &walk.next;
      walk = walk.next;
    }
  }
}
static void
maybe_compact_free_large_objects() {
  if (pending_large_object_compact) {
    pending_large_object_compact = 0;
    large_object **prev = &large_objects;
    while (*prev) {
      prev = &(*maybe_merge_free_large_object(prev)).next;
    }
  }
}
static large_object*
allocate_large_object(size_t size) {
  maybe_compact_free_large_objects();
  large_object *best = null;
  auto best_prev = &large_objects;
  size_t best_size = -1;

  auto prev = &large_objects;
  auto walk = large_objects;

// TODO: double check this loop
  for (;
       walk;
       prev = &walk.next, walk = walk.next) {
    if (walk.size >= size && walk.size < best_size) {
      best_size = walk.size;
      best = walk;
      best_prev = prev;
      if (best_size + ( (large_object.sizeof))
          == _align_(size + ( (large_object.sizeof)), 256))

        break;
    }
  }

  if (!best) {




    size_t size_with_header = size + (large_object.sizeof);
    size_t n_allocated = 0;
    page *page = allocate_pages(size_with_header, &n_allocated);
    if (!page) {
      return null;
    }
    byte *ptr = allocate_chunk(page, 1, chunk_kind.LARGE_OBJECT);
    best = cast(large_object *)ptr;
    size_t page_header = ptr - (cast(byte*) page);
    best.next = large_objects;
    best.size = best_size =
      n_allocated * 65536 - page_header - ( (large_object.sizeof));
    do { if (!(best_size >= size_with_header)) __builtin_trap(); } while (0);
  }

  allocate_chunk(get_page(best), get_chunk_index(best), chunk_kind.LARGE_OBJECT);

  large_object *next = best.next;
  *best_prev = next;

  size_t tail_size = (best_size - size) & ~(256 - 1);
  if (tail_size) {


    page *start_page = get_page(best);
    byte *start = cast(byte*) get_large_object_payload(best);
    byte *end = start + best_size;

    if (start_page == get_page(end - tail_size - 1)) {

      do { if (!((cast(uintptr_t)end) == _align_((cast(uintptr_t)end), 256))) __builtin_trap(); } while (0);
    } else if (size < 65536 - ( (large_object.sizeof)) - 256) {


      do { if (!((cast(uintptr_t)end) == _align_((cast(uintptr_t)end), 65536))) __builtin_trap(); } while (0);
      size_t first_page_size = 65536 - ((cast(uintptr_t)start) & (65536 - 1));
      large_object *head = best;
      allocate_chunk(start_page, get_chunk_index(start), chunk_kind.FREE_LARGE_OBJECT);
      head.size = first_page_size;
      head.next = large_objects;
      large_objects = head;

      maybe_repurpose_single_chunk_large_objects_head();

      page *next_page = start_page + 1;
      byte *ptr = allocate_chunk(next_page, 1, chunk_kind.LARGE_OBJECT);
      best = cast(large_object *) ptr;
      best.size = best_size = best_size - first_page_size - 256 - ( (large_object.sizeof));
      do { if (!(best_size >= size)) __builtin_trap(); } while (0);
      start = cast(byte*) get_large_object_payload(best);
      tail_size = (best_size - size) & ~(256 - 1);
    } else {



      do { if (!((cast(uintptr_t)end) == _align_((cast(uintptr_t)end), 65536))) __builtin_trap(); } while (0);
      size_t first_page_size = 65536 - ((cast(uintptr_t)start) & (65536 - 1));
      size_t tail_pages_size = _align_(size - first_page_size, 65536);
      size = first_page_size + tail_pages_size;
      tail_size = best_size - size;
    }
    best.size -= tail_size;

    uint tail_idx = get_chunk_index(end - tail_size);
    while (tail_idx < 1 && tail_size) {

      tail_size -= 256;
      tail_idx++;
    }

    if (tail_size) {
      page *page = get_page(end - tail_size);
      byte *tail_ptr = allocate_chunk(page, tail_idx, chunk_kind.FREE_LARGE_OBJECT);
      large_object *tail = cast(large_object *) tail_ptr;
      tail.next = large_objects;
      tail.size = tail_size - ( (large_object.sizeof));
      do { if (!((cast(uintptr_t)(get_large_object_payload(tail) + tail.size)) == _align_((cast(uintptr_t)(get_large_object_payload(tail) + tail.size)), 256))) __builtin_trap(); } while (0);
      large_objects = tail;

      maybe_repurpose_single_chunk_large_objects_head();
    }
  }

  do { if (!((cast(uintptr_t)(get_large_object_payload(best) + best.size)) == _align_((cast(uintptr_t)(get_large_object_payload(best) + best.size)), 256))) __builtin_trap(); } while (0);
  return best;
}

static freelist*
obtain_small_objects(chunk_kind kind) {
  freelist** whole_chunk_freelist = &small_object_freelists[chunk_kind.GRANULES_32];
  void *chunk;
  if (*whole_chunk_freelist) {
    chunk = *whole_chunk_freelist;
    *whole_chunk_freelist = (*whole_chunk_freelist).next;
  } else {
    chunk = allocate_large_object(0);
    if (!chunk) {
      return null;
    }
  }
  byte *ptr = allocate_chunk(get_page(chunk), get_chunk_index(chunk), kind);
  byte *end = ptr + 256;
  freelist *next = null;
  size_t size = chunk_kind_to_granules(kind) * 8;
  for (size_t i = size; i <= 256; i += size) {
    freelist *head = cast(freelist*) (end - i);
    head.next = next;
    next = head;
  }
  return next;
}

 size_t size_to_granules(size_t size) {
  return (size + 8 - 1) >> 3;
}
static freelist** get_small_object_freelist(chunk_kind kind) {
  do { if (!(kind < chunk_kind.SMALL_OBJECT_CHUNK_KINDS)) __builtin_trap(); } while (0);
  return &small_object_freelists[kind];
}

static void*
allocate_small(chunk_kind kind) {
  freelist **loc = get_small_object_freelist(kind);
  if (!*loc) {
    freelist *freelist = obtain_small_objects(kind);
    if (!freelist) {
      return (cast(void *) 0);
    }
    *loc = freelist;
  }
  freelist *ret = *loc;
  *loc = ret.next;
  return cast(void *) ret;
}

static void*
allocate_large(size_t size) {
  large_object *obj = allocate_large_object(size);
  return obj ? get_large_object_payload(obj) : (cast(void *) 0);
}

export extern (C)
void*
malloc(size_t size) 
{
  size_t granules = size_to_granules(size);
  chunk_kind kind = granules_to_chunk_kind(granules);
  return (kind == chunk_kind.LARGE_OBJECT) ? allocate_large(size) : allocate_small(kind);
}

export extern (C) 
void
free(void *ptr) {
  if (!ptr) return;
  page *page = get_page(ptr);
  uint chunk = get_chunk_index(ptr);
  uint8_t kind = page.header.chunk_kinds[chunk];
  if (kind == chunk_kind.LARGE_OBJECT) {
    large_object *obj = get_large_object(ptr);
    obj.next = large_objects;
    large_objects = obj;
    allocate_chunk(page, chunk, chunk_kind.FREE_LARGE_OBJECT);
    pending_large_object_compact = 1;
  } else {
    size_t granules = kind;
    freelist **loc = get_small_object_freelist(cast(chunk_kind) granules);
    freelist *obj = cast(freelist*) ptr;
    obj.next = *loc;
    *loc = obj;
  }
}
