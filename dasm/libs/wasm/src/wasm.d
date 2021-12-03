module wasm;


extern(C):

// JS general API
void update_memory_view();
void abort();
uint WAJS_sleep();
// ---


// JS canvas API
void WAJS_setup_canvas(size_t width, size_t height);
// ---

// JS time API
uint WAJS_get_elapsed_time();
uint WAJS_get_time();
uint WAJS_ticks();
// ---

// JS print API
void print_uint(uint value)
{
    print_int(value);
}
void print_ulong(ulong value)
{
    print_long(value);
}
void print_int(int value);
void print_long(long value);
void print_float(float value);
void print_double(double value);
void print_char(char value);
void print_str(const char* value);
void print_str_len(const char* value, size_t len);
void print_ptr(const (void)* value);
// ---


alias cb_t = extern(C) void delegate (uint id, void* ptr, int len, bool ok);
void load_file_async(string path, uint id, scope cb_t cb);

extern(C)
export
void jsCallback0(uint ctx, uint fun) {
  static struct Handler {
    union {
      extern(C) void delegate() handle;
      struct {
        void* contextPtr;
        void* funcPtr;
      }
    }
  }
  Handler c;
  c.contextPtr = cast(void*) ctx;
  c.funcPtr = cast(void*) fun;
  c.handle();
}

extern(C)
export
void jsCallback(uint ctx, uint fun, uint arg) {
  static struct Handler {
    union {
      extern(C) void delegate(uint) handle;
      struct {
        void* contextPtr;
        void* funcPtr;
      }
    }
  }
  Handler c;
  c.contextPtr = cast(void*) ctx;
  c.funcPtr = cast(void*) fun;
  c.handle(arg);
}

extern(C)
export
void js_cb_load_file(uint ctx, uint fun, int id, int ptr, int len, bool ok) {
  static struct Handler {
    union {
      extern(C) void delegate(int, void*, int, bool) handle;
      struct {
        void* contextPtr;
        void* funcPtr;
      }
    }
  }
  Handler c;
  c.contextPtr = cast(void*) ctx;
  c.funcPtr = cast(void*) fun;
  c.handle(id, cast(void*)ptr, len, ok);
}
