module wasm;


extern(C):

// JS general API
void abort();
// ---


// JS canvas API
void WAJS_setup_canvas(size_t width, size_t height);
// ---

// JS time API
uint WAJS_get_elapsed_time();
uint WAJS_get_time();
// ---

// JS print API
void print_uint(uint value)
{
    print_int(value);
}
void print_int(int value);
void print_float(float value);
void print_double(double value);
void print_char(char value);
void print_str(const char* value);
void print_str_len(const char* value, int len);
void print_ptr(void* value);
// ---


// JS math API
