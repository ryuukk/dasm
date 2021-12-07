var string = (function () {
    'use strict';

    var string = {};
    var utf8Decoder = new TextDecoder('utf8');

    string.ptr2str = (buffer, ptr) => {
        var raw = new Uint8Array(buffer, ptr);
        var nul = raw.indexOf(0);
        if (nul !== -1) {
            return utf8Decoder.decode(raw.slice(0, nul));
        }
        return utf8Decoder.decode(raw);
    };
    string.ptr2str_len = (buffer, ptr, len) => {
        var raw = new Uint8Array(buffer, ptr);

        // TODO: check bounds
        return utf8Decoder.decode(raw.slice(0, len));
    };
    return string;
})();