(function (MOD) {
	'use strict';

    var ABORT = false;
    var initTime;
    
    const memory = new WebAssembly.Memory({
        initial: 1024,
        maximum: 4096,
    });

    var env = 
    {
        memory: memory,

        OVERFLOW_MEMCPY: () => {
            throw Error("memcpy overflow!");
        },

        OVERFLOW_MEMSET: () => {
            throw Error("memset overflow!");
        },

        abort: () => {
            ABORT = true;
            console.error("-- ABORT --");
        },
        __assert: () => {
            ABORT = true;
            console.error("-- ASSERT --");
        },
        _d_assert: (file,line) => {
            ABORT = true;
            console.error("-- D_ASSERT --");
        },
        _d_assert_msg: (msgL, msg, fileL, file, line) => {
            ABORT = true;
            console.error("-- D_ASSERT_MSG");
            var m = string.ptr2str_len(MOD.memory, msg, msgL);
            var f = string.ptr2str_len(MOD.memory, file, fileL);
            console.error(f+":"+line+" "+ m);
        },
        update_memory_view: () => {
            var memory = MOD.WA.exports.memory;
            MOD.memory = memory;
            MOD.HEAP8 = new Int8Array(memory.buffer);
            MOD.HEAPU8 = new Uint8Array(memory.buffer);
            MOD.HEAP16 = new Int16Array(memory.buffer);
            MOD.HEAPU16 = new Uint16Array(memory.buffer);
            MOD.HEAP32 = new Uint32Array(memory.buffer);
            MOD.HEAPU32 = new Uint32Array(memory.buffer);
            MOD.HEAPF32 = new Float32Array(memory.buffer);
            MOD.HEAPF64 = new Float64Array(memory.buffer);
        },

        // string: len, offset
        // ctx + func: cb

        load_file_async: (len, offset, id, ctx, func) => {
            var path = string.ptr2str_len(MOD.memory.buffer, offset, len);
            var req = new XMLHttpRequest();
            req.open("GET", path, true);
            req.responseType = "arraybuffer";

            req.onload = function (evt) {
                var arrayBuffer = req.response; // Note: not req.responseText
                if (arrayBuffer) 
                {
                    var byteArray = new Uint8Array(arrayBuffer);
                    var fileSize = byteArray.byteLength;
                    
                    // alloc on D side
                    var ptr = MOD.WA.exports.malloc(fileSize);
                    
                    // copy file content to our buffer
                    MOD.HEAP8.set(byteArray, ptr);

                    // notify D side
                    MOD.WA.exports.js_cb_load_file(ctx,func, id, ptr, fileSize, true);
                }
            };

            req.onerror = function(evt) {
                MOD.WA.exports.js_cb_load_file(ctx, func, id, 0, 0, false);
                console.log('ERROR: Unnable to load file : ' + path + ' ' + evt.type);
            };

            req.send(null);
        },

        WAJS_sleep: function(ms) {
        },
    };

    // feed modules
    for (var i = 0; i < MOD.libraries.length; i++) {
        var lib = MOD.libraries[i];
        if (lib.import) {
            lib.import(env);
        }
    }

    var WGL_init_context = (canvas, attr) =>
    {
        var attr = { majorVersion: 3, minorVersion: 0, antialias: false, alpha: false };
        var errorInfo = '';
        try
        {
            let onContextCreationError = (event) => { errorInfo = event.statusMessage || errorInfo; };
            canvas.addEventListener('webglcontextcreationerror', onContextCreationError, false);
            try { MOD.WGL = canvas.getContext('webgl2', attr); }
            finally { canvas.removeEventListener('webglcontextcreationerror', onContextCreationError, false); }
            if (!MOD.WGL) throw 'Could not create context';
            else console.log("JS: WGL ok");
        }
        catch (e) { abort('WEBGL', e + (errorInfo ? ' (' + errorInfo + ')' : '')); }
        return true;
    }

    // This sets up the canvas for GL rendering
    env.WAJS_setup_canvas = (width, height) =>
    {
        // Get the canvas and set its size as requested by the wasm module
        var canvas = document.getElementById("wgl_canvas");
        canvas.addEventListener("contextmenu", (event) => { event.preventDefault(); });
        canvas.setAttribute("width", width);
        canvas.setAttribute("height", height);
        canvas.setAttribute("title", "MyCanvas");

        // Set up the WebGL context for our OpenGL 2.0 emulation
        if (!WGL_init_context(canvas)) return;


        for (var i = 0; i < MOD.libraries.length; i++) {
            var lib = MOD.libraries[i];
            if (lib.canvas_init) {
                lib.canvas_init(canvas);
            }
        }

        console.log("JS: Canvas setup to: " + width +":"+height);
        var sts = document.getElementById("wa_status");
        sts.textContent = "Status: Loaded";

        // Store the startup time
        initTime = Date.now();

        // Call the exported WA_render function every frame (unless the program crashes and aborts)
        var draw_func_ex = () => {
             if (ABORT) return;
              window.requestAnimationFrame(draw_func_ex);

              // TODO: remove try catch on release build
              try {
                MOD.WA.exports.WA_render(); 
              } catch (error) {
                  ABORT = true;
                  var sts = document.getElementById("wa_status");
                  sts.textContent = "Status: Errpr";
                  console.error("error bro: ", error);
              }
        };
        
        window.requestAnimationFrame(draw_func_ex);

        
    };

    // Export a custom GetTime function that returns milliseconds since startup

    env.WAJS_ticks = () => { return window.performance.now(); };
    env.WAJS_get_time = () => { return Date.now(); };
    env.WAJS_get_elapsed_time = () => { return Date.now() - initTime; };
    
    const importObject = {
        env: env,
    };

    WebAssembly.instantiateStreaming(fetch("game.wasm",{ credentials: "same-origin" }), importObject)
        .then(result => {

            console.log('JS: Loaded wasm file');

            let memory = result.instance.exports.memory;

            MOD.WA = result.instance;
            MOD.memory = memory;
            MOD.HEAP8 = new Int8Array(memory.buffer);
            MOD.HEAPU8 = new Uint8Array(memory.buffer);
            MOD.HEAP16 = new Int16Array(memory.buffer);
            MOD.HEAPU16 = new Uint16Array(memory.buffer);
            MOD.HEAP32 = new Uint32Array(memory.buffer);
            MOD.HEAPU32 = new Uint32Array(memory.buffer);
            MOD.HEAPF32 = new Float32Array(memory.buffer);
            MOD.HEAPF64 = new Float64Array(memory.buffer);

            const { exports } = result.instance;



            // init modules
            for (var i = 0; i < MOD.libraries.length; i++) {
                var lib = MOD.libraries[i];
                if (lib.init) {
                    lib.init(instance);
                }
            }

            // call _start

            console.log("JS: caling _start, __heap_base:", result.instance.exports.__heap_base);
            exports._start(result.instance.exports.__heap_base);
        })
        .catch(error=>{
          console.error('there was some error; ', error)
          ABORT = true;
        });

})(MOD);