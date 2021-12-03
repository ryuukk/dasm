module sokol.fetch;

version(Windows)
{
    version = _SFETCH_HAS_THREADS;
    import core.sys.windows.winbase;
    import core.sys.windows.windef;
    import core.sys.windows.winnls : CP_UTF8, MultiByteToWideChar, WideCharToMultiByte;
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.string;
    
}


version(WASM)
{
    enum _SFETCH_PLATFORM_EMSCRIPTEN = (1);
    enum _SFETCH_PLATFORM_WINDOWS = (0);
    enum _SFETCH_PLATFORM_POSIX = (0);
    enum _SFETCH_HAS_THREADS = (0);
}
version(Windows)
{
    enum _SFETCH_PLATFORM_WINDOWS = (1);
    enum _SFETCH_PLATFORM_EMSCRIPTEN = (0);
    enum _SFETCH_PLATFORM_POSIX = (0);
    enum _SFETCH_HAS_THREADS = (1);
}
version(Posix)
{
    import core.stdc.stdio;
    enum _SFETCH_PLATFORM_POSIX =  (1);
    enum _SFETCH_PLATFORM_EMSCRIPTEN =  (0);
    enum _SFETCH_PLATFORM_WINDOWS =  (0);
    enum _SFETCH_HAS_THREADS =  (1);
}

alias uint8_t = ubyte;
alias uint32_t = uint;
alias uint64_t = ulong;
alias wchar_t = wchar;

enum SFETCH_MAX_PATH = (1024);
enum SFETCH_MAX_USERDATA_UINT64 = (16);
enum SFETCH_MAX_CHANNELS = (16);


alias SOKOL_FREE = free;
alias SOKOL_MALLOC = malloc;

void SOKOL_LOG(const (char)* msg)
{
    printf("%s\n", msg);
}


void SOKOL_ASSERT(bool cond, string f = __FILE__, int l = __LINE__)
{
    assert(cond);
}

void SOKOL_ASSERT(int cond)
{
    assert(cond);
}
void SOKOL_ASSERT(void* cond)
{
    assert(cond);
}

void SOKOL_ASSERT(const (void)* cond)
{
    assert(cond);
}

/* configuration values for sfetch_setup() */
struct sfetch_desc_t {
    uint32_t _start_canary;
    uint32_t max_requests;          /* max number of active requests across all channels, default is 128 */
    uint32_t num_channels;          /* number of channels to fetch requests in parallel, default is 1 */
    uint32_t num_lanes;             /* max number of requests active on the same channel, default is 1 */
    uint32_t _end_canary;
}

/* a request handle to identify an active fetch request, returned by sfetch_send() */
struct sfetch_handle_t { uint32_t id; }

/* error codes */
enum sfetch_error_t {
    SFETCH_ERROR_NO_ERROR,
    SFETCH_ERROR_FILE_NOT_FOUND,
    SFETCH_ERROR_NO_BUFFER,
    SFETCH_ERROR_BUFFER_TOO_SMALL,
    SFETCH_ERROR_UNEXPECTED_EOF,
    SFETCH_ERROR_INVALID_HTTP_STATUS,
    SFETCH_ERROR_CANCELLED
}


struct sfetch_response_t {
    sfetch_handle_t handle;         /* request handle this response belongs to */
    bool dispatched;                /* true when request is in DISPATCHED state (lane has been assigned) */
    bool fetched;                   /* true when request is in FETCHED state (fetched data is available) */
    bool paused;                    /* request is currently in paused state */
    bool finished;                  /* this is the last response for this request */
    bool failed;                    /* request has failed (always set together with 'finished') */
    bool cancelled;                 /* request was cancelled (always set together with 'finished') */
    sfetch_error_t error_code;      /* more detailed error code when failed is true */
    uint32_t channel;               /* the channel which processes this request */
    uint32_t lane;                  /* the lane this request occupies on its channel */
    const (char)* path;               /* the original filesystem path of the request (FIXME: this is unsafe, wrap in API call?) */
    void* user_data;                /* pointer to read/write user-data area (FIXME: this is unsafe, wrap in API call?) */
    uint32_t fetched_offset;        /* current offset of fetched data chunk in file data */
    uint32_t fetched_size;          /* size of fetched data chunk in number of bytes */
    void* buffer_ptr;               /* pointer to buffer with fetched data */
    uint32_t buffer_size;           /* overall buffer size (may be >= than fetched_size!) */
}

/* response callback function signature */
alias sfetch_callback_t = void function(const (sfetch_response_t)*);

/* request parameters passed to sfetch_send() */
struct sfetch_request_t {
    uint32_t _start_canary;
    uint32_t channel;               /* index of channel this request is assigned to (default: 0) */
    const (char)* path;               /* filesystem path or HTTP URL (required) */
    sfetch_callback_t callback;     /* response callback function pointer (required) */
    void* buffer_ptr;               /* buffer pointer where data will be loaded into (optional) */
    uint32_t buffer_size;           /* buffer size in number of bytes (optional) */
    uint32_t chunk_size;            /* number of bytes to load per stream-block (optional) */
    const (void)* user_data_ptr;      /* pointer to a POD user-data block which will be memcpy'd(!) (optional) */
    uint32_t user_data_size;        /* size of user-data block (optional) */
    uint32_t _end_canary;
}


struct _sfetch_path_t
{
    char[SFETCH_MAX_PATH] buf;
}

struct _sfetch_buffer_t
{
    uint8_t* ptr;
    uint32_t size;
}

version (Posix)
{
    struct _sfetch_thread_t
    {
        pthread_t thread;
        pthread_cond_t incoming_cond;
        pthread_mutex_t incoming_mutex;
        pthread_mutex_t outgoing_mutex;
        pthread_mutex_t running_mutex;
        pthread_mutex_t stop_mutex;
        bool stop_requested;
        bool valid;
    }
}

version (Windows)
{
    struct _sfetch_thread_t
    {
        HANDLE thread;
        HANDLE incoming_event;
        CRITICAL_SECTION incoming_critsec;
        CRITICAL_SECTION outgoing_critsec;
        CRITICAL_SECTION running_critsec;
        CRITICAL_SECTION stop_critsec;
        bool stop_requested;
        bool valid;
    }
}

version (Posix)
{

    alias _sfetch_file_handle_t = FILE*;
    enum _SFETCH_INVALID_FILE_HANDLE = 0;
    alias _sfetch_thread_func_t = void* delegate(void*);
}

version (Windows)
{
    alias _sfetch_file_handle_t = HANDLE;
    enum _SFETCH_INVALID_FILE_HANDLE = INVALID_HANDLE_VALUE;
    alias _sfetch_thread_func_t = LPTHREAD_START_ROUTINE;
}


/* user-side per-request state */
struct _sfetch_item_user_t {
    bool pause;                 /* switch item to PAUSED state if true */
    bool cont;                  /* switch item back to FETCHING if true */
    bool cancel;                /* cancel the request, switch into FAILED state */
    /* transfer IO => user thread */
    uint32_t fetched_offset;    /* number of bytes fetched so far */
    uint32_t fetched_size;      /* size of last fetched chunk */
    sfetch_error_t error_code;
    bool finished;
    /* user thread only */
    uint32_t user_data_size;
    uint64_t[SFETCH_MAX_USERDATA_UINT64] user_data;
} 

/* thread-side per-request state */
struct _sfetch_item_thread_t{
    /* transfer IO => user thread */
    uint32_t fetched_offset;
    uint32_t fetched_size;
    sfetch_error_t error_code;
    bool failed;
    bool finished;
    /* IO thread only */
    version(WASM)
        uint32_t http_range_offset;
    else
        _sfetch_file_handle_t file_handle;
    uint32_t content_size;
}

/* a request goes through the following states, ping-ponging between IO and user thread */
enum _sfetch_state_t {
    _SFETCH_STATE_INITIAL,      /* internal: request has just been initialized */
    _SFETCH_STATE_ALLOCATED,    /* internal: request has been allocated from internal pool */
    _SFETCH_STATE_DISPATCHED,   /* user thread: request has been dispatched to its IO channel */
    _SFETCH_STATE_FETCHING,     /* IO thread: waiting for data to be fetched */
    _SFETCH_STATE_FETCHED,      /* user thread: fetched data available */
    _SFETCH_STATE_PAUSED,       /* user thread: request has been paused via sfetch_pause() */
    _SFETCH_STATE_FAILED,       /* user thread: follow state or FETCHING if something went wrong */
}

enum _SFETCH_INVALID_LANE = (0xFFFFFFFF);

struct _sfetch_item_t {
    sfetch_handle_t handle;
    _sfetch_state_t state;
    uint32_t channel;
    uint32_t lane;
    uint32_t chunk_size;
    sfetch_callback_t callback;
    _sfetch_buffer_t buffer;

    /* updated by IO-thread, off-limits to user thread */
    _sfetch_item_thread_t thread;

    /* accessible by user-thread, off-limits to IO thread */
    _sfetch_item_user_t user;

    /* big stuff at the end */
    _sfetch_path_t path;
} 

/* a pool of internal per-request items */
struct _sfetch_pool_t {
    uint32_t size;
    uint32_t free_top;
    _sfetch_item_t* items;
    uint32_t* free_slots;
    uint32_t* gen_ctrs;
    bool valid;
} 

/* a ringbuffer for pool-slot ids */
struct _sfetch_ring_t {
    uint32_t head;
    uint32_t tail;
    uint32_t num;
    uint32_t* buf;
}

/* an IO channel with its own IO thread */
struct _sfetch_channel_t {
    _sfetch_t* ctx;  /* back-pointer to thread-local _sfetch state pointer,
                               since this isn't accessible from the IO threads */
    _sfetch_ring_t free_lanes;
    _sfetch_ring_t user_sent;
    _sfetch_ring_t user_incoming;
    _sfetch_ring_t user_outgoing;


    version(_SFETCH_HAS_THREADS)
    {
        _sfetch_ring_t thread_incoming;
        _sfetch_ring_t thread_outgoing;
        _sfetch_thread_t thread;
    }
    void function(_sfetch_t* ctx, uint32_t slot_id) request_handler;
    bool valid;
}

/* the sfetch global state */
struct _sfetch_t {
    bool setup;
    bool valid;
    bool in_callback;
    sfetch_desc_t desc;
    _sfetch_pool_t pool;
    _sfetch_channel_t[SFETCH_MAX_CHANNELS] chn;
}

__gshared _sfetch_t* _sfetch;

T _sfetch_def(T)(T val, T def) {
    return (val == 0) ? def : val;
}

_sfetch_t* _sfetch_ctx() {
    return _sfetch;
}

void _sfetch_path_copy(_sfetch_path_t* dst, const (char)*src) {
    SOKOL_ASSERT(dst);
    if (src && (strlen(src) < SFETCH_MAX_PATH)) {

        //#if defined(_MSC_VER)
        //strncpy_s(dst.buf, SFETCH_MAX_PATH, src, (SFETCH_MAX_PATH-1));
        //#else
        strncpy(dst.buf.ptr, src, SFETCH_MAX_PATH);
        //#endif
        dst.buf[SFETCH_MAX_PATH-1] = 0;
    }
    else {
        memset(dst.buf.ptr, 0, SFETCH_MAX_PATH);
    }
}

_sfetch_path_t _sfetch_path_make(const (char)*str) {
    _sfetch_path_t res;
    _sfetch_path_copy(&res, str);
    return res;
}

uint32_t _sfetch_make_id(uint32_t index, uint32_t gen_ctr) {
    return (gen_ctr<<16) | (index & 0xFFFF);
}

sfetch_handle_t _sfetch_make_handle(uint32_t slot_id) {
    sfetch_handle_t h;
    h.id = slot_id;
    return h;
}

uint32_t _sfetch_slot_index(uint32_t slot_id) {
    return slot_id & 0xFFFF;
}

/*=== a circular message queue ===============================================*/
uint32_t _sfetch_ring_wrap(const (_sfetch_ring_t)* rb, uint32_t i) {
    return i % rb.num;
}

void _sfetch_ring_discard(_sfetch_ring_t* rb) {
    SOKOL_ASSERT(rb);
    if (rb.buf) {
        SOKOL_FREE(rb.buf);
        rb.buf = null;
    }
    rb.head = 0;
    rb.tail = 0;
    rb.num = 0;
}

bool _sfetch_ring_init(_sfetch_ring_t* rb, uint32_t num_slots) {
    SOKOL_ASSERT(rb && (num_slots > 0));
    SOKOL_ASSERT(null == rb.buf);
    rb.head = 0;
    rb.tail = 0;
    /* one slot reserved to detect full vs empty */
    rb.num = num_slots + 1;
    const size_t queue_size = rb.num * (sfetch_handle_t.sizeof);
    rb.buf = cast(uint32_t*) SOKOL_MALLOC(queue_size);
    if (rb.buf) {
        memset(rb.buf, 0, queue_size);
        return true;
    }
    else {
        _sfetch_ring_discard(rb);
        return false;
    }
}

bool _sfetch_ring_full(const (_sfetch_ring_t)* rb) {
    SOKOL_ASSERT(rb && rb.buf);
    return _sfetch_ring_wrap(rb, rb.head + 1) == rb.tail;
}

bool _sfetch_ring_empty(const (_sfetch_ring_t)* rb) {
    SOKOL_ASSERT(rb && rb.buf);
    return rb.head == rb.tail;
}

uint32_t _sfetch_ring_count(const (_sfetch_ring_t)* rb) {
    SOKOL_ASSERT(rb && rb.buf);
    uint32_t count;
    if (rb.head >= rb.tail) {
        count = rb.head - rb.tail;
    }
    else {
        count = (rb.head + rb.num) - rb.tail;
    }
    SOKOL_ASSERT(count < rb.num);
    return count;
}

void _sfetch_ring_enqueue(_sfetch_ring_t* rb, uint32_t slot_id) {
    SOKOL_ASSERT(rb && rb.buf);
    SOKOL_ASSERT(!_sfetch_ring_full(rb));
    SOKOL_ASSERT(rb.head < rb.num);
    rb.buf[rb.head] = slot_id;
    rb.head = _sfetch_ring_wrap(rb, rb.head + 1);
}

uint32_t _sfetch_ring_dequeue(_sfetch_ring_t* rb) {
    SOKOL_ASSERT(rb && rb.buf);
    SOKOL_ASSERT(!_sfetch_ring_empty(rb));
    SOKOL_ASSERT(rb.tail < rb.num);
    uint32_t slot_id = rb.buf[rb.tail];
    rb.tail = _sfetch_ring_wrap(rb, rb.tail + 1);
    return slot_id;
}

uint32_t _sfetch_ring_peek(const (_sfetch_ring_t)* rb, uint32_t index) {
    SOKOL_ASSERT(rb && rb.buf);
    SOKOL_ASSERT(!_sfetch_ring_empty(rb));
    SOKOL_ASSERT(index < _sfetch_ring_count(rb));
    uint32_t rb_index = _sfetch_ring_wrap(rb, rb.tail + index);
    return rb.buf[rb_index];
}

/*=== request pool implementation ============================================*/
void _sfetch_item_init(_sfetch_item_t* item, uint32_t slot_id, const (sfetch_request_t)* request) {
    SOKOL_ASSERT(item && (0 == item.handle.id));
    SOKOL_ASSERT(request && request.path);
    memset(item, 0, (_sfetch_item_t.sizeof));
    item.handle.id = slot_id;
    item.state = _sfetch_state_t._SFETCH_STATE_INITIAL;
    item.channel = request.channel;
    item.chunk_size = request.chunk_size;
    item.lane = _SFETCH_INVALID_LANE;
    item.callback = request.callback;
    item.buffer.ptr = cast(uint8_t*) request.buffer_ptr;
    item.buffer.size = request.buffer_size;
    item.path = _sfetch_path_make(request.path);


    version(WASM){}
    else
        item.thread.file_handle = _SFETCH_INVALID_FILE_HANDLE;
    
    
    if (request.user_data_ptr &&
        (request.user_data_size > 0) &&
        (request.user_data_size <= (SFETCH_MAX_USERDATA_UINT64*8)))
    {
        item.user.user_data_size = request.user_data_size;
        memcpy(item.user.user_data.ptr, request.user_data_ptr, request.user_data_size);
    }
}

void _sfetch_item_discard(_sfetch_item_t* item) {
    SOKOL_ASSERT(item && (0 != item.handle.id));
    memset(item, 0, (_sfetch_item_t.sizeof));
}

void _sfetch_pool_discard(_sfetch_pool_t* pool) {
    SOKOL_ASSERT(pool);
    if (pool.free_slots) {
        SOKOL_FREE(pool.free_slots);
        pool.free_slots = null;
    }
    if (pool.gen_ctrs) {
        SOKOL_FREE(pool.gen_ctrs);
        pool.gen_ctrs = null;
    }
    if (pool.items) {
        SOKOL_FREE(pool.items);
        pool.items = null;
    }
    pool.size = 0;
    pool.free_top = 0;
    pool.valid = false;
}

bool _sfetch_pool_init(_sfetch_pool_t* pool, uint32_t num_items) {
    SOKOL_ASSERT(pool && (num_items > 0) && (num_items < ((1<<16)-1)));
    SOKOL_ASSERT(null == pool.items);
    /* NOTE: item slot 0 is reserved for the special "invalid" item index 0*/
    pool.size = num_items + 1;
    pool.free_top = 0;
    const size_t items_size = pool.size * (_sfetch_item_t.sizeof);
    pool.items = cast(_sfetch_item_t*) SOKOL_MALLOC(items_size);
    /* generation counters indexable by pool slot index, slot 0 is reserved */
    const size_t gen_ctrs_size = (uint32_t.sizeof) * pool.size;
    pool.gen_ctrs = cast(uint32_t*) SOKOL_MALLOC(gen_ctrs_size);
    SOKOL_ASSERT(pool.gen_ctrs);
    /* NOTE: it's not a bug to only reserve num_items here */
    const size_t free_slots_size = num_items * (int.sizeof);
    pool.free_slots = cast(uint32_t*) SOKOL_MALLOC(free_slots_size);
    if (pool.items && pool.free_slots) {
        memset(pool.items, 0, items_size);
        memset(pool.gen_ctrs, 0, gen_ctrs_size);
        /* never allocate the 0-th item, this is the reserved 'invalid item' */
        for (uint32_t i = pool.size - 1; i >= 1; i--) {
            pool.free_slots[pool.free_top++] = i;
        }
        pool.valid = true;
    }
    else {
        /* allocation error */
        _sfetch_pool_discard(pool);
    }
    return pool.valid;
}

uint32_t _sfetch_pool_item_alloc(_sfetch_pool_t* pool, const (sfetch_request_t)* request) {
    SOKOL_ASSERT(pool && pool.valid);
    if (pool.free_top > 0) {
        uint32_t slot_index = pool.free_slots[--pool.free_top];
        SOKOL_ASSERT((slot_index > 0) && (slot_index < pool.size));
        uint32_t slot_id = _sfetch_make_id(slot_index, ++pool.gen_ctrs[slot_index]);
        _sfetch_item_init(&pool.items[slot_index], slot_id, request);
        pool.items[slot_index].state = _sfetch_state_t._SFETCH_STATE_ALLOCATED;
        return slot_id;
    }
    else {
        /* pool exhausted, return the 'invalid handle' */
        return _sfetch_make_id(0, 0);
    }
}

void _sfetch_pool_item_free(_sfetch_pool_t* pool, uint32_t slot_id) {
    SOKOL_ASSERT(pool && pool.valid);
    uint32_t slot_index = _sfetch_slot_index(slot_id);
    SOKOL_ASSERT((slot_index > 0) && (slot_index < pool.size));
    SOKOL_ASSERT(pool.items[slot_index].handle.id == slot_id);

    version(SOKOL_DEBUG)
    {
    /* debug check against double-free */
    for (uint32_t i = 0; i < pool.free_top; i++) {
        SOKOL_ASSERT(pool.free_slots[i] != slot_index);
    }
    }
    _sfetch_item_discard(&pool.items[slot_index]);
    pool.free_slots[pool.free_top++] = slot_index;
    SOKOL_ASSERT(pool.free_top <= (pool.size - 1));
}

/* return pointer to item by handle without matching id check */
_sfetch_item_t* _sfetch_pool_item_at(_sfetch_pool_t* pool, uint32_t slot_id) {
    SOKOL_ASSERT(pool && pool.valid);
    uint32_t slot_index = _sfetch_slot_index(slot_id);
    SOKOL_ASSERT((slot_index > 0) && (slot_index < pool.size));
    return &pool.items[slot_index];
}

/* return pointer to item by handle with matching id check */
_sfetch_item_t* _sfetch_pool_item_lookup(_sfetch_pool_t* pool, uint32_t slot_id) {
    SOKOL_ASSERT(pool && pool.valid);
    if (0 != slot_id) {
        _sfetch_item_t* item = _sfetch_pool_item_at(pool, slot_id);
        if (item.handle.id == slot_id) {
            return item;
        }
    }
    return null;
}

/*=== PLATFORM WRAPPER FUNCTIONS =============================================*/
version(Posix)
{
_sfetch_file_handle_t _sfetch_file_open(const (_sfetch_path_t)* path) {
    return fopen(path.buf, "rb");
}

void _sfetch_file_close(_sfetch_file_handle_t h) {
    fclose(h);
}

bool _sfetch_file_handle_valid(_sfetch_file_handle_t h) {
    return h != _SFETCH_INVALID_FILE_HANDLE;
}

uint32_t _sfetch_file_size(_sfetch_file_handle_t h) {
    fseek(h, 0, SEEK_END);
    return cast(uint32_t) ftell(h);
}

bool _sfetch_file_read(_sfetch_file_handle_t h, uint32_t offset, uint32_t num_bytes, void* ptr) {
    fseek(h, cast(long)offset, SEEK_SET);
    return num_bytes == fread(ptr, 1, num_bytes, h);
}

bool _sfetch_thread_init(_sfetch_thread_t* thread, _sfetch_thread_func_t thread_func, void* thread_arg) {
    SOKOL_ASSERT(thread && !thread.valid && !thread.stop_requested);

    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutex_init(&thread.incoming_mutex, &attr);
    pthread_mutexattr_destroy(&attr);

    pthread_mutexattr_init(&attr);
    pthread_mutex_init(&thread.outgoing_mutex, &attr);
    pthread_mutexattr_destroy(&attr);

    pthread_mutexattr_init(&attr);
    pthread_mutex_init(&thread.running_mutex, &attr);
    pthread_mutexattr_destroy(&attr);

    pthread_mutexattr_init(&attr);
    pthread_mutex_init(&thread.stop_mutex, &attr);
    pthread_mutexattr_destroy(&attr);

    pthread_condattr_t cond_attr;
    pthread_condattr_init(&cond_attr);
    pthread_cond_init(&thread.incoming_cond, &cond_attr);
    pthread_condattr_destroy(&cond_attr);

    /* FIXME: in debug mode, the threads should be named */
    pthread_mutex_lock(&thread.running_mutex);
    int res = pthread_create(&thread.thread, 0, thread_func, thread_arg);
    thread.valid = (0 == res);
    pthread_mutex_unlock(&thread.running_mutex);
    return thread.valid;
}

void _sfetch_thread_request_stop(_sfetch_thread_t* thread) {
    pthread_mutex_lock(&thread.stop_mutex);
    thread.stop_requested = true;
    pthread_mutex_unlock(&thread.stop_mutex);
}

bool _sfetch_thread_stop_requested(_sfetch_thread_t* thread) {
    pthread_mutex_lock(&thread.stop_mutex);
    bool stop_requested = thread.stop_requested;
    pthread_mutex_unlock(&thread.stop_mutex);
    return stop_requested;
}

void _sfetch_thread_join(_sfetch_thread_t* thread) {
    SOKOL_ASSERT(thread);
    if (thread.valid) {
        pthread_mutex_lock(&thread.incoming_mutex);
        _sfetch_thread_request_stop(thread);
        pthread_cond_signal(&thread.incoming_cond);
        pthread_mutex_unlock(&thread.incoming_mutex);
        pthread_join(thread.thread, 0);
        thread.valid = false;
    }
    pthread_mutex_destroy(&thread.stop_mutex);
    pthread_mutex_destroy(&thread.running_mutex);
    pthread_mutex_destroy(&thread.incoming_mutex);
    pthread_mutex_destroy(&thread.outgoing_mutex);
    pthread_cond_destroy(&thread.incoming_cond);
}

/* called when the thread-func is entered, this blocks the thread func until
   the _sfetch_thread_t object is fully initialized
*/
void _sfetch_thread_entered(_sfetch_thread_t* thread) {
    pthread_mutex_lock(&thread.running_mutex);
}

/* called by the thread-func right before it is left */
void _sfetch_thread_leaving(_sfetch_thread_t* thread) {
    pthread_mutex_unlock(&thread.running_mutex);
}

void _sfetch_thread_enqueue_incoming(_sfetch_thread_t* thread, _sfetch_ring_t* incoming, _sfetch_ring_t* src) {
    /* called from user thread */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(incoming && incoming.buf);
    SOKOL_ASSERT(src && src.buf);
    if (!_sfetch_ring_empty(src)) {
        pthread_mutex_lock(&thread.incoming_mutex);
        while (!_sfetch_ring_full(incoming) && !_sfetch_ring_empty(src)) {
            _sfetch_ring_enqueue(incoming, _sfetch_ring_dequeue(src));
        }
        pthread_cond_signal(&thread.incoming_cond);
        pthread_mutex_unlock(&thread.incoming_mutex);
    }
}

uint32_t _sfetch_thread_dequeue_incoming(_sfetch_thread_t* thread, _sfetch_ring_t* incoming) {
    /* called from thread function */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(incoming && incoming.buf);
    pthread_mutex_lock(&thread.incoming_mutex);
    while (_sfetch_ring_empty(incoming) && !thread.stop_requested) {
        pthread_cond_wait(&thread.incoming_cond, &thread.incoming_mutex);
    }
    uint32_t item = 0;
    if (!thread.stop_requested) {
        item = _sfetch_ring_dequeue(incoming);
    }
    pthread_mutex_unlock(&thread.incoming_mutex);
    return item;
}

bool _sfetch_thread_enqueue_outgoing(_sfetch_thread_t* thread, _sfetch_ring_t* outgoing, uint32_t item) {
    /* called from thread function */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(outgoing && outgoing.buf);
    SOKOL_ASSERT(0 != item);
    pthread_mutex_lock(&thread.outgoing_mutex);
    bool result = false;
    if (!_sfetch_ring_full(outgoing)) {
        _sfetch_ring_enqueue(outgoing, item);
    }
    pthread_mutex_unlock(&thread.outgoing_mutex);
    return result;
}

void _sfetch_thread_dequeue_outgoing(_sfetch_thread_t* thread, _sfetch_ring_t* outgoing, _sfetch_ring_t* dst) {
    /* called from user thread */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(outgoing && outgoing.buf);
    SOKOL_ASSERT(dst && dst.buf);
    pthread_mutex_lock(&thread.outgoing_mutex);
    while (!_sfetch_ring_full(dst) && !_sfetch_ring_empty(outgoing)) {
        _sfetch_ring_enqueue(dst, _sfetch_ring_dequeue(outgoing));
    }
    pthread_mutex_unlock(&thread.outgoing_mutex);
}
}


version(Windows)
{
bool _sfetch_win32_utf8_to_wide(const (char)*src, wchar_t* dst, int dst_num_bytes) {
    SOKOL_ASSERT(src && dst && (dst_num_bytes > 1));
    memset(dst, 0, cast(size_t)dst_num_bytes);
    const int dst_chars = dst_num_bytes / cast(int)(wchar_t.sizeof);
    const int dst_needed = MultiByteToWideChar(CP_UTF8, 0, src, -1, null, 0);
    if ((dst_needed > 0) && (dst_needed < dst_chars)) {
        MultiByteToWideChar(CP_UTF8, 0, src, -1, dst, dst_chars);
        return true;
    }
    else {
        /* input string doesn't fit into destination buffer */
        return false;
    }
}

_sfetch_file_handle_t _sfetch_file_open(const (_sfetch_path_t)* path) {
    wchar_t[SFETCH_MAX_PATH] w_path;
    if (!_sfetch_win32_utf8_to_wide(path.buf.ptr, w_path.ptr, (w_path.sizeof))) {
        SOKOL_LOG("_sfetch_file_open: error converting UTF-8 path to wide string");
        return null;
    }
    _sfetch_file_handle_t h = CreateFileW(
        w_path.ptr,                 /* lpFileName */
        GENERIC_READ,           /* dwDesiredAccess */
        FILE_SHARE_READ,        /* dwShareMode */
        null,                   /* lpSecurityAttributes */
        OPEN_EXISTING,          /* dwCreationDisposition */
        FILE_ATTRIBUTE_NORMAL|FILE_FLAG_SEQUENTIAL_SCAN,    /* dwFlagsAndAttributes */
        null);                  /* hTemplateFile */
    return h;
}

void _sfetch_file_close(_sfetch_file_handle_t h) {
    CloseHandle(h);
}

bool _sfetch_file_handle_valid(_sfetch_file_handle_t h) {
    return h != _SFETCH_INVALID_FILE_HANDLE;
}

uint32_t _sfetch_file_size(_sfetch_file_handle_t h) {
    return GetFileSize(h, null);
}

bool _sfetch_file_read(_sfetch_file_handle_t h, uint32_t offset, uint32_t num_bytes, void* ptr) {
    LARGE_INTEGER offset_li;
    offset_li.QuadPart = offset;
    BOOL seek_res = SetFilePointerEx(h, offset_li, null, FILE_BEGIN);
    if (seek_res) {
        DWORD bytes_read = 0;
        BOOL read_res = ReadFile(h, ptr, cast(DWORD)num_bytes, &bytes_read, null);
        return read_res && (bytes_read == num_bytes);
    }
    else {
        return false;
    }
}

bool _sfetch_thread_init(_sfetch_thread_t* thread, _sfetch_thread_func_t thread_func, void* thread_arg) {
    SOKOL_ASSERT(thread && !thread.valid && !thread.stop_requested);

    thread.incoming_event = CreateEventA(null, FALSE, FALSE, null);
    SOKOL_ASSERT(null != thread.incoming_event);
    InitializeCriticalSection(&thread.incoming_critsec);
    InitializeCriticalSection(&thread.outgoing_critsec);
    InitializeCriticalSection(&thread.running_critsec);
    InitializeCriticalSection(&thread.stop_critsec);

    EnterCriticalSection(&thread.running_critsec);
    const SIZE_T stack_size = 512 * 1024;
    thread.thread = CreateThread(null, stack_size, thread_func, thread_arg, 0, null);
    thread.valid = (null != thread.thread);
    LeaveCriticalSection(&thread.running_critsec);
    return thread.valid;
}

void _sfetch_thread_request_stop(_sfetch_thread_t* thread) {
    EnterCriticalSection(&thread.stop_critsec);
    thread.stop_requested = true;
    LeaveCriticalSection(&thread.stop_critsec);
}

bool _sfetch_thread_stop_requested(_sfetch_thread_t* thread) {
    EnterCriticalSection(&thread.stop_critsec);
    bool stop_requested = thread.stop_requested;
    LeaveCriticalSection(&thread.stop_critsec);
    return stop_requested;
}

void _sfetch_thread_join(_sfetch_thread_t* thread) {
    if (thread.valid) {
        EnterCriticalSection(&thread.incoming_critsec);
        _sfetch_thread_request_stop(thread);
        BOOL set_event_res = SetEvent(thread.incoming_event);
        //_SOKOL_UNUSED(set_event_res);
        SOKOL_ASSERT(set_event_res);
        LeaveCriticalSection(&thread.incoming_critsec);
        WaitForSingleObject(thread.thread, INFINITE);
        CloseHandle(thread.thread);
        thread.valid = false;
    }
    CloseHandle(thread.incoming_event);
    DeleteCriticalSection(&thread.stop_critsec);
    DeleteCriticalSection(&thread.running_critsec);
    DeleteCriticalSection(&thread.outgoing_critsec);
    DeleteCriticalSection(&thread.incoming_critsec);
}

void _sfetch_thread_entered(_sfetch_thread_t* thread) {
    EnterCriticalSection(&thread.running_critsec);
}

/* called by the thread-func right before it is left */
void _sfetch_thread_leaving(_sfetch_thread_t* thread) {
    LeaveCriticalSection(&thread.running_critsec);
}

void _sfetch_thread_enqueue_incoming(_sfetch_thread_t* thread, _sfetch_ring_t* incoming, _sfetch_ring_t* src) {
    /* called from user thread */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(incoming && incoming.buf);
    SOKOL_ASSERT(src && src.buf);
    if (!_sfetch_ring_empty(src)) {
        EnterCriticalSection(&thread.incoming_critsec);
        while (!_sfetch_ring_full(incoming) && !_sfetch_ring_empty(src)) {
            _sfetch_ring_enqueue(incoming, _sfetch_ring_dequeue(src));
        }
        LeaveCriticalSection(&thread.incoming_critsec);
        BOOL set_event_res = SetEvent(thread.incoming_event);
        // _SOKOL_UNUSED(set_event_res);
        SOKOL_ASSERT(set_event_res);
    }
}

uint32_t _sfetch_thread_dequeue_incoming(_sfetch_thread_t* thread, _sfetch_ring_t* incoming) {
    /* called from thread function */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(incoming && incoming.buf);
    EnterCriticalSection(&thread.incoming_critsec);
    while (_sfetch_ring_empty(incoming) && !thread.stop_requested) {
        LeaveCriticalSection(&thread.incoming_critsec);
        WaitForSingleObject(thread.incoming_event, INFINITE);
        EnterCriticalSection(&thread.incoming_critsec);
    }
    uint32_t item = 0;
    if (!thread.stop_requested) {
        item = _sfetch_ring_dequeue(incoming);
    }
    LeaveCriticalSection(&thread.incoming_critsec);
    return item;
}

bool _sfetch_thread_enqueue_outgoing(_sfetch_thread_t* thread, _sfetch_ring_t* outgoing, uint32_t item) {
    /* called from thread function */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(outgoing && outgoing.buf);
    EnterCriticalSection(&thread.outgoing_critsec);
    bool result = false;
    if (!_sfetch_ring_full(outgoing)) {
        _sfetch_ring_enqueue(outgoing, item);
    }
    LeaveCriticalSection(&thread.outgoing_critsec);
    return result;
}

void _sfetch_thread_dequeue_outgoing(_sfetch_thread_t* thread, _sfetch_ring_t* outgoing, _sfetch_ring_t* dst) {
    /* called from user thread */
    SOKOL_ASSERT(thread && thread.valid);
    SOKOL_ASSERT(outgoing && outgoing.buf);
    SOKOL_ASSERT(dst && dst.buf);
    EnterCriticalSection(&thread.outgoing_critsec);
    while (!_sfetch_ring_full(dst) && !_sfetch_ring_empty(outgoing)) {
        _sfetch_ring_enqueue(dst, _sfetch_ring_dequeue(outgoing));
    }
    LeaveCriticalSection(&thread.outgoing_critsec);
}
}

/*=== IO CHANNEL implementation ==============================================*/

/* per-channel request handler for native platforms accessing the local filesystem */
version(_SFETCH_HAS_THREADS)
{
void _sfetch_request_handler(_sfetch_t* ctx, uint32_t slot_id) {
    _sfetch_state_t state;
    _sfetch_path_t* path;
    _sfetch_item_thread_t* thread;
    _sfetch_buffer_t* buffer;
    uint32_t chunk_size;
    {
        _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, slot_id);
        if (!item) {
            return;
        }
        state = item.state;
        SOKOL_ASSERT((state == _sfetch_state_t._SFETCH_STATE_FETCHING) ||
                     (state == _sfetch_state_t._SFETCH_STATE_PAUSED) ||
                     (state == _sfetch_state_t._SFETCH_STATE_FAILED));
        path = &item.path;
        thread = &item.thread;
        buffer = &item.buffer;
        chunk_size = item.chunk_size;
    }
    if (thread.failed) {
        return;
    }
    if (state == _sfetch_state_t._SFETCH_STATE_FETCHING) {
        if ((buffer.ptr == null) || (buffer.size == 0)) {
            thread.error_code = sfetch_error_t.SFETCH_ERROR_NO_BUFFER;
            thread.failed = true;
        }
        else {
            /* open file if not happened yet */
            if (!_sfetch_file_handle_valid(thread.file_handle)) {
                SOKOL_ASSERT(path.buf[0]);
                SOKOL_ASSERT(thread.fetched_offset == 0);
                SOKOL_ASSERT(thread.fetched_size == 0);
                thread.file_handle = _sfetch_file_open(path);
                if (_sfetch_file_handle_valid(thread.file_handle)) {
                    thread.content_size = _sfetch_file_size(thread.file_handle);
                }
                else {
                    thread.error_code = sfetch_error_t.SFETCH_ERROR_FILE_NOT_FOUND;
                    thread.failed = true;
                }
            }
            if (!thread.failed) {
                uint32_t read_offset = 0;
                uint32_t bytes_to_read = 0;
                if (chunk_size == 0) {
                    /* load entire file */
                    if (thread.content_size <= buffer.size) {
                        bytes_to_read = thread.content_size;
                        read_offset = 0;
                    }
                    else {
                        /* provided buffer to small to fit entire file */
                        thread.error_code = sfetch_error_t.SFETCH_ERROR_BUFFER_TOO_SMALL;
                        thread.failed = true;
                    }
                }
                else {
                    if (chunk_size <= buffer.size) {
                        bytes_to_read = chunk_size;
                        read_offset = thread.fetched_offset;
                        if ((read_offset + bytes_to_read) > thread.content_size) {
                            bytes_to_read = thread.content_size - read_offset;
                        }
                    }
                    else {
                        /* provided buffer to small to fit next chunk */
                        thread.error_code = sfetch_error_t.SFETCH_ERROR_BUFFER_TOO_SMALL;
                        thread.failed = true;
                    }
                }
                if (!thread.failed) {
                    if (_sfetch_file_read(thread.file_handle, read_offset, bytes_to_read, buffer.ptr)) {
                        thread.fetched_size = bytes_to_read;
                        thread.fetched_offset += bytes_to_read;
                    }
                    else {
                        thread.error_code = sfetch_error_t.SFETCH_ERROR_UNEXPECTED_EOF;
                        thread.failed = true;
                    }
                }
            }
        }
        SOKOL_ASSERT(thread.fetched_offset <= thread.content_size);
        if (thread.failed || (thread.fetched_offset == thread.content_size)) {
            if (_sfetch_file_handle_valid(thread.file_handle)) {
                _sfetch_file_close(thread.file_handle);
                thread.file_handle = _SFETCH_INVALID_FILE_HANDLE;
            }
            thread.finished = true;
        }
    }
    /* ignore items in PAUSED or FAILED state */
}

version(Windows)
{
    alias channel_thread_r = DWORD;
    alias channel_thread_p = LPVOID;
}
else
{
    alias channel_thread_r = void*;
    alias channel_thread_p = void*;
}


channel_thread_r _sfetch_channel_thread_func(channel_thread_p arg) {
    _sfetch_channel_t* chn = cast(_sfetch_channel_t*) arg;
    _sfetch_thread_entered(&chn.thread);
    while (!_sfetch_thread_stop_requested(&chn.thread)) {
        /* block until work arrives */
        uint32_t slot_id = _sfetch_thread_dequeue_incoming(&chn.thread, &chn.thread_incoming);
        /* slot_id will be invalid if the thread was woken up to join */
        if (!_sfetch_thread_stop_requested(&chn.thread)) {
            SOKOL_ASSERT(0 != slot_id);
            chn.request_handler(chn.ctx, slot_id);
            SOKOL_ASSERT(!_sfetch_ring_full(&chn.thread_outgoing));
            _sfetch_thread_enqueue_outgoing(&chn.thread, &chn.thread_outgoing, slot_id);
        }
    }
    _sfetch_thread_leaving(&chn.thread);
    return 0;
}
}

void _sfetch_channel_discard(_sfetch_channel_t* chn) {
    SOKOL_ASSERT(chn);
    version(_SFETCH_HAS_THREADS)
    {
        if (chn.valid) {
            _sfetch_thread_join(&chn.thread);
        }
        _sfetch_ring_discard(&chn.thread_incoming);
        _sfetch_ring_discard(&chn.thread_outgoing);
    }
    _sfetch_ring_discard(&chn.free_lanes);
    _sfetch_ring_discard(&chn.user_sent);
    _sfetch_ring_discard(&chn.user_incoming);
    _sfetch_ring_discard(&chn.user_outgoing);
    _sfetch_ring_discard(&chn.free_lanes);
    chn.valid = false;
}

bool _sfetch_channel_init(_sfetch_channel_t* chn, _sfetch_t* ctx, uint32_t num_items, uint32_t num_lanes, void function(_sfetch_t* ctx, uint32_t) request_handler) {
    SOKOL_ASSERT(chn && (num_items > 0) && request_handler);
    SOKOL_ASSERT(!chn.valid);
    bool valid = true;
    chn.request_handler = request_handler;
    chn.ctx = ctx;
    valid &= _sfetch_ring_init(&chn.free_lanes, num_lanes);
    for (uint32_t lane = 0; lane < num_lanes; lane++) {
        _sfetch_ring_enqueue(&chn.free_lanes, lane);
    }
    valid &= _sfetch_ring_init(&chn.user_sent, num_items);
    valid &= _sfetch_ring_init(&chn.user_incoming, num_lanes);
    valid &= _sfetch_ring_init(&chn.user_outgoing, num_lanes);

    version(_SFETCH_HAS_THREADS)
    {
        valid &= _sfetch_ring_init(&chn.thread_incoming, num_lanes);
        valid &= _sfetch_ring_init(&chn.thread_outgoing, num_lanes);
    }
    if (valid) {
        chn.valid = true;
        version(SFETCH_HAS_THREADS)
            _sfetch_thread_init(&chn.thread, _sfetch_channel_thread_func, chn);
        return true;
    }
    else {
        _sfetch_channel_discard(chn);
        return false;
    }
}

/* put a request into the channels sent-queue, this is where all new requests
   are stored until a lane becomes free.
*/
bool _sfetch_channel_send(_sfetch_channel_t* chn, uint32_t slot_id) {
    SOKOL_ASSERT(chn && chn.valid);
    if (!_sfetch_ring_full(&chn.user_sent)) {
        _sfetch_ring_enqueue(&chn.user_sent, slot_id);
        return true;
    }
    else {
        SOKOL_LOG("sfetch_send: user_sent queue is full)");
        return false;
    }
}

void _sfetch_invoke_response_callback(_sfetch_item_t* item) {
    sfetch_response_t response;
    memset(&response, 0, (response.sizeof));
    response.handle = item.handle;
    response.dispatched = (item.state == _sfetch_state_t._SFETCH_STATE_DISPATCHED);
    response.fetched = (item.state == _sfetch_state_t._SFETCH_STATE_FETCHED);
    response.paused = (item.state == _sfetch_state_t._SFETCH_STATE_PAUSED);
    response.finished = item.user.finished;
    response.failed = (item.state == _sfetch_state_t._SFETCH_STATE_FAILED);
    response.cancelled = item.user.cancel;
    response.error_code = item.user.error_code;
    response.channel = item.channel;
    response.lane = item.lane;
    response.path = item.path.buf.ptr;
    response.user_data = item.user.user_data.ptr;
    response.fetched_offset = item.user.fetched_offset - item.user.fetched_size;
    response.fetched_size = item.user.fetched_size;
    response.buffer_ptr = item.buffer.ptr;
    response.buffer_size = item.buffer.size;
    item.callback(&response);
}

/* per-frame channel stuff: move requests in and out of the IO threads, call response callbacks */
void _sfetch_channel_dowork(_sfetch_channel_t* chn, _sfetch_pool_t* pool) {

    /* move items from sent- to incoming-queue permitting free lanes */
    const uint32_t num_sent = _sfetch_ring_count(&chn.user_sent);
    const uint32_t avail_lanes = _sfetch_ring_count(&chn.free_lanes);
    const uint32_t num_move = (num_sent < avail_lanes) ? num_sent : avail_lanes;
    for (uint32_t i = 0; i < num_move; i++) {
        const uint32_t slot_id = _sfetch_ring_dequeue(&chn.user_sent);
        _sfetch_item_t* item = _sfetch_pool_item_lookup(pool, slot_id);
        SOKOL_ASSERT(item);
        SOKOL_ASSERT(item.state == _sfetch_state_t._SFETCH_STATE_ALLOCATED);
        item.state = _sfetch_state_t._SFETCH_STATE_DISPATCHED;
        item.lane = _sfetch_ring_dequeue(&chn.free_lanes);
        /* if no buffer provided yet, invoke response callback to do so */
        if (null == item.buffer.ptr) {
            _sfetch_invoke_response_callback(item);
        }
        _sfetch_ring_enqueue(&chn.user_incoming, slot_id);
    }

    /* prepare incoming items for being moved into the IO thread */
    const uint32_t num_incoming = _sfetch_ring_count(&chn.user_incoming);
    for (uint32_t i = 0; i < num_incoming; i++) {
        const uint32_t slot_id = _sfetch_ring_peek(&chn.user_incoming, i);
        _sfetch_item_t* item = _sfetch_pool_item_lookup(pool, slot_id);
        SOKOL_ASSERT(item);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_INITIAL);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_FETCHING);
        /* transfer input params from user- to thread-data */
        if (item.user.pause) {
            item.state = _sfetch_state_t._SFETCH_STATE_PAUSED;
            item.user.pause = false;
        }
        if (item.user.cont) {
            if (item.state == _sfetch_state_t._SFETCH_STATE_PAUSED) {
                item.state = _sfetch_state_t._SFETCH_STATE_FETCHED;
            }
            item.user.cont = false;
        }
        if (item.user.cancel) {
            item.state = _sfetch_state_t._SFETCH_STATE_FAILED;
            item.user.finished = true;
        }
        switch (item.state) with (_sfetch_state_t) {
            case _SFETCH_STATE_DISPATCHED:
            case _SFETCH_STATE_FETCHED:
                item.state = _SFETCH_STATE_FETCHING;
                break;
            default: break;
        }
    }

    version(_SFETCH_HAS_THREADS)
    {
        /* move new items into the IO threads and processed items out of IO threads */
        _sfetch_thread_enqueue_incoming(&chn.thread, &chn.thread_incoming, &chn.user_incoming);
        _sfetch_thread_dequeue_outgoing(&chn.thread, &chn.thread_outgoing, &chn.user_outgoing);
    }
    else
    {
        /* without threading just directly dequeue items from the user_incoming queue and
           call the request handler, the user_outgoing queue will be filled as the
           asynchronous HTTP requests sent by the request handler are completed
        */
        while (!_sfetch_ring_empty(&chn.user_incoming)) {
            uint32_t slot_id = _sfetch_ring_dequeue(&chn.user_incoming);
            _sfetch_request_handler(chn.ctx, slot_id);
        }
    }

    /* drain the outgoing queue, prepare items for invoking the response
       callback, and finally call the response callback, free finished items
    */
    while (!_sfetch_ring_empty(&chn.user_outgoing)) {
        const uint32_t slot_id = _sfetch_ring_dequeue(&chn.user_outgoing);
        SOKOL_ASSERT(slot_id);
        _sfetch_item_t* item = _sfetch_pool_item_lookup(pool, slot_id);
        SOKOL_ASSERT(item && item.callback);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_INITIAL);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_ALLOCATED);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_DISPATCHED);
        SOKOL_ASSERT(item.state != _sfetch_state_t._SFETCH_STATE_FETCHED);
        /* transfer output params from thread- to user-data */
        item.user.fetched_offset = item.thread.fetched_offset;
        item.user.fetched_size = item.thread.fetched_size;
        if (item.user.cancel) {
            item.user.error_code = sfetch_error_t.SFETCH_ERROR_CANCELLED;
        }
        else {
            item.user.error_code = item.thread.error_code;
        }
        if (item.thread.finished) {
            item.user.finished = true;
        }
        /* state transition */
        if (item.thread.failed) {
            item.state = _sfetch_state_t._SFETCH_STATE_FAILED;
        }
        else if (item.state == _sfetch_state_t._SFETCH_STATE_FETCHING) {
            item.state = _sfetch_state_t._SFETCH_STATE_FETCHED;
        }
        _sfetch_invoke_response_callback(item);

        /* when the request is finish, free the lane for another request,
           otherwise feed it back into the incoming queue
        */
        if (item.user.finished) {
            _sfetch_ring_enqueue(&chn.free_lanes, item.lane);
            _sfetch_pool_item_free(pool, slot_id);
        }
        else {
            _sfetch_ring_enqueue(&chn.user_incoming, slot_id);
        }
    }
}

/*=== private high-level functions ===========================================*/
bool _sfetch_validate_request(_sfetch_t* ctx, const (sfetch_request_t)* req) {
    version(SOKOL_DEBUG)
    {
        if (req.channel >= ctx.desc.num_channels) {
            SOKOL_LOG("_sfetch_validate_request: request.channel too big!");
            return false;
        }
        if (!req.path) {
            SOKOL_LOG("_sfetch_validate_request: request.path is null!");
            return false;
        }
        if (strlen(req.path) >= (SFETCH_MAX_PATH-1)) {
            SOKOL_LOG("_sfetch_validate_request: request.path is too long (must be < SFETCH_MAX_PATH-1)");
            return false;
        }
        if (!req.callback) {
            SOKOL_LOG("_sfetch_validate_request: request.callback missing");
            return false;
        }
        if (req.chunk_size > req.buffer_size) {
            SOKOL_LOG("_sfetch_validate_request: request.chunk_size is greater request.buffer_size)");
            return false;
        }
        if (req.user_data_ptr && (req.user_data_size == 0)) {
            SOKOL_LOG("_sfetch_validate_request: request.user_data_ptr is set, but request.user_data_size is null");
            return false;
        }
        if (!req.user_data_ptr && (req.user_data_size > 0)) {
            SOKOL_LOG("_sfetch_validate_request: request.user_data_ptr is null, but request.user_data_size is not");
            return false;
        }
        if (req.user_data_size > SFETCH_MAX_USERDATA_UINT64 * (uint64_t.sizeof)) {
            SOKOL_LOG("_sfetch_validate_request: request.user_data_size is too big (see SFETCH_MAX_USERDATA_UINT64");
            return false;
        }
    }
    else
    {
        /* silence unused warnings in release*/
        //(void)(ctx && req);
    }
    return true;
}

/*=== PUBLIC API FUNCTIONS ===================================================*/
void sfetch_setup(const (sfetch_desc_t)* desc) {
    SOKOL_ASSERT(desc);
    SOKOL_ASSERT((desc._start_canary == 0) && (desc._end_canary == 0));
    SOKOL_ASSERT(null == _sfetch);
    _sfetch = cast(_sfetch_t*) SOKOL_MALLOC((_sfetch_t.sizeof));
    SOKOL_ASSERT(_sfetch);
    memset(_sfetch, 0, (_sfetch_t.sizeof));
    _sfetch_t* ctx = _sfetch_ctx();
    ctx.desc = *desc;
    ctx.setup = true;
    ctx.valid = true;

    /* replace zero-init items with default values */
    ctx.desc.max_requests = _sfetch_def(ctx.desc.max_requests, 128);
    ctx.desc.num_channels = _sfetch_def(ctx.desc.num_channels, 1);
    ctx.desc.num_lanes = _sfetch_def(ctx.desc.num_lanes, 1);
    if (ctx.desc.num_channels > SFETCH_MAX_CHANNELS) {
        ctx.desc.num_channels = SFETCH_MAX_CHANNELS;
        SOKOL_LOG("sfetch_setup: clamping num_channels to SFETCH_MAX_CHANNELS");
    }

    /* setup the global request item pool */
    ctx.valid &= _sfetch_pool_init(&ctx.pool, ctx.desc.max_requests);

    /* setup IO channels (one thread per channel) */
    for (uint32_t i = 0; i < ctx.desc.num_channels; i++) {
        bool ok = _sfetch_channel_init(&ctx.chn[i], ctx, ctx.desc.max_requests, ctx.desc.num_lanes, &_sfetch_request_handler);
        ctx.valid &= ok; 
    }
}

void sfetch_shutdown() {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.setup);
    ctx.valid = false;
    /* IO threads must be shutdown first */
    for (uint32_t i = 0; i < ctx.desc.num_channels; i++) {
        if (ctx.chn[i].valid) {
            _sfetch_channel_discard(&ctx.chn[i]);
        }
    }
    _sfetch_pool_discard(&ctx.pool);
    ctx.setup = false;
    SOKOL_FREE(ctx);
    _sfetch = null;
}

bool sfetch_valid() {
    _sfetch_t* ctx = _sfetch_ctx();
    return ctx && ctx.valid;
}

sfetch_desc_t sfetch_desc() {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    return ctx.desc;
}

int sfetch_max_userdata_bytes() {
    return SFETCH_MAX_USERDATA_UINT64 * 8;
}

int sfetch_max_path() {
    return SFETCH_MAX_PATH;
}

bool sfetch_handle_valid(sfetch_handle_t h) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    /* shortcut invalid handle */
    if (h.id == 0) {
        return false;
    }
    return null != _sfetch_pool_item_lookup(&ctx.pool, h.id);
}

sfetch_handle_t sfetch_send(const (sfetch_request_t)* request) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.setup);
    SOKOL_ASSERT(request && (request._start_canary == 0) && (request._end_canary == 0));

    const sfetch_handle_t invalid_handle = _sfetch_make_handle(0);
    if (!ctx.valid) {
        return invalid_handle;
    }
    if (!_sfetch_validate_request(ctx, request)) {
        return invalid_handle;
    }
    SOKOL_ASSERT(request.channel < ctx.desc.num_channels);

    uint32_t slot_id = _sfetch_pool_item_alloc(&ctx.pool, request);
    if (0 == slot_id) {
        SOKOL_LOG("sfetch_send: request pool exhausted (too many active requests)");
        return invalid_handle;
    }
    if (!_sfetch_channel_send(&ctx.chn[request.channel], slot_id)) {
        /* send failed because the channels sent-queue overflowed */
        _sfetch_pool_item_free(&ctx.pool, slot_id);
        return invalid_handle;
    }
    return _sfetch_make_handle(slot_id);
}

void sfetch_dowork() {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.setup);
    if (!ctx.valid) {
        return;
    }
    /* we're pumping each channel 2x so that unfinished request items coming out the
       IO threads can be moved back into the IO-thread immediately without
       having to wait a frame
     */
    ctx.in_callback = true;
    for (int pass = 0; pass < 2; pass++) {
        for (uint32_t chn_index = 0; chn_index < ctx.desc.num_channels; chn_index++) {
            _sfetch_channel_dowork(&ctx.chn[chn_index], &ctx.pool);
        }
    }
    ctx.in_callback = false;
}

void sfetch_bind_buffer(sfetch_handle_t h, void* buffer_ptr, uint32_t buffer_size) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    SOKOL_ASSERT(ctx.in_callback);
    _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, h.id);
    if (item) {
        SOKOL_ASSERT((null == item.buffer.ptr) && (0 == item.buffer.size));
        item.buffer.ptr = cast(uint8_t*) buffer_ptr;
        item.buffer.size = buffer_size;
    }
}

void* sfetch_unbind_buffer(sfetch_handle_t h) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    SOKOL_ASSERT(ctx.in_callback);
    _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, h.id);
    if (item) {
        void* prev_buf_ptr = item.buffer.ptr;
        item.buffer.ptr = null;
        item.buffer.size = 0;
        return prev_buf_ptr;
    }
    else {
        return null;
    }
}

void sfetch_pause(sfetch_handle_t h) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, h.id);
    if (item) {
        item.user.pause = true;
        item.user.cont = false;
    }
}

void sfetch_continue(sfetch_handle_t h) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, h.id);
    if (item) {
        item.user.cont = true;
        item.user.pause = false;
    }
}

void sfetch_cancel(sfetch_handle_t h) {
    _sfetch_t* ctx = _sfetch_ctx();
    SOKOL_ASSERT(ctx && ctx.valid);
    _sfetch_item_t* item = _sfetch_pool_item_lookup(&ctx.pool, h.id);
    if (item) {
        item.user.cont = false;
        item.user.pause = false;
        item.user.cancel = true;
    }
}




version(TEST)
{
    version = SOKOL_DEBUG;
    enum MAX_FILE_SIZE = (10 * 1024 * 1024);

    uint8_t[MAX_FILE_SIZE] buf;

    void main()
    {
        sfetch_desc_t desc;
        desc.max_requests = 1;
        desc.num_channels = 1;
        desc.num_lanes = 1;
        sfetch_setup(&desc);

        sfetch_request_t req;
        req.path = "test.txt";
        req.callback = &load_callback;
        req.buffer_ptr = buf.ptr;
        req.buffer_size = buf.length;
        sfetch_send(&req);

        while(true)
        {
            sfetch_dowork();
        }
        
        sfetch_shutdown();
    }

    void load_callback(const (sfetch_response_t) * response)
    {
        if (response.fetched)
        {
            printf("fetched!\n");

        }
        else if (response.failed)
        {
            printf("error\n");
        }
    }
}