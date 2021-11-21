(function (MOD) {
	'use strict';

    var WA;
    var WGL;
    var ABORT = false;
    var initTime;
    
    const memory = new WebAssembly.Memory({
        initial: 256,
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
            try { WGL = canvas.getContext('webgl', attr) || canvas.getContext('experimental-webgl', attr); }
            finally { canvas.removeEventListener('webglcontextcreationerror', onContextCreationError, false); }
            if (!WGL) throw 'Could not create context';
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
              WA.exports.WA_render(); 
        };
        
        window.requestAnimationFrame(draw_func_ex);
    };

    // Export a custom GetTime function that returns milliseconds since startup
    env.WAJS_get_time = () => { return Date.now(); };
    env.WAJS_get_elapsed_time = () => { return Date.now() - initTime; };
    
    // wgl
    env.glViewport = (x0, x1, x2, x3) => { WGL.viewport(x0, x1, x2, x3); };
    env.glClear = (x0) => { WGL.clear(x0); };
    env.glClearColor = (x0, x1, x2, x3) => { WGL.clearColor(x0, x1, x2, x3); };
    env.glColorMask = (red, green, blue, alpha) => { WGL.colorMask(!!red, !!green, !!blue, !!alpha); };

    const importObject = {
        env: env,
    };

    WebAssembly.instantiateStreaming(fetch("./game.wasm"), importObject)
        .then(result => {

            console.log('JS: Loaded wasm file');

            
            WA = result.instance;

            MOD.memory = result.instance.exports.memory;

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
        });

})(MOD);