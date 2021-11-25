(function (MOD) {
	'use strict';

    var ABORT = false;
    var initTime;
    
    const memory = new WebAssembly.Memory({
        initial: 128,
        maximum: 512
    });
    const heap = new Uint8Array(memory.buffer);

    var env = 
    {
        memory: memory,

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
                    var mem = new Uint8Array(MOD.memory.buffer, ptr, arrayBuffer.length);
                    mem.set(byteArray);

                    // notify D side
                    MOD.WA.exports.js_cb_load_file(ctx,func, id, ptr, fileSize);
                }
            };

            req.onerror = function(evt) {
                MOD.WA.exports.js_cb_load_file(ctx, func, id, 0, 0);
                console.log('ERROR: Unnable to load file : ' + path + ' ' + evt.type);
            };

            req.send(null);
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
        var attr = { majorVersion: 1, minorVersion: 0, antialias: true, alpha: false };
        var errorInfo = '';
        try
        {
            let onContextCreationError = (event) => { errorInfo = event.statusMessage || errorInfo; };
            canvas.addEventListener('webglcontextcreationerror', onContextCreationError, false);
            try { MOD.WGL = canvas.getContext('webgl2', attr) || canvas.getContext('webgl', attr); }
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

        window.onkeyup = function(ev) 
        {
            var code = ev.keyCode;
            MOD.WA.exports.on_key_up(code);
        }
        window.onkeydown = function(ev) 
        {
            var code = ev.keyCode;
            MOD.WA.exports.on_key_down(code);

            if (ev.keyCode === 8 /* backspace */ || ev.keyCode === 9 /* tab */) {
                ev.preventDefault();
              }
        }
        canvas.addEventListener("touchmove", (ev) => {
            MOD.WA.exports.on_mouse_move(ev.offsetX, ev.offsetY);
        }, true);
        canvas.addEventListener("touchstart", (ev) => { 
            MOD.WA.exports.on_mouse_down(0);
        }, true);
        canvas.addEventListener("touchcancel", (ev) => {
            MOD.WA.exports.on_mouse_up(0);
        }, true);
        canvas.addEventListener("touchend", (ev) => { 
            MOD.WA.exports.on_mouse_up(0);
        }, true);
        canvas.addEventListener("mousemove", (ev) => { 
            MOD.WA.exports.on_mouse_move(ev.offsetX, ev.offsetY);
        }, true);
        canvas.addEventListener("mousedown", (ev) => { 
            MOD.WA.exports.on_mouse_down(ev.button);
        }, true);
        canvas.addEventListener("mouseup", (ev) => {
            MOD.WA.exports.on_mouse_up(ev.button);
        }, true);
        canvas.addEventListener('wheel', (ev) => {  }, true);
        canvas.addEventListener('mousewheel', (ev) => {  }, true);
        canvas.addEventListener('mouseenter', (ev) => { }, true);
        canvas.addEventListener('mouseleave', (ev) => { }, true);
        canvas.addEventListener('drop', (ev) => {  }, true);
        canvas.addEventListener('dragover', (ev) => {  }, true);

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
    env.WAJS_get_time = () => { return Date.now(); };
    env.WAJS_get_elapsed_time = () => { return Date.now() - initTime; };
    
    const importObject = {
        env: env,
    };

    WebAssembly.instantiateStreaming(fetch("./game.wasm",{ credentials: "same-origin" }), importObject)
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
            exports._start();
        })
        .catch(error=>{
          console.error('there was some error; ', error)
          ABORT = true;
        });

})(MOD);