(function (MOD) {
    'use strict';
    MOD.libraries.push({
        name: 'print',

        import: (imports) => {

            var GLcounter = 1;
            var GLbuffers = [];
            var GLprograms = [];
            var GLframebuffers = [];
            var GLtextures = [];
            var GLuniforms = [];
            var GLshaders = [];
            var GLprogramInfos = {};
            var GLMINI_TEMP_BUFFER_SIZE = 256;
            var GLminiTempBuffer = null;
            var GLminiTempBufferViews = [0];
            
            GLminiTempBuffer = new Float32Array(GLMINI_TEMP_BUFFER_SIZE);
            for (var i = 0; i < GLMINI_TEMP_BUFFER_SIZE; i++) GLminiTempBufferViews[i] = GLminiTempBuffer.subarray(0, i+1);
            
            function ReadHeapString(ptr, length)
            {
                if (length === 0 || !ptr) return '';
                for (var hasUtf = 0, t, i = 0; !length || i != length; i++)
                {
                    t = MOD.HEAPU8[((ptr)+(i))>>0];
                    if (t == 0 && !length) break;
                    hasUtf |= t;
                }
                if (!length) length = i;
                if (hasUtf & 128)
                {
                    for(var r=MOD.HEAPU8,o=ptr,p=ptr+length,F=String.fromCharCode,e,f,i,n,C,t,a,g='';;)
                    {
                        if(o==p||(e=r[o++],!e)) return g;
                        128&e?(f=63&r[o++],192!=(224&e)?(i=63&r[o++],224==(240&e)?e=(15&e)<<12|f<<6|i:(n=63&r[o++],240==(248&e)?e=(7&e)<<18|f<<12|i<<6|n:(C=63&r[o++],248==(252&e)?e=(3&e)<<24|f<<18|i<<12|n<<6|C:(t=63&r[o++],e=(1&e)<<30|f<<24|i<<18|n<<12|C<<6|t))),65536>e?g+=F(e):(a=e-65536,g+=F(55296|a>>10,56320|1023&a))):g+=F((31&e)<<6|f)):g+=F(e);
                    }
                }
                // split up into chunks, because .apply on a huge string can overflow the stack
                for (var ret = '', curr; length > 0; ptr += 1024, length -= 1024)
                    ret += String.fromCharCode.apply(String, MOD.HEAPU8.slice(ptr, ptr + Math.min(length, 1024)));
                return ret;
            }
            function getNewId(table)
            {
                var ret = GLcounter++;
                for (var i = table.length; i < ret; i++) table[i] = null;
                return ret;
            }
            function getSource(shader, count, string, length)
            {
                var source = '';
                for (var i = 0; i < count; ++i)
                {
                    var frag;
                    if (length)
                    {
                        var len = MOD.HEAP32[(((length)+(i*4))>>2)];
                        if (len < 0) frag = ReadHeapString(MOD.HEAP32[(((string)+(i*4))>>2)]);
                        else frag = ReadHeapString(MOD.HEAP32[(((string)+(i*4))>>2)], len);
                    }
                    else frag = ReadHeapString(MOD.HEAP32[(((string)+(i*4))>>2)]);
                    source += frag;
                }
                return source;
            }
            function populateUniformTable(program)
            {
                var p = GLprograms[program];
                GLprogramInfos[program] =
                {
                    uniforms: {},
                    maxUniformLength: 0, // This is eagerly computed below, since we already enumerate all uniforms anyway.
                    maxAttributeLength: -1, // This is lazily computed and cached, computed when/if first asked, '-1' meaning not computed yet.
                    maxUniformBlockNameLength: -1 // Lazily computed as well
                };
        
                var ptable = GLprogramInfos[program];
                var utable = ptable.uniforms;
        
                // A program's uniform table maps the string name of an uniform to an integer location of that uniform.
                // The global GLuniforms map maps integer locations to WebGLUniformLocations.
                var numUniforms = MOD.WGL.getProgramParameter(p, MOD.WGL.ACTIVE_UNIFORMS);
                for (var i = 0; i < numUniforms; ++i)
                {
                    var u = MOD.WGL.getActiveUniform(p, i);
        
                    var name = u.name;
                    ptable.maxUniformLength = Math.max(ptable.maxUniformLength, name.length+1);
        
                    // Strip off any trailing array specifier we might have got, e.g. '[0]'.
                    if (name.indexOf(']', name.length-1) !== -1)
                    {
                        var ls = name.lastIndexOf('[');
                        name = name.slice(0, ls);
                    }
        
                    // Optimize memory usage slightly: If we have an array of uniforms, e.g. 'vec3 colors[3];', then
                    // only store the string 'colors' in utable, and 'colors[0]', 'colors[1]' and 'colors[2]' will be parsed as 'colors'+i.
                    // Note that for the GLuniforms table, we still need to fetch the all WebGLUniformLocations for all the indices.
                    var loc = MOD.WGL.getUniformLocation(p, name);
                    if (loc != null)
                    {
                        var id = getNewId(GLuniforms);
                        utable[name] = [u.size, id];
                        GLuniforms[id] = loc;
        
                        for (var j = 1; j < u.size; ++j)
                        {
                            var n = name + '['+j+']';
                            loc = MOD.WGL.getUniformLocation(p, n);
                            id = getNewId(GLuniforms);
        
                            GLuniforms[id] = loc;
                        }
                    }
                }
            }

            imports.glViewport = (x0, x1, x2, x3) => { MOD.WGL.viewport(x0, x1, x2, x3); };
            imports.glClear = (x0) => { MOD.WGL.clear(x0); };
            imports.glClearColor = (x0, x1, x2, x3) => { MOD.WGL.clearColor(x0, x1, x2, x3); };
            imports.glColorMask = (red, green, blue, alpha) => { MOD.WGL.colorMask(!!red, !!green, !!blue, !!alpha); };
        

            imports.glCreateProgram = function () {
                var id = getNewId(GLprograms);
                var program = MOD.WGL.createProgram();
                program.name = id;
                GLprograms[id] = program;
                return id;
            };
            imports.glGetAttribLocation = function (program, name) {
                program = GLprograms[program];
                name = ReadHeapString(name);
                return MOD.WGL.getAttribLocation(program, name);
            };

            imports.glGetUniformLocation = function(program, name)
            {
                name = ReadHeapString(name);
        
                var arrayOffset = 0;
                if (name.indexOf(']', name.length-1) !== -1)
                {
                    // If user passed an array accessor "[index]", parse the array index off the accessor.
                    var ls = name.lastIndexOf('[');
                    var arrayIndex = name.slice(ls+1, -1);
                    if (arrayIndex.length > 0)
                    {
                        arrayOffset = parseInt(arrayIndex);
                        if (arrayOffset < 0) return -1;
                    }
                    name = name.slice(0, ls);
                }

                var ptable = GLprogramInfos[program];
                if (!ptable) return -1;
                var utable = ptable.uniforms;
                var uniformInfo = utable[name]; // returns pair [ dimension_of_uniform_array, uniform_location ]
                if (uniformInfo && arrayOffset < uniformInfo[0])
                {
                    // Check if user asked for an out-of-bounds element, i.e. for 'vec4 colors[3];' user could ask for 'colors[10]' which should return -1.
                    return uniformInfo[1] + arrayOffset;
                }
                return -1;
            };

            imports.glCreateShader = function(shaderType)
            {
                var id = getNewId(GLshaders);
                GLshaders[id] = MOD.WGL.createShader(shaderType);
                return id;
            };

            imports.glShaderSource = function(shader, count, string, length)
            {
                var source = getSource(shader, count, string, length);
                MOD.WGL.shaderSource(GLshaders[shader], source);
            };

            imports.glCompileShader = function(shader) { MOD.WGL.compileShader(GLshaders[shader]); };
            imports.glAttachShader = function(program, shader) { MOD.WGL.attachShader(GLprograms[program], GLshaders[shader]); };
            imports.glLinkProgram = function(program)
            {
                MOD.WGL.linkProgram(GLprograms[program]);
                GLprogramInfos[program] = null; // uniforms no longer keep the same names after linking
                populateUniformTable(program);
            };
            imports.glUseProgram = function(program) { MOD.WGL.useProgram(program ? GLprograms[program] : null); };
            imports.glBindBuffer = function(target, buffer) { MOD.WGL.bindBuffer(target, buffer ? GLbuffers[buffer] : null); };
            imports.glEnableVertexAttribArray = function(index) { MOD.WGL.enableVertexAttribArray(index); };
            imports.glVertexAttribPointer = function(index, size, type, normalized, stride, ptr) { MOD.WGL.vertexAttribPointer(index, size, type, !!normalized, stride, ptr); };
            imports.glGenBuffers = function(n, buffers)
            {
                for (var i = 0; i < n; i++)
                {
                    var buffer = MOD.WGL.createBuffer();
                    if (!buffer)
                    {
                        GLrecordError(0x0502); // GL_INVALID_OPERATION
                        while(i < n) MOD.HEAP32[(((buffers)+(i++*4))>>2)]=0;
                        return;
                    }
                    var id = getNewId(GLbuffers);
                    buffer.name = id;
                    GLbuffers[id] = buffer;
                    MOD.HEAP32[(((buffers)+(i*4))>>2)]=id;
                }
            };

            
            imports.glUniformMatrix4fv = function(loc, count, transpose, value)
            {
                count<<=4;
                var view;
                if (count <= GLMINI_TEMP_BUFFER_SIZE)
                {
                    // avoid allocation when uploading few enough uniforms
                    view = GLminiTempBufferViews[count-1];
                    for (var ptr = value>>2, i = 0; i != count; i += 4)
                    {
                        view[i  ] = MOD.HEAPF32[ptr+i  ];
                        view[i+1] = MOD.HEAPF32[ptr+i+1];
                        view[i+2] = MOD.HEAPF32[ptr+i+2];
                        view[i+3] = MOD.HEAPF32[ptr+i+3];
                    }
                }
                else view = MOD.HEAPF32.slice((value)>>2,(value+count*4)>>2);
                MOD.WGL.uniformMatrix4fv(GLuniforms[loc], !!transpose, view);
            };

            imports.glBufferData = function(target, size, data, usage)
            {
                if (!data) MOD.WGL.bufferData(target, size, usage);
                else MOD.WGL.bufferData(target, MOD.HEAPU8.slice(data, data+size), usage);
            };

            imports.glDrawArrays = function(mode, first, count) { MOD.WGL.drawArrays(mode, first, count); };


            // move that to a math.js file
            
            // why that is needed? it should be intrinsics
            imports["llvm.cosf.f32"] = (value) => {
                return Math.cos(value);
            };
            imports["llvm.sinf.f32"] = (value) => {
                return Math.sin(value);
            };

            imports.cosf = (value) => {
                return Math.cos(value);
            };
            imports.sinf = (value) => {
                return Math.sin(value);
            };
            imports.sqrt = (value) => {
                return Math.sqrt(value);
            };
            imports.abs = (value) => {
                return Math.abs(value);
            };

        }
    });

})(MOD);