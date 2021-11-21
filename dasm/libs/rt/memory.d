module memory;

void* malloc(size_t size);
void free(void* ptr);
void* calloc(size_t nmemb, size_t size);
void* realloc(void* ptr, size_t size);

version (WASM)
{
	import wasm;

	alias uintptr_t = size_t;

	enum PAGE_SIZE = (64 * 1024);
	enum BLOCK_INFO_MAGIC = 0x47f98950;
	enum BLOCK_INFO_SIZE = (block_info.sizeof);

	struct block_info
	{
		int magic;
		block_info* previous;
		block_info* next;
		size_t size;
		bool free;
	}

	__gshared bool initialized = false;
	__gshared size_t current_pages;
	__gshared uintptr_t heap_top;
	__gshared block_info* first_block;
	__gshared block_info* last_block;
	__gshared block_info* first_free_block;

	bool block_info_valid(block_info* block)
	{
		return block.magic == BLOCK_INFO_MAGIC;
	}

	void do_initialize()
	{
		// #ifdef MALLOC_DEBUG
		// 	prints("Initializing\n");
		// #endif

		current_pages = grow_memory(0);
		heap_top = current_pages * PAGE_SIZE;
		first_block = null;
		last_block = null;
		first_free_block = null;

		initialized = true;

		// #ifdef MALLOC_DEBUG
		// 	prints("BLOCK_INFO_SIZE: ");
		// 	printi(BLOCK_INFO_SIZE);
		// 	printc('\n');
		// 	prints("Heap start: ");
		// 	printptr((void *) heap_top);
		// 	printc('\n');
		// #endif
	}

	void initialize()
	{
		if (!initialized)
		{
			do_initialize();
		}
	}

	uintptr_t grow_heap(size_t inc)
	{
		uintptr_t old_heap_top = heap_top;

		heap_top += inc;

		uintptr_t heap_max = current_pages * PAGE_SIZE - 1;
		if (heap_top > heap_max)
		{
			size_t diff = heap_top - heap_max;
			size_t pages = (diff + (PAGE_SIZE - 1)) / PAGE_SIZE;
			// #ifdef MALLOC_DEBUG
			// 		prints("Heap too small by ");
			// 		printi(diff);
			// 		prints(" bytes, ");
			// 		printi(pages);
			// 		prints(" pages");
			// 		printc('\n');
			// #endif
			current_pages = grow_memory(pages) + pages;
		}

		// #ifdef MALLOC_DEBUG
		// 	prints("Heap now ends at ");
		// 	printptr((void *) heap_top);
		// 	printc('\n');
		// #endif

		return old_heap_top;
	}

	void* malloc(size_t size)
	{
		initialize();

		block_info* block = first_free_block;
		while (block != null)
		{
			if (block.free)
			{
				if (block.size >= size)
				{
					// #ifdef MALLOC_DEBUG
					// 				prints("Found free block with sufficient size\n");
					// #endif
					if (block.size - size > BLOCK_INFO_SIZE)
					{
						uintptr_t next_block_addr = cast(uintptr_t) block + BLOCK_INFO_SIZE + size;

						block_info* next_block = cast(block_info*) next_block_addr;
						next_block.magic = BLOCK_INFO_MAGIC;
						next_block.previous = block;
						next_block.next = block.next;
						if (next_block.next)
							next_block.next.previous = next_block;

						next_block.free = true;
						next_block.size = block.size - size - BLOCK_INFO_SIZE;

						block.next = next_block;
						block.size = size;

						first_free_block = next_block;
					}
					else
					{
						first_free_block = block.next;
						while (first_free_block != null && !first_free_block.free)
						{
							first_free_block = first_free_block.next;
						}
					}
					block.free = false;
					return cast(void*)(cast(uintptr_t) block + BLOCK_INFO_SIZE);
				}
				else if (cast(uintptr_t) block == cast(uintptr_t) last_block)
				{
					grow_heap(size - block.size);
					block.size = size;
					block.free = false;
					return cast(void*)(cast(uintptr_t) block + BLOCK_INFO_SIZE);
				}
			}
			block = block.next;
		}

		// #ifdef MALLOC_DEBUG
		// 	prints("No free block with sufficient size found\n");
		// #endif

		block_info* new_block = cast(block_info*) grow_heap(BLOCK_INFO_SIZE + size);
		new_block.magic = BLOCK_INFO_MAGIC;
		new_block.previous = last_block;
		new_block.next = null;
		new_block.free = false;
		new_block.size = size;

		if (first_block == null)
		{
			first_block = new_block;
		}

		if (last_block != null)
		{
			last_block.next = new_block;
		}
		last_block = new_block;

		return cast(void*)(cast(uintptr_t) new_block + BLOCK_INFO_SIZE);
	}

	void free(void* ptr)
	{
		if (!initialized)
		{
			// #ifdef MALLOC_DEBUG
			// 		prints("free(): not yet initialized\n");
			// #endif		
			return;
		}

		block_info* block = cast(block_info*)(cast(uintptr_t) ptr - BLOCK_INFO_SIZE);

		if (!block_info_valid(block))
		{
			// #ifdef MALLOC_DEBUG
			// 		prints("free(): invalid pointer: ");
			// 		printptr(ptr);
			// 		printc('\n');
			// #endif
			return;
		}

		if (block.free)
		{
			// #ifdef MALLOC_DEBUG
			// 		prints("free(): double free: ");
			// 		printptr(ptr);
			// 		printc('\n');
			// #endif
			return;
		}

		block.free = true;

		// Merge consecutive free blocks
		if (block.previous && block.previous.free)
		{
			block.previous.size += BLOCK_INFO_SIZE + block.size;
			block.previous.next = block.next;
			if (block.next)
				block.next.previous = block.previous;
			if (cast(uintptr_t) block == cast(uintptr_t) last_block)
			{
				last_block = block.previous;
			}
			block = block.previous;
		}
		if (block.next && block.next.free)
		{
			block.size += BLOCK_INFO_SIZE + block.next.size;
			if (cast(uintptr_t) block.next == cast(uintptr_t) last_block)
			{
				last_block = block;
			}
			block.next = block.next.next;
			if (block.next)
				block.next.previous = block;
		}

		if (first_free_block == null || cast(uintptr_t) block < cast(uintptr_t) first_free_block)
		{
			first_free_block = block;
		}

		// TODO: if this is the last block, release it

		// #ifdef MALLOC_DEBUG
		// 	prints("Freed block at ");
		// 	printptr(ptr);
		// 	printc('\n');
		// #endif
	}

	void* calloc(size_t nmemb, size_t size)
	{
		initialize();

		size_t full_size = nmemb * size;
		if (nmemb != 0 && full_size / nmemb != size)
		{
			// #ifdef MALLOC_DEBUG
			// 		prints("calloc() multiplication overflow: ");
			// 		printi(nmemb);
			// 		prints(" * ");
			// 		printi(size);
			// 		prints(" > SIZE_MAX\n");
			// #endif
			return null;
		}

		void* ptr = malloc(full_size);
		if (ptr)
		{
			//memset(ptr, 0, full_size);
		}

		return ptr;
	}

	void* realloc(void* ptr, size_t size)
	{
		initialize();
		// TODO
		return null;
	}
}
else
{
	import stdc = core.stdc.stdio;
	import stdlib = core.stdc.stdlib;

	void* malloc(size_t size)
	{
		return stdlib.malloc(size);
	}

	void free(void* ptr)
	{
		stdlib.free(ptr);
	}

	void* calloc(size_t nmemb, size_t size)
	{
		return stdlib.calloc(nmemb, size);
	}

	void* realloc(void* ptr, size_t size)
	{
		return stdlib.realloc(ptr, size);
	}
}
