
//          Copyright 2019 - 2021 Michael D. Parker
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module freetype.bind.ftlzw;

import freetype.config;
import freetype.bind.ftsystem,
       freetype.bind.fttypes;

static if(staticBinding) {
	extern(C) @nogc nothrow {
        FT_Error FT_Stream_OpenLZW(FT_Stream stream, FT_Stream source);
    }
}
else {
    extern(C) @nogc nothrow {
        alias pFT_Stream_OpenLZW = FT_Error function(FT_Stream stream, FT_Stream source);
    }

    __gshared {
        pFT_Stream_OpenLZW FT_Stream_OpenLZW;
    }
}