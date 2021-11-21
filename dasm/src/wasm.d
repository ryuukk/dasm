module wasm;

version(WASM):

extern(C):

// WASM JS API
void WAJS_log(const char* txt, size_t len);
void WAJS_setup_canvas(size_t width, size_t height);
uint WAJS_get_time();
// ---


void abort()
{
    
}