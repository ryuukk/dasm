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
                        name = name.subarray(0, ls);
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
                    var arrayIndex = name.subarray(ls+1, -1);
                    if (arrayIndex.length > 0)
                    {
                        arrayOffset = parseInt(arrayIndex);
                        if (arrayOffset < 0) return -1;
                    }
                    name = name.subarray(0, ls);
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
                else view = MOD.HEAPF32.subarray((value)>>2,(value+count*4)>>2);
                MOD.WGL.uniformMatrix4fv(GLuniforms[loc], !!transpose, view);
            };

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
                    var source = GLctx.getShaderSource(GLshaders[shader]);
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
        }
    });

})(MOD);