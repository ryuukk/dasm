(function (MOD) {
    'use strict';

    MOD.libraries.push({
        name: 'print',
        import: (imports) => {
            var buffer = [];
            function printBuffered(str) {
                while (1) {
                    var nl = str.indexOf('\n');
                    if (nl !== -1) {
                        console.log(buffer.join('') + str.substring(0, nl));
                        buffer.length = 0;
                        str = str.substring(nl + 1);
                    } else {
                        buffer.push(str);
                        break;
                    }
                }
            }
            function padLeft(padding, str) {
                return (padding + str).slice(-padding.length);
            }
            imports.print_int = (i) => {
                printBuffered(i + '');
            };

            imports.print_long = (i) => {
                printBuffered(i + '');
            };

            imports.print_float = (f) => {
                printBuffered(f + '');
            };

            imports.print_double = (d) => {
                printBuffered(d + '');
            };

            imports.print_char = (c) => {
                printBuffered(String.fromCharCode(c));
            };

            imports.print_str = (ptr) => {
                printBuffered(string.ptr2str(MOD.memory.buffer, ptr));
            };

            imports.print_str_len = (ptr, len) => {
                printBuffered(string.ptr2str_len(MOD.memory.buffer, ptr, len));
            };

            imports.print_ptr = (ptr) => {
                if (ptr === 0) {
                    printBuffered('(null)');
                } else {
                    printBuffered('0x' + padLeft('00000000', ptr.toString(16)));
                }
            };
        }
    });
})(MOD);