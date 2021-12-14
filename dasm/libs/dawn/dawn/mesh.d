module dawn.mesh;

import rt.dbg;
import rt.math;
import rt.str;
import rt.memz;

import dawn.gl;
import dawn.renderer;
import dawn.assets;

enum LocType : byte
{
    ATTRIBUTE, UNIFORM
}

struct ShaderLoc 
{
    LocType loc_type;
    int location;
    uint type;
    int size;
    char[64] name = 0;
}

struct ShaderProgram {
    bool invalidated = false;
    uint program = 0;
    uint v_handle = 0;
    uint f_handle = 0;
    bool is_compiled = false;
    ShaderLoc[16] attributes;
    ShaderLoc[16] uniforms;
    int num_attributes = 0;
    int num_uniforms = 0;

    bool require_uniform = true;
    char[4096] log = 0;

    void create(const(char)[] v, const(char)[] f)
    {
        compile_shaders(v, f);
        if (is_compiled)
        {
            fetch_attributes();
            fetch_uniforms();
        } 
        else 
        {
            panic("Can't compile shader");
        }
    }

    const bool opEquals(ref const(ShaderProgram) rhs)
    {
        return program == rhs.program;
    }

    void dispose()
    {
        glUseProgram(0);
        glDeleteShader(v_handle);
        glDeleteShader(f_handle);
        glDeleteProgram(program);
    }

    void fetch_attributes()
    {
        glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &num_attributes);
        //LINFO("Attributes: %i", num_attributes);
        // writeln("Attributes: {}", num_attributes);
        char[128] buffer = 0;
        int i = 0;
        while (i < num_attributes) {
            uint typee = 0;
            int size = 0;
            int length = 0;

            buffer = 0;
            
            glGetActiveAttrib(program, i, buffer.length, &length, &size, &typee, buffer.ptr);

            assert(str_len(buffer.ptr) != 0);

            auto sl = ShaderLoc();
            sl.loc_type = LocType.ATTRIBUTE;
            //sl.name[0 .. length + 1] = buffer[0 .. length + 1];
            sl.name = 0;

            
            strcpy(sl.name.ptr, buffer.ptr);

            int location = glGetAttribLocation(program, buffer.ptr);
            //assert(location == i);

            sl.location = location;
            sl.size = size;
            sl.type = typee;

            attributes[i] = sl;

            //LINFO("    attribute: loc: %i name: %s", location, sl.name.ptr);
            // writeln("atrib: {} - {}", location, sl.name);
            i += 1;
        }
    }

    void fetch_uniforms()
    {
        glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &num_uniforms);
        // LINFO("Uniforms: %i", num_uniforms);
        // writeln("Uniforms: {}", num_uniforms);
        char[96] buffer = 0;
        int i = 0;
        while (i < num_uniforms) {
            uint typee = 0;
            int size = 0;
            int length = 0;

            buffer = 0;
            glGetActiveUniform(program, i, 128, &length, &size, &typee, buffer.ptr);

            assert(str_len(buffer.ptr) != 0);
            

            auto sl = ShaderLoc();
            sl.loc_type = LocType.UNIFORM;
            //sl.name[0 .. length + 1] = buffer[0 .. length + 1];
            sl.name = 0;
            strcpy(sl.name.ptr, buffer.ptr);

            int location = glGetUniformLocation(program, buffer.ptr);
            // TODO: i != location, will it break elsewhere, dunno
            // assert(location == i);

            sl.location = location;
            sl.size = size;
            sl.type = typee;

            uniforms[i] = sl;

            // LINFO("    uniform: loc: %i name: %s", location, sl.name.ptr);
            // writeln("uniform: {} - {}", location, sl.name);

            i += 1;
        }
    }

    void compile_shaders(const(char)[] v, const(char)[] f)
    {
        v_handle = load_shader(true, v);
        if(v_handle == 0)
        {
            is_compiled = false;
            return;
        }
        
        f_handle = load_shader(false, f);
        if(f_handle == 0)
        {
            is_compiled = false;
            return;
        }
        
        program = link_program(create_program());
        if(program == 0)
        {
            is_compiled = false;
            return;
        }

        is_compiled = true;
    }

    uint load_shader(bool is_v, const(char)[] source)
    {
        int vs = glCreateShader(is_v ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER);
        if(vs == 0) 
        {
            panic("not time for that right now");
        }

        int compiled = 0;
        int ssl = cast(int) source.length;
        auto ptr = cast(char*) cast(void*) source.ptr;

        glShaderSource(vs, 1, &ptr, &ssl);
        glCompileShader(vs); 
        glGetShaderiv(vs, GL_COMPILE_STATUS, &compiled);

        if(compiled == 0)
        {
            int logLen = 0;
            glGetShaderiv(vs, GL_INFO_LOG_LENGTH, &logLen);
            
            char[4096] buffer = 0;
            int l = 0;
            glGetShaderInfoLog(vs, buffer.length, &l, buffer.ptr);
            

            LERRO("Can't compile shader {}:\n{}",  (is_v ? "VERTEX" : "FRAGMENT"), buffer);
            return 0;
        }

        return vs;
    }
    
    uint create_program()
    {
        return glCreateProgram();
    }

    uint link_program(uint program)
    {
        if(program == 0) return 0;

        glAttachShader(program, v_handle);
        glAttachShader(program, f_handle);
        glLinkProgram(program);

        int linked = 0;
        glGetProgramiv(program, GL_LINK_STATUS, &linked);

        if(linked == 0)
        {
            int logLen = 0;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);

            int l = 0;
            glGetProgramInfoLog(program, log.length, &l, log.ptr);
            
            //panic("can't link program:\n%s", buffer.ptr);
            return 0;
        }

        return program;
    }

    void check_managed()
    {
        if(invalidated) 
        {
            panic("no time");
        }
    }

    void bind()
    {
        check_managed();
        glUseProgram(program);
    }

    int get_attrib_loc(const(char)[] aliass)
    {
        import core.stdc.string: strcmp;
        for(int i = 0; i < num_attributes; i++)
        {
            auto attr = &attributes[i];
            if(!strcmp(attr.name.ptr, aliass.ptr)) 
                return attr.location;
        }
        return -1;
    }

    void enable_vert_attr(int location)
    {
        check_managed();
        glEnableVertexAttribArray(cast(uint) location);
    }

    void set_vert_attr(int location, int size, uint gltype, bool norm, int stride, int offset) {
        check_managed();
        // @intToPtr(?*const c_void, @intCast(usize, orr))
        //debug checkGLError("set_vert_attr pre");
        glVertexAttribPointer(cast(uint)location, size, gltype, norm? GL_TRUE : GL_FALSE, stride, cast(const(void)*) offset);
        version(CHECK_GL) check_gl_error(false);
    }

    int fetch_uniform_location(const(char)[] name, bool pedantic) {
        import core.stdc.string: strcmp;
        int location = -2;
        ShaderLoc* uniform = null;

        for(int i = 0; i < num_uniforms; i++)
        {
            auto u = &uniforms[i];
            if(!strcmp(u.name.ptr, name.ptr)) {
                location = u.location;
                uniform = u;
                break;
            }
        }

        //if(uniform == null) 
        //    panic("can't find unfiform: %s", name.ptr);

        if (location == -2) {
            location = glGetUniformLocation(program, name.ptr);
            if (location == -1 && pedantic) {
                panic("can't find unfiform: {}", name.ptr);
            }

            // uniform.location = location;
        }

        return location;
    }

    // --- BY NAME
    void set_uniform_mat4(const(char)[] name, ref mat4 value) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added

        glUniformMatrix4fv(location, 1, 0, &value.m00);
    }

    void set_uniform_mat4_array(const(char)[] name, uint size, ref mat4[] value) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added

        glUniformMatrix4fv(location, size, 0, &value[0].m00);
    }

    void set_uniformi(const(char)[] name, int value) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added

        glUniform1i(location, value);
    }

    void set_uniformf(const(char)[] name, float value) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added

        glUniform1f(location, value);
    }

    void set_uniform4f(const(char)[] name, float a, float b, float c, float d) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added

        glUniform4f(location, a, b, c, d);
    }

    void set_uniform_color(const(char)[] name, float r, float g, float b, float a) {
        check_managed();
        int location = fetch_uniform_location(name, require_uniform); // TODO: change once static pedantic bool added
        glUniform4f(location, r, g, b, a);
    }

    // --- BY LOCATION
       
    void set_uniform_mat4(int location, ref mat4 value) {
        check_managed();
        glUniformMatrix4fv(location, 1, 0, &value.m00);
    }

    void set_uniform_mat4_array(int location, uint size, ref mat4[] value) {
        check_managed();
        glUniformMatrix4fv(location, size, 0, &value[0].m00);
    }

    void set_uniformi(int location, int value) {
        check_managed();
        glUniform1i(location, value);
    }

    void set_uniformf(int location, float value) {
        check_managed();
        glUniform1f(location, value);
    }

    void set_uniform4f(int location, float a, float b, float c, float d) {
        check_managed();

        glUniform4f(location, a, b, c, d);
    }

    void set_uniform_color(int location, float r, float g, float b, float a) {
        check_managed();
        glUniform4f(location, r, g, b, a);
    }
}



enum VertexUsage : int
{
    POSITION = 1,
    COLOR_UNPACKED = 2,
    COLOR_PACKED = 4,
    NORMAL = 8,
    TEXTURE_COOR = 16,
    GENERIC = 32,
    BONE_WEIGHT = 64,
    TANGENT = 128,
    BINORMAL = 256,
    TEXTURE_INDEX = 512,
    MAX = 9,
}


struct VertexAttributes
{
    VertexAttribute[VertexUsage.MAX] attributes;
    int vertex_size;
    uint mask;
    ubyte num_attributes;

    ref VertexAttributes add(VertexAttribute attr) return
    {
        attributes[num_attributes++] = attr;
        vertex_size = calculate_offsets();
        return this;
    }

    int calculate_offsets()
    {
        int count = 0;
        for(int i = 0; i < num_attributes; i++)
        {
            auto a = &attributes[i];
            a.offset = count;
            count += a.get_size_bytes();

            mask |= a.usage;
        }
        return count;
    }

    ulong get_mask_with_size_packed()
    {
        return mask | (cast(ulong) vertex_size << 32);
    }
}

struct VertexAttribute
{
    VertexUsage usage;
    int num_components = 0;
    bool normalized = false;
    uint gl_type = 0;
    int offset = 0;
    char[64] aliass;
    int unit = 0;
    int _usage_index;

    int get_size_bytes()
    {
        switch(gl_type)
        {
            case GL_FLOAT: return 4 * num_components;
            case GL_UNSIGNED_SHORT:
            case GL_SHORT:
                return 2 * num_components;
            case GL_UNSIGNED_BYTE:
            case GL_BYTE:
                return num_components;

            default: 
                panic("VA type not supported: %i", gl_type); 
        }
        version (WASM) return 0; // TODO: noreturn doesn't work for wasm yet! report to LDC!
    }

    int get_key()
    {
        return (_usage_index << 8) + (unit & 0xFF);
    }

    static VertexAttribute position2D()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.POSITION;
        ret.num_components = 2;
        ret.aliass = "a_position";
        ret.gl_type = GL_FLOAT;
        ret._usage_index = number_of_trailing_zeros(ret.usage);
        return ret;
    }

    static VertexAttribute position3D()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.POSITION;
        ret.num_components = 3;
        ret.aliass = "a_position";
        ret.gl_type = GL_FLOAT;
        ret._usage_index = number_of_trailing_zeros(ret.usage);
        return ret;
    }
    
    static VertexAttribute color_unpacked()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.COLOR_UNPACKED;
        ret.num_components = 4;
        ret.aliass = "a_color";
        ret.gl_type = GL_FLOAT;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.COLOR_UNPACKED);
        return ret;
    }
    
    static VertexAttribute color_packed()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.COLOR_PACKED;
        ret.num_components = 4;
        ret.aliass = "a_color";
        ret.gl_type = 0x1401;
        ret.normalized = true;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.COLOR_PACKED);
        return ret;
    }
    static VertexAttribute normal()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.POSITION;
        ret.num_components = 3;
        ret.aliass = "a_normal";
        ret.gl_type = GL_FLOAT;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.NORMAL);
        return ret;
    }
    static VertexAttribute tex_coords(int index)
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.TEXTURE_COOR;
        ret.num_components = 2;
        ret.aliass = "a_texCoord0";
        if(index > 0)
            ret.aliass[10] = cast(char) (index + cast(int)'0');
        ret.gl_type = GL_FLOAT;
        ret.unit = index;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.TEXTURE_COOR);
        return ret;
    }
    static VertexAttribute tex_index()
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.TEXTURE_INDEX;
        ret.num_components = 1;
        ret.aliass = "a_texIndex";
        ret.gl_type = GL_FLOAT;
        ret.unit = 0;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.TEXTURE_INDEX);
        return ret;
    }
    
    static VertexAttribute blend_weight(int index)
    {
        VertexAttribute ret;
        ret.usage = VertexUsage.BONE_WEIGHT;
        ret.num_components = 2;
        ret.aliass = "a_boneWeight0";
        if(index > 0)
            ret.aliass[12] = cast(char) (index + cast(int)'0');
        ret.gl_type = GL_FLOAT;
        ret.unit = index;
        ret._usage_index = number_of_trailing_zeros(VertexUsage.BONE_WEIGHT);
        return ret;
    }
}


struct VertexBuffer 
{
    uint buffer_handle;
    uint vao_handle = 0;
    uint usage = 0;
    bool is_static = false;
    bool is_dirty = false;
    bool is_bound = false;

    VertexAttributes attributes;
    float[] vertices;

    void create(bool s, int size, VertexAttributes attrs)
    {
        int vsize = size * (attrs.vertex_size / 4);

        assert(vsize > 0);

        attributes = attrs;


        LINFO("create vertices of size: {} :: {} :: {} {}", vsize, size, float.sizeof * vsize, attrs.vertex_size);
        auto ptr = cast(float*) malloc(float.sizeof * vsize);
        vertices = ptr[0 .. vsize];

        glGenBuffers(1, &buffer_handle);

        usage = s ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;

        glGenVertexArrays(1, &vao_handle);
    }

    void dispose()
    {
        if(vertices.length ==0) return;

        free(vertices.ptr);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDeleteBuffers(1, &buffer_handle);
        glDeleteVertexArrays(1, &vao_handle);
    }

    void bind(ShaderProgram* program, int[] locations)
    {
        glBindVertexArray(vao_handle);
        //TODO:
        glBindBuffer(GL_ARRAY_BUFFER, buffer_handle);

        bind_attributes(program, locations);
        bind_data();
        is_bound = true;
    }
    
    void bind_attributes(ShaderProgram* program, int[] locations)
    {
        auto numAttributes = attributes.num_attributes;
        for(int i = 0; i < numAttributes; i++) 
        {
            auto attr = &attributes.attributes[i];
            auto loc = program.get_attrib_loc(attr.aliass);
            if(loc < 0)
            {
                // TODO: better log this
                // happens when a_ not used in shader
                // LWARN("no va for: {}", attr.aliass.ptr);
                continue;
            }

            program.enable_vert_attr(loc);
            program.set_vert_attr(loc, attr.num_components, attr.gl_type, attr.normalized, attributes.vertex_size, attr.offset);

        }

        // TODO: finish implementing caching, but do we need to do it here?
    }

    void bind_data()
    {
        if(is_dirty)
        {
            glBindBuffer(GL_ARRAY_BUFFER, buffer_handle);
            glBufferData(GL_ARRAY_BUFFER, vertices.length * 4, vertices.ptr, usage);
            is_dirty = false;
        }
    }

    void unbind(ShaderProgram* program, int[] locations)
    {
        glBindVertexArray(0);
        //TODO:
         glBindBuffer(GL_ARRAY_BUFFER, 0);
        is_bound = false;
    }

    void set_data(const float[] data, int offset, int count)
    {
        assert(offset >= 0);
        assert(offset < data.length);
        assert((offset+count) <= data.length);
        is_dirty = true;

        for(int i = 0; i < count; i++) 
        {
            //printf("Set: [%i] < [%i + %i]:%i\n", i, offset, i, data[offset + i]);
            vertices[i] = data[offset + i];
        }

        buffer_changed();
    }

    void buffer_changed()
    {
        if(is_bound)
        {
            glBindBuffer(GL_ARRAY_BUFFER, buffer_handle);
            glBufferData(GL_ARRAY_BUFFER, vertices.length * 4, vertices.ptr, usage);
            is_dirty = false;
        }
    }

    uint get_num_vertices()
    {
        return cast(uint) vertices.length;
    }

    uint get_num_max_vertices()
    {
        return cast(uint) vertices.length;
    }
}

struct IndexBuffer 
{
    uint handle;
    int[] buffer;
    bool is_direct;
    bool is_dirty;
    bool is_bound;
    uint usage;
    bool empty;

    void create(bool s, int size)
    {
        empty = s == 0;

        is_direct = true;

        glGenBuffers(1, &handle);
        usage = s ? GL_STATIC_DRAW : GL_DYNAMIC_DRAW;

        
        if(size > 0)
        {
            auto ptr = cast(int*)malloc(int.sizeof * size);
            buffer = ptr[0 .. size];
        }
    }

    void dispose()
    {
        if(buffer.length == 0) return;
        
        free(buffer.ptr);
        // TODO: do i need to find 0?
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glDeleteBuffers(1, &handle);
    }

    void bind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, handle);
        if (is_dirty) {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, buffer.length * 4, buffer.ptr, usage);            
            is_dirty = false;
        }
        is_bound = true;
    }

    void unbind()
    {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, handle);
        if (is_dirty) {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, buffer.length * 4, buffer.ptr, usage);            
            is_dirty = false;
        }
        is_bound = true;
    }

    void invalidate()
    {
        glGenBuffers(1, &handle);
        is_dirty = true;
    }

    void set_data(const int[] data, uint offset, uint count)
    {
        is_dirty = true;

        for(int i = 0; i < count; i++) 
        {
            buffer[i] = data[offset + i];
        }
        if(is_bound)
        {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, buffer.length * 4, buffer.ptr, usage);
            is_dirty = true;
        }
    }
    
    uint get_num_indices()
    {
        return cast(uint)buffer.length;
    }

    uint get_num_max_indices()
    {
        return cast(uint)buffer.length;
    }
}

struct Mesh
{
    VertexBuffer vb;
    IndexBuffer ib;
    bool autobind = true;

    void create(bool s, uint num_v, uint num_i, VertexAttributes attrs)
    {
        vb.create(s, num_v, attrs);
        ib.create(s, num_i);
    }

    void dispose()
    {
        vb.dispose();
        ib.dispose();
    }

    void render(ShaderProgram* program, uint primitiveType) {
        render(
            program,
            primitiveType,
            0,
            ib.get_num_max_indices() > 0 ? ib.get_num_indices() : vb.get_num_vertices(),
            autobind
        );
    }

    void render(ShaderProgram* program, uint primitiveType, int offset, int count, bool autoBind)
    {
        if (count == 0)
            return;

        if(autoBind) 
            bind(program, null);
        
        if(ib.get_num_indices() > 0)
        {
            int orr = offset * 4;
            glDrawElements(primitiveType, count, GL_UNSIGNED_INT,  cast(void*) orr);
        }
        else
        {
            glDrawArrays(primitiveType, offset, count);
        }


        if(autoBind)
            unbind(program, null);

    }

    void bind(ShaderProgram* program, int[] locations)
    {
        vb.bind(program, locations);
        if(ib.get_num_indices() > 0) ib.bind();
    }
    
    void unbind(ShaderProgram* program, int[] locations)
    {
        vb.unbind(program, locations);
        if(ib.get_num_indices() > 0) ib.unbind();
    }

    VertexAttribute* get_vert_attr(VertexUsage usage)
    {
        for(int i = 0; i < vb.attributes.num_attributes; i++)
        {
            auto attr = &vb.attributes.attributes[i];
            if (attr.usage == usage)
                return attr;
        }
        return null;
    }

    BoundingBox calculate_bounds()
    {
        BoundingBox bbox;
        bbox.inf();
		int numVertices = vb.get_num_vertices();
        assert(numVertices > 0);

		float[] verts = vb.vertices;
		VertexAttribute* posAttrib = get_vert_attr(VertexUsage.POSITION);
		int offset = posAttrib.offset / 4;
		int vertexSize = vb.attributes.vertex_size / 4;
		int idx = offset;

		switch (posAttrib.num_components) {
		case 1:
			for (int i = 0; i < numVertices; i++) {
				bbox.ext(verts[idx], 0, 0);
				idx += vertexSize;
			}
			break;
		case 2:
			for (int i = 0; i < numVertices; i++) {
				bbox.ext(verts[idx], verts[idx + 1], 0);
				idx += vertexSize;
			}
			break;
		case 3:
			for (int i = 0; i < numVertices; i++) {
				bbox.ext(verts[idx], verts[idx + 1], verts[idx + 2]);
				idx += vertexSize;
			}
			break;
        default:break;
		}
        return bbox;
    }

    void calculate_bounds(ref BoundingBox bounds, int offset, int count, mat4* transform = null)
    {
        extend_bounds(bounds.inf(), offset, count, transform);
    }

    void extend_bounds(ref BoundingBox bounds, int offset, int count, mat4* transform = null)
    {
	    int numIndices = ib.get_num_indices();
		int numVertices = vb.get_num_vertices();
		int max = numIndices == 0 ? numVertices : numIndices;
		if (offset < 0 || count < 1 || offset + count > max)
            panic("invalid part specified ( offset='{}' count='{}' max='{}' )", offset, count, max);

		float[] verts = vb.vertices;
		int[] index = ib.buffer;

		VertexAttribute* posAttrib = get_vert_attr(VertexUsage.POSITION);
		int posoff = posAttrib.offset / 4;
		int vertexSize = vb.attributes.vertex_size / 4;
		int end = offset + count;

		switch (posAttrib.num_components) {
		case 1:
			if (numIndices > 0) {
				for (int i = offset; i < end; i++) {
					int idx = (index[i]) * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], 0, 0);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			} else {
				for (int i = offset; i < end; i++) {
					int idx = i * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], 0, 0);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			}
			break;
		case 2:
			if (numIndices > 0) {
				for (int i = offset; i < end; i++) {
					int idx = (index[i]) * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], verts[idx + 1], 0);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			} else {
				for (int i = offset; i < end; i++) {
					int idx = i * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], verts[idx + 1], 0);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			}
			break;
		case 3:
			if (numIndices > 0) {
				for (int i = offset; i < end; i++) {
					int idx = (index[i]) * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], verts[idx + 1], verts[idx + 2]);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			} else {
				for (int i = offset; i < end; i++) {
					int idx = i * vertexSize + posoff;
					v3 tmpV = v3(verts[idx], verts[idx + 1], verts[idx + 2]);
					if (transform != null) tmpV = tmpV.mul(transform);
					bounds.ext(tmpV.tupleof);
				}
			}
			break;
        default: break;
		}
    }
}

struct MeshPart
{
    char[32] id = 0;
    int primitive_type;
    int offset;
    int size;
    Mesh* mesh;

    // TODO: finish
    v3 center;
    v3 halfExtents;
    float radius = -1;

    void render(ShaderProgram* program, bool autobind)
    {
        mesh.render(program, primitive_type, offset, size, autobind);
    }

    void update()
    {
        BoundingBox bounds;
        mesh.extend_bounds(bounds, offset, size);

		center = bounds.cnt;
		halfExtents = bounds.cnt * 0.5;
		radius = v3.len(halfExtents.x, halfExtents.y, halfExtents.z);

        LINFO("{} -> {}:{}:{} r: {}", id, center.x, center.y, center.z, radius);
        LINFO("{} -> he {}:{}:{}", id, halfExtents.x, halfExtents.y, halfExtents.z);
    }

    void reset()
    {
        id[] = '\0';
        primitive_type = 0;
        offset = 0;
        size = 0;
        mesh = null;
    }

    void set(const (char)[] id,  Mesh* rhs, int primitiveType)
    {
        assert(id.length < this.id.length);
        memcpy(this.id.ptr, id.ptr, id.length);

        mesh = rhs;
        offset = 0;
        size = (mesh.ib.get_num_indices > 0 ? mesh.ib.get_num_indices : mesh.vb.get_num_vertices);
        primitive_type = primitiveType;
    }

    void from(MeshPart* rhs)
    {
        memcpy(id.ptr, rhs.id.ptr, rhs.id.length);
        primitive_type = rhs.primitive_type;
        offset = rhs.offset;
        size = rhs.size;
        mesh = rhs.mesh;
        // TODO: finish copy rest once rest is implemented
    }
}


enum UsagColorFlag : ubyte
{
    fNONE = 0,
    fcDiffuse 			= 1 << 0,
    fcAmbient 			= 1 << 1,
    fcEmissive 			= 1 << 2,
    fcSpecular 			= 1 << 3,
    fcShininess			= 1 << 4,
    fcOpacity 			= 1 << 5,
}

enum AttributeType : ulong
{
    DIFFUSE_TEXTURE = 1 << 0,

    DIFFUSE_COLOR = 1 << 1,
    SPECULAR_COLOR = 1 << 2,
    AMBIENT_COLOR = 1 << 3,
    EMISSIVE_COLOR = 1 << 4,
    REFLECTION_COLOR = 1 << 5,
    AMBIENT_LIGHT_COLOR = 1 << 6,
    FOG_COLOR = 1 << 7,

    CULLFACE = 1 << 8,
    DEPTH_TEST = 1 << 9,
}

struct DiffuseTexAttribute
{
    char[32] id;

    TextureAsset* texture;

    float offset_u = 0;
    float offset_v = 0;
    float scale_u = 1;
    float scale_v = 1;
}

struct DepthAttribute
{   
    bool enabled = true;
    uint depth_func = GL_LEQUAL;
    float depth_range_near = 0.0;
    float depth_range_far = 1.0;
    bool depth_mask = true;
}

struct BlendAttribute
{
    bool enabled = true;
    float opacity = 1.0;
    BlendState blend_state = BlendState.AlphaBlend;
}

struct AlphaTestAttribute
{
    float value = 0.0;
}

struct Attribute
{
    ulong type;
    union 
    {
        DiffuseTexAttribute diffuse_tex;
        DepthAttribute depth;
        BlendAttribute blend;
        AlphaTestAttribute alpha_test;
    }
}

struct Material 
{
    char[32] id;
    Attribute[8] attributes;
    int num_attrs;
    ulong mask;
    bool sorted = true;
    private void enable(ulong mask)
    {
        this.mask |= mask;
    }

    private void disable(ulong mask)
    {
        this.mask &= ~mask;
    }

    void sort()
    {
        if (!sorted)
        {
            // todo: figure out sorting
            //attributes.sort(this);
            sorted = true;
        }
    }

    void set(Attribute attribute)
    {
        int idx = indexOf(attribute.type);
        if (idx < 0)
        {
            enable(attribute.type);
            attributes[num_attrs] = attribute;
            num_attrs++;
            sorted = false;
        }
        else
        {
            attributes[idx] = attribute;
        }
        sort(); //FIXME: See #4186
    }

    bool has(ulong type)
    {
        return type != 0 && (this.mask & type) == type;
    }

    int indexOf(ulong type)
    {
        if (has(type))
            for (int i = 0; i < num_attrs; i++)
                if (attributes[i].type == type)
                    return i;
        return -1;
    }

    T* get(T)(ulong t)
    {
        int index = indexOf(t);
        if (index == -1)
            return null;

        return cast(T*) &attributes[index];
    }

    ulong getMask()
    {
        return mask;
    }
}





// -- UTILITIES

int bit_count(int value) {
    int i = value;
    // Algo from : http://aggregate.ee.engr.uky.edu/MAGIC/#Population%20Count%20(ones%20Count)
    i -= ((i >> 1) & 0x55555555);
    i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
    i = (((i >> 4) + i) & 0x0F0F0F0F);
    i += (i >> 8);
    i += (i >> 16);
    return (i & 0x0000003F);
}

int number_of_trailing_zeros(int i) {
    return bit_count((i & -i) - 1);
}



void create_cube_mesh(Mesh* cube)
{
    auto attr = VertexAttributes()
        .add(VertexAttribute.position3D())
        .add(VertexAttribute.normal());

    cube.create(true, 24, 36, attr);

    float[72] cubeVerts = [
        -0.5f, -0.5f, -0.5f,        -0.5f, -0.5f, 0.5f,
        0.5f, -0.5f, 0.5f,          0.5f, -0.5f, -0.5f,
        -0.5f, 0.5f, -0.5f,         -0.5f, 0.5f, 0.5f,
        0.5f, 0.5f, 0.5f,           0.5f, 0.5f, -0.5f,
        -0.5f, -0.5f, -0.5f,        -0.5f, 0.5f, -0.5f,
        0.5f, 0.5f, -0.5f,          0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f, 0.5f,         -0.5f, 0.5f, 0.5f,
        0.5f, 0.5f, 0.5f,           0.5f, -0.5f, 0.5f,
        -0.5f, -0.5f, -0.5f,        -0.5f, -0.5f, 0.5f,
        -0.5f, 0.5f, 0.5f,          -0.5f, 0.5f, -0.5f, 
        0.5f, -0.5f, -0.5f,         0.5f, -0.5f, 0.5f,
         0.5f, 0.5f, 0.5f,          0.5f, 0.5f, -0.5f
    ];

    float[72] cubeNormals = [
        0.2f, -0.5f, 0.2f,
        0.2f, -0.5f, 0.2f,
        0.2f, -0.5f, 0.2f,
        0.2f, -0.5f, 0.2f,

        0.2f, 0.5f, 0.2f,
        0.2f, 0.5f, 0.2f,
        0.2f, 0.5f, 0.2f,
        0.2f, 0.5f, 0.2f,

        0.2f, 0.2f, -0.5f,
        0.2f, 0.2f, -0.5f,
        0.2f, 0.2f, -0.5f,
        0.2f, 0.2f, -0.5f,

        0.2f, 0.2f, 0.5f,
        0.2f, 0.2f, 0.5f,
        0.2f, 0.2f, 0.5f,
        0.2f, 0.2f, 0.5f,

        -0.5f, 0.2f, 0.2f,
        -0.5f, 0.2f, 0.2f,
        -0.5f, 0.2f, 0.2f,
        -0.5f, 0.2f, 0.2f,

        0.5f, 0.2f, 0.2f,
        0.5f, 0.2f, 0.2f,
        0.5f, 0.2f, 0.2f,
        0.5f, 0.2f, 0.2f
    ];

    //float[72] cubeTex = {0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f,
    //  0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
    //  1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f,};

    float[24 * 6] vertices;
    int pIdx = 0;
    int nIdx = 0;
    //int tIdx = 0;
    for (int i = 0; i < vertices.length;)
    {
        vertices[i++] = cubeVerts[pIdx++];
        vertices[i++] = cubeVerts[pIdx++];
        vertices[i++] = cubeVerts[pIdx++];
        vertices[i++] = cubeNormals[nIdx++];
        vertices[i++] = cubeNormals[nIdx++];
        vertices[i++] = cubeNormals[nIdx++];
        //vertices[i++] = cubeTex[tIdx++];
        //vertices[i++] = cubeTex[tIdx++];
    }

    int[36] indices = [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 15, 14, 12, 14, 13, 16, 17, 18, 16,
        18, 19, 20, 23, 22, 20, 22, 21];

    cube.vb.set_data(vertices, 0, vertices.length);
    cube.ib.set_data(indices, 0, indices.length);
}
