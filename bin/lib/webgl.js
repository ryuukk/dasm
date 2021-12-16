(function (MOD) {
    'use strict';
    MOD.libraries.push({
        name: 'webgl',

        import: (imports) => {

            var GLcounter = 1;
            var GLbuffers = [];
            var GLvaos = [];
            var GLprograms = [];
            var GLframebuffers = [];
            var GLtextures = [];
            var GLuniforms = [];
            var GLshaders = [];
            var GLprogramInfos = {};
            var GLpackAlignment = 4;
            var GLunpackAlignment = 4;
            var GLMINI_TEMP_BUFFER_SIZE = 256;
            var GLminiTempBuffer = null;
            var GLminiTempBufferViews = [0];
            var GLlastError;
            
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
                    ret += String.fromCharCode.apply(String, MOD.HEAPU8.subarray(ptr, ptr + Math.min(length, 1024)));
                return ret;
            }
            function WriteHeapString(str, ptr, max_length)
            {
                for (var e=str,r=MOD.HEAPU8,f=ptr,i=(max_length?max_length:MOD.HEAPU8.length),a=f,t=f+i-1,b=0;b<e.length;++b)
                {
                    var k=e.charCodeAt(b);
                    if(55296<=k&&k<=57343&&(k=65536+((1023&k)<<10)|1023&e.charCodeAt(++b)),k<=127){if(t<=f)break;r[f++]=k;}
                    else if(k<=2047){if(t<=f+1)break;r[f++]=192|k>>6,r[f++]=128|63&k;}
                    else if(k<=65535){if(t<=f+2)break;r[f++]=224|k>>12,r[f++]=128|k>>6&63,r[f++]=128|63&k;}
                    else if(k<=2097151){if(t<=f+3)break;r[f++]=240|k>>18,r[f++]=128|k>>12&63,r[f++]=128|k>>6&63,r[f++]=128|63&k;}
                    else if(k<=67108863){if(t<=f+4)break;r[f++]=248|k>>24,r[f++]=128|k>>18&63,r[f++]=128|k>>12&63,r[f++]=128|k>>6&63,r[f++]=128|63&k;}
                    else{if(t<=f+5)break;r[f++]=252|k>>30,r[f++]=128|k>>24&63,r[f++]=128|k>>18&63,r[f++]=128|k>>12&63,r[f++]=128|k>>6&63,r[f++]=128|63&k;}
                }
                return r[f]=0,f-a;
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
            
            function webGLGetTexPixelData(type, format, width, height, pixels, internalFormat)
            {
                var sizePerPixel;
                var numChannels;
                switch(format)
                {
                    case 0x1906: case 0x1909: case 0x1902: numChannels = 1; break; //GL_ALPHA, GL_LUMINANCE, GL_DEPTH_COMPONENT
                    case 0x190A: numChannels = 2; break; //GL_LUMINANCE_ALPHA
                    case 0x1907: case 0x8C40: numChannels = 3; break; //GL_RGB, GL_SRGB_EXT
                    case 0x1908: case 0x8C42: numChannels = 4; break; //GL_RGBA, GL_SRGB_ALPHA_EXT
                    default: GLrecordError(0x0500); return null; //GL_INVALID_ENUM
                }
                switch (type)
                {
                    case 0x1401: sizePerPixel = numChannels*1; break; //GL_UNSIGNED_BYTE
                    case 0x1403: case 0x8D61: sizePerPixel = numChannels*2; break; //GL_UNSIGNED_SHORT, GL_HALF_FLOAT_OES
                    case 0x1405: case 0x1406: sizePerPixel = numChannels*4; break; //GL_UNSIGNED_INT, GL_FLOAT
                    case 0x84FA: sizePerPixel = 4; break; //GL_UNSIGNED_INT_24_8_WEBGL/GL_UNSIGNED_INT_24_8
                    case 0x8363: case 0x8033: case 0x8034: sizePerPixel = 2; break; //GL_UNSIGNED_SHORT_5_6_5, GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1
                    default: GLrecordError(0x0500); return null; //GL_INVALID_ENUM
                }

                function roundedToNextMultipleOf(x, y) { return Math.floor((x + y - 1) / y) * y; }
                var plainRowSize = width * sizePerPixel;
                var alignedRowSize = roundedToNextMultipleOf(plainRowSize, GLunpackAlignment);
                var bytes = (height <= 0 ? 0 : ((height - 1) * alignedRowSize + plainRowSize));

                switch(type)
                {
                    case 0x1401: return MOD.HEAPU8.subarray((pixels),(pixels+bytes)); //GL_UNSIGNED_BYTE
                    case 0x1406: return MOD.HEAPF32.subarray((pixels)>>2,(pixels+bytes)>>2); //GL_FLOAT
                    case 0x1405: case 0x84FA: return MOD.HEAPU32.subarray((pixels)>>2,(pixels+bytes)>>2); //GL_UNSIGNED_INT, GL_UNSIGNED_INT_24_8_WEBGL/GL_UNSIGNED_INT_24_8
                    case 0x1403: case 0x8363: case 0x8033: case 0x8034: case 0x8D61: return MOD.HEAPU16.subarray((pixels)>>1,(pixels+bytes)>>1); //GL_UNSIGNED_SHORT, GL_UNSIGNED_SHORT_5_6_5, GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1, GL_HALF_FLOAT_OES
                    default: GLrecordError(0x0500); return null; //GL_INVALID_ENUM
                }
            }
            function GLrecordError(err)
            {
                if (!GLlastError)
                {
                    GLlastError = err;
                    console.error("gl error:", err);
                }
            }
            imports.glGetError = function()
            {
                if (GLlastError)
                {
                    var e = GLlastError;
                    GLlastError = 0;
                    return e;
                }
                return MOD.WGL.getError();
            };
            imports.glEnable = function(x0) { MOD.WGL.enable(x0); };
            imports.glDisable = function(x0) { MOD.WGL.disable(x0); };
            imports.glViewport = (x0, x1, x2, x3) => { MOD.WGL.viewport(x0, x1, x2, x3); };
            imports.glClear = (x0) => { MOD.WGL.clear(x0); };
            imports.glClearColor = (x0, x1, x2, x3) => { MOD.WGL.clearColor(x0, x1, x2, x3); };
            imports.glColorMask = (red, green, blue, alpha) => { MOD.WGL.colorMask(!!red, !!green, !!blue, !!alpha); };
        

            imports.glFrontFace = function(mode) { MOD.WGL.frontFace(mode); };
            imports.glCullFace = function(mode) { MOD.WGL.cullFace(mode); };
            imports.glScissor = function(x0, x1, x2, x3) { MOD.WGL.scissor(x0, x1, x2, x3); };
            imports.glCreateProgram = function () {
                var id = getNewId(GLprograms);
                var program = MOD.WGL.createProgram();
                program.name = id;
                GLprograms[id] = program;
                return id;
            };
            imports.glDeleteShader = function(id)
            {
                if (!id) return;
                var shader = GLshaders[id];
                if (!shader)
                {
                    // glDeleteShader actually signals an error when deleting a nonexisting object, unlike some other GL delete functions.
                    GLrecordError(0x0501); // GL_INVALID_VALUE
                    return;
                }
                MOD.WGL.deleteShader(shader);
                GLshaders[id] = null;
            };

            imports.glDeleteProgram = function(id)
            {
                if (!id) return;
                var program = GLprograms[id];
                if (!program) 
                {
                    // glDeleteProgram actually signals an error when deleting a nonexisting object, unlike some other GL delete functions.
                    GLrecordError(0x0501); // GL_INVALID_VALUE
                    return;
                }
                MOD.WGL.deleteProgram(program);
                program.name = 0;
                GLprograms[id] = null;
                GLprogramInfos[id] = null;
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

            // TODO: double check support of VAO
            imports.glGenVertexArrays = function(n, buffers)
            {
                for (var i = 0; i < n; i++)
                {
                    // TODO: CHECK THIS
                    // should i really store it in the same glbuffers?
                    // should i really use getNewId?
                    var buffer = MOD.WGL.createVertexArray();
                    if (!buffer)
                    {
                        GLrecordError(0x0502); // GL_INVALID_OPERATION
                        while(i < n) MOD.HEAP32[(((buffers)+(i++*4))>>2)]=0;
                        return;
                    }
                    var id = getNewId(GLvaos);
                    buffer.name = id;
                    GLvaos[id] = buffer;
                    MOD.HEAP32[(((buffers)+(i*4))>>2)]=id;
                }
            };
            imports.glDeleteVertexArrays = function(n, buffers)
            {
                for (var i = 0; i < n; i++)
                {
                    var id = MOD.HEAP32[(((buffers)+(i*4))>>2)];
                    var buffer = GLvaos[id];
        
                    // From spec: "glDeleteBuffers silently ignores 0's and names that do not correspond to existing buffer objects."
                    if (!buffer) continue;
        
                    MOD.WGL.deleteVertexArray(buffer);
                    buffer.name = 0;
                    GLvaos[id] = null;
                }
            };
            imports.glBindVertexArray = function(target) { 
                var vao = GLvaos[target];
                MOD.WGL.bindVertexArray(vao);
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
                else view = MOD.HEAPF32.subarray((value)>>2,(value+count*4)>>2);
                MOD.WGL.uniformMatrix4fv(GLuniforms[loc], !!transpose, view);
            };

            imports.glUniform1f = function(loc, v0) { MOD.WGL.uniform1f(GLuniforms[loc], v0); };
            imports.glUniform1i = function(loc, v0) { MOD.WGL.uniform1i(GLuniforms[loc], v0); };
            imports.glUniform2f = function(loc, v0, v1) { MOD.WGL.uniform2f(GLuniforms[loc], v0, v1); };
            imports.glUniform3f = function(loc, v0, v1, v2) { MOD.WGL.uniform3f(GLuniforms[loc], v0, v1, v2); };
        
            imports.glUniform3fv = function(loc, count, value)
            {
                var view;
                if (3*count <= GLMINI_TEMP_BUFFER_SIZE)
                {
                    // avoid allocation when uploading few enough uniforms
                    view = GLminiTempBufferViews[3*count-1];
                    for (var ptr = value>>2, i = 0; i != 3*count; i++)
                    {
                        view[i] = MOD.HEAPF32[ptr+i];
                    }
                }
                else view = MOD.HEAPF32.subarray((value)>>2,(value+count*12)>>2);
                MOD.WGL.uniform3fv(GLuniforms[loc], view);
            };
        
            imports.glUniform4f = function(loc, v0, v1, v2, v3) { MOD.WGL.uniform4f(GLuniforms[loc], v0, v1, v2, v3); };
        

            imports.glBufferData = function(target, size, data, usage)
            {
                if (!data) MOD.WGL.bufferData(target, size, usage);
                else MOD.WGL.bufferData(target, MOD.HEAPU8.subarray(data, data+size), usage);
            };

            imports.glDrawArrays = function(mode, first, count) { MOD.WGL.drawArrays(mode, first, count); };
            imports.glGetShaderiv = function(shader, pname, p)
            {
                if (!p)
                {
                    // GLES2 specification does not specify how to behave if p is a null pointer. Since calling this function does not make sense
                    // if p == null, issue a GL error to notify user about it.
                    GLrecordError(0x0501); // GL_INVALID_VALUE
                    return;
                }
                if (pname == 0x8B84) // GL_INFO_LOG_LENGTH
                {
                    var log = MOD.WGL.getShaderInfoLog(GLshaders[shader]);
                    if (log === null) log = '(unknown error)';
                    MOD.HEAP32[((p)>>2)] = log.length + 1;
                }
                else if (pname == 0x8B88) // GL_SHADER_SOURCE_LENGTH
                {
                    var source = MOD.WGL.getShaderSource(GLshaders[shader]);
                    var sourceLength = (source === null || source.length == 0) ? 0 : source.length + 1;
                    MOD.HEAP32[((p)>>2)] = sourceLength;
                }
                else MOD.HEAP32[((p)>>2)] = MOD.WGL.getShaderParameter(GLshaders[shader], pname);
            };
        
            imports.glGetProgramInfoLog = function(program, maxLength, length, infoLog)
            {
                var log = MOD.WGL.getProgramInfoLog(GLprograms[program]);
                if (log === null) log = '(unknown error)';
                if (maxLength > 0 && infoLog)
                {
                    var numBytesWrittenExclNull = WriteHeapString(log, infoLog, maxLength);
                    if (length) MOD.HEAP32[((length)>>2)]=numBytesWrittenExclNull;
                }
                else if (length) MOD.HEAP32[((length)>>2)]=0;
            };

            
            imports.glGetProgramiv = function(program, pname, p)
            {
                if (!p)
                {
                    // GLES2 specification does not specify how to behave if p is a null pointer. Since calling this function does not make sense
                    // if p == null, issue a GL error to notify user about it.
                    GLrecordError(0x0501); // GL_INVALID_VALUE
                    return;
                }
        
                if (program >= GLcounter)
                {
                    GLrecordError(0x0501); // GL_INVALID_VALUE
                    return;
                }
        
                var ptable = GLprogramInfos[program];
                if (!ptable)
                {
                    GLrecordError(0x0502); //GL_INVALID_OPERATION
                    return;
                }
        
                if (pname == 0x8B84) // GL_INFO_LOG_LENGTH
                {
                    var log = MOD.WGL.getProgramInfoLog(GLprograms[program]);
                    if (log === null) log = '(unknown error)';
                    MOD.HEAP32[((p)>>2)] = log.length + 1;
                }
                else if (pname == 0x8B87) //GL_ACTIVE_UNIFORM_MAX_LENGTH
                {
                    MOD.HEAP32[((p)>>2)] = ptable.maxUniformLength;
                }
                else if (pname == 0x8B8A) //GL_ACTIVE_ATTRIBUTE_MAX_LENGTH
                {
                    if (ptable.maxAttributeLength == -1)
                    {
                        program = GLprograms[program];
                        var numAttribs = MOD.WGL.getProgramParameter(program, MOD.WGL.ACTIVE_ATTRIBUTES);
                        ptable.maxAttributeLength = 0; // Spec says if there are no active attribs, 0 must be returned.
                        for (var i = 0; i < numAttribs; ++i)
                        {
                            var activeAttrib = MOD.WGL.getActiveAttrib(program, i);
                            ptable.maxAttributeLength = Math.max(ptable.maxAttributeLength, activeAttrib.name.length+1);
                        }
                    }
                    MOD.HEAP32[((p)>>2)] = ptable.maxAttributeLength;
                }
                else if (pname == 0x8A35) //GL_ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH
                {
                    if (ptable.maxUniformBlockNameLength == -1)
                    {
                        program = GLprograms[program];
                        var numBlocks = MOD.WGL.getProgramParameter(program, MOD.WGL.ACTIVE_UNIFORM_BLOCKS);
                        ptable.maxUniformBlockNameLength = 0;
                        for (var i = 0; i < numBlocks; ++i)
                        {
                            var activeBlockName = MOD.WGL.getActiveUniformBlockName(program, i);
                            ptable.maxUniformBlockNameLength = Math.max(ptable.maxUniformBlockNameLength, activeBlockName.length+1);
                        }
                    }
                    MOD.HEAP32[((p)>>2)] = ptable.maxUniformBlockNameLength;
                }
                else
                {
                    MOD.HEAP32[((p)>>2)] = MOD.WGL.getProgramParameter(GLprograms[program], pname);
                }
            };
            imports.glGetActiveUniform = function(program, index, bufSize, length, size, type, name)
            {
                program = GLprograms[program];
                var info = MOD.WGL.getActiveUniform(program, index);
                if (!info) return; // If an error occurs, nothing will be written to length, size, type and name.
        
                if (bufSize > 0 && name)
                {
                    var numBytesWrittenExclNull = WriteHeapString(info.name, name, bufSize);
                    if (length) MOD.HEAP32[((length)>>2)]=numBytesWrittenExclNull;
                } else {
                    if (length) MOD.HEAP32[((length)>>2)]=0;
                }
        
                if (size) MOD.HEAP32[((size)>>2)]=info.size;
                if (type) MOD.HEAP32[((type)>>2)]=info.type;
            };
            imports.glGetActiveAttrib = function(program, index, bufSize, length, size, type, name)
            {
                program = GLprograms[program];
                var info = MOD.WGL.getActiveAttrib(program, index);
                if (!info) return; // If an error occurs, nothing will be written to length, size, type and name.
        
                if (bufSize > 0 && name)
                {
                    var numBytesWrittenExclNull = WriteHeapString(info.name, name, bufSize);
                    if (length) MOD.HEAP32[((length)>>2)]=numBytesWrittenExclNull;
                } else {
                    if (length) MOD.HEAP32[((length)>>2)]=0;
                }
        
                if (size) MOD.HEAP32[((size)>>2)]=info.size;
                if (type) MOD.HEAP32[((type)>>2)]=info.type;
            };

            imports.glGetShaderInfoLog = function(shader, maxLength, length, infoLog)
            {
                var log = MOD.WGL.getShaderInfoLog(GLshaders[shader]);
                if (log === null) log = '(unknown error)';
                if (maxLength > 0 && infoLog)
                {
                    var numBytesWrittenExclNull = WriteHeapString(log, infoLog, maxLength);
                    if (length) MOD.HEAP32[((length)>>2)] = numBytesWrittenExclNull;
                }
                else if (length) MOD.HEAP32[((length)>>2)] = 0;
            };
            
            imports.glDrawElements = function(mode, count, type, indices) { MOD.WGL.drawElements(mode, count, type, indices); };



            imports.glDeleteBuffers = function(n, buffers)
            {
                for (var i = 0; i < n; i++)
                {
                    var id = MOD.HEAP32[(((buffers)+(i*4))>>2)];
                    var buffer = GLbuffers[id];
        
                    // From spec: "glDeleteBuffers silently ignores 0's and names that do not correspond to existing buffer objects."
                    if (!buffer) continue;
        
                    MOD.WGL.deleteBuffer(buffer);
                    buffer.name = 0;
                    GLbuffers[id] = null;
                }
            };

            
            imports.glActiveTexture = function(x0) { MOD.WGL.activeTexture(x0); };
            imports.glDeleteTextures = function(n, textures)
            {
                for (var i = 0; i < n; i++)
                {
                    var id = MOD.HEAP32[(((textures)+(i*4))>>2)];
                    var texture = GLtextures[id];
                    if (!texture) continue; // GL spec: "glDeleteTextures silently ignores 0s and names that do not correspond to existing textures".
                    MOD.WGL.deleteTexture(texture);
                    texture.name = 0;
                    GLtextures[id] = null;
                }
            };


            imports.glPixelStorei = function(pname, param)
            {
                if (pname == 0x0D05) GLpackAlignment = param; //GL_PACK_ALIGNMENT
                else if (pname == 0x0cf5) GLunpackAlignment = param; //GL_UNPACK_ALIGNMENT
                MOD.WGL.pixelStorei(pname, param);
            };
        
            imports.glGenTextures = function(n, textures)
            {
                for (var i = 0; i < n; i++)
                {
                    var texture = MOD.WGL.createTexture();
                    if (!texture)
                    {
                        // GLES + EGL specs don't specify what should happen here, so best to issue an error and create IDs with 0.
                        GLrecordError(0x0502); // GL_INVALID_OPERATION
                        while(i < n) MOD.HEAP32[(((textures)+(i++*4))>>2)]=0;
                        return;
                    }
                    var id = getNewId(GLtextures);
                    texture.name = id;
                    GLtextures[id] = texture;
                    MOD.HEAP32[(((textures)+(i*4))>>2)]=id;
                }
            };

            imports.glTexImage2D = function(target, level, internalFormat, width, height, border, format, type, pixels)
            {
                var pixelData = null;
                if (pixels) pixelData = webGLGetTexPixelData(type, format, width, height, pixels, internalFormat);
                MOD.WGL.texImage2D(target, level, internalFormat, width, height, border, format, type, pixelData);
            };
			imports.glTexImage3D = (target, level, internalformat, width, height, depth, border, format, type, data) => {
                var pixelData = null;
                if (data) pixelData = webGLGetTexPixelData(type, format, width, height, data, internalformat);
                MOD.WGL.texImage3D(target, level, internalformat, width, height, depth, border, format, type, pixelData);
			};
            imports.glTexSubImage3D = (target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, data) => {
                var pixelData = null;
                if (data) pixelData = webGLGetTexPixelData(type, format, width, height, data, 0);

                //   gl.texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, GLintptr offset);

				MOD.WGL.texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pixelData);
			},
            imports.glTexParameteri = function(x0, x1, x2)
            {
                MOD.WGL.texParameteri(x0, x1, x2);
            };
        
            imports.glBindFramebuffer = function(target, framebuffer) { MOD.WGL.bindFramebuffer(target, framebuffer ? GLframebuffers[framebuffer] : null); };
            imports.glBindTexture = function(target, texture) { MOD.WGL.bindTexture(target, texture ? GLtextures[texture] : null); };
            imports.glDepthMask = function(flag) { MOD.WGL.depthMask(!!flag); };

            imports.glDepthFunc = function(x0) { MOD.WGL.depthFunc(x0); };

            imports.glDepthRange = function(zNear, zFar) { MOD.WGL.depthRange(zNear, zFar); };

            imports.glDisable = function(x0) { MOD.WGL.disable(x0); };
            
            imports.glBlendFunc = function(x0, x1) { MOD.WGL.blendFunc(x0, x1); };
            imports.glBlendFuncSeparate = function(x0, x1, x2, x3) { MOD.WGL.blendFuncSeparate(x0, x1, x2, x3); }
            imports.glBlendColor = function(x0, x1, x2, x3) { MOD.WGL.blendColor(x0, x1, x2, x3); }
            imports.glBlendEquation = function(x0) { MOD.WGL.blendEquation(x0); }
            imports.glBlendEquationSeparate = function(x0, x1) { MOD.WGL.blendEquationSeparate(x0, x1); }




            imports.glDeleteFramebuffers = function(n, framebuffers)
            {
                for (var i = 0; i < n; ++i)
                {
                    var id = MOD.HEAP32[(((framebuffers)+(i*4))>>2)];
                    var framebuffer = GLframebuffers[id];
                    if (!framebuffer) continue; // GL spec: "glDeleteFramebuffers silently ignores 0s and names that do not correspond to existing framebuffer objects".
                    MOD.WGL.deleteFramebuffer(framebuffer);
                    framebuffer.name = 0;
                    GLframebuffers[id] = null;
                }
            };
            imports.glFramebufferTexture2D = function(target, attachment, textarget, texture, level) 
            {
                const h = GLtextures[texture];
                MOD.WGL.framebufferTexture2D(target, attachment, textarget, h, level);
            };
            imports.glGenFramebuffers = function(n, ids)
            {
                for (var i = 0; i < n; ++i)
                {
                    var framebuffer = MOD.WGL.createFramebuffer();
                    if (!framebuffer)
                    {
                        GLrecordError(0x0502); // GL_INVALID_OPERATION
                        while(i < n) MOD.HEAP32[(((ids)+(i++*4))>>2)]=0;
                        return;
                    }
                    var id = getNewId(GLframebuffers);
                    framebuffer.name = id;
                    GLframebuffers[id] = framebuffer;
                    MOD.HEAP32[(((ids)+(i*4))>>2)] = id;
                }
            };

            imports.glDrawBuffer = function(buf)
            {
                MOD.WGL.drawBuffers([buf]);
            };

            imports.glCheckFramebufferStatus = function(target)
            {
                return MOD.WGL.checkFramebufferStatus(target);
            };

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
            imports.acosf = (value) => {
                return Math.acos(value);
            };

            imports.tanf = (value) => {
                return Math.tan(value);
            };
            
            imports.absf = (value) => {
                return Math.abs(value);
            };
            
            imports.roundf = (value) => {
                return Math.round(value);
            };
            
            imports.logf = (value) => {
                return Math.log(value);
            };

            imports.atan2f = (y, x) => {
                return Math.atan2(y, x);
            };
            
            imports.fmodf = (a, b) => {
                return a%b;
            };
        }
    });

})(MOD);