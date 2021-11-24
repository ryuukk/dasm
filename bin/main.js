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
        _d_assert_msg: (msg, file, line) => {
            ABORT = true;
            console.error("-- D_ASSERT_MSG");
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