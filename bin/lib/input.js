(function (MOD) {
    'use strict';
    MOD.libraries.push({
        name: 'input',
        canvas_init: (canvas) => {
            var keys = new Array();
            var RELEASE = 0;
            var PRESS_RPT = 1;
            function on_key_changed(keycode, status) {
                // TODO: implement repeat in D side
                // to mimic GLFW behavior
                var repeat = status && keys[keycode];
                keys[keycode] = status;

                if (status == PRESS_RPT) {
                    if (!repeat)
                        MOD.WA.exports.on_key_down(keycode);
                }
                else {
                    MOD.WA.exports.on_key_up(keycode);
                }
            }
            window.onkeyup = function (ev) {
                var code = ev.keyCode;
                on_key_changed(code, RELEASE);
            }
            window.onkeydown = function (ev) {
                var code = ev.keyCode;
                on_key_changed(code, PRESS_RPT);

                if (ev.keyCode === 8 /* backspace */ || ev.keyCode === 9 /* tab */) {
                    ev.preventDefault();
                }
            }
            window.onkeypress = function (ev) {
                if (ev.ctrlKey || ev.metaKey) return;

                var charCode = ev.charCode;
                if (charCode == 0 || (charCode >= 0x00 && charCode <= 0x1F)) return;

                MOD.WA.exports.on_key_press(charCode);
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
            canvas.addEventListener('wheel', (ev) => { }, true);
            canvas.addEventListener('mousewheel', (ev) => { }, true);
            canvas.addEventListener('mouseenter', (ev) => { }, true);
            canvas.addEventListener('mouseleave', (ev) => { }, true);
            canvas.addEventListener('drop', (ev) => { }, true);
            canvas.addEventListener('dragover', (ev) => { }, true);
        },
    });
})(MOD);