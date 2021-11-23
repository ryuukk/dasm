module mesh;

import dbg;
import gl;
import math;
import str;


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
            return;
        }
    }

    const bool opEquals(ref const(ShaderProgram) rhs)
    {
        return program == rhs.program;
    }

    void deinit()
    {}

    void fetch_attributes()
    {
        glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &num_attributes);
        //LINFO("Attributes: %i", num_attributes);
        char[128] buffer = 0;
        int i = 0;
        while (i < num_attributes) {
            uint typee = 0;
            int size = 0;
            int length = 0;

            buffer = 0;
            glGetActiveAttrib(program, i, 128, &length, &size, &typee, buffer.ptr);

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
            i += 1;
        }
    }

    void fetch_uniforms()
    {
        glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &num_uniforms);
        // LINFO("Uniforms: %i", num_uniforms);
        char[128] buffer = 0;
        int i = 0;
        while (i < num_uniforms) {
            uint typee = 0;
            int size = 0;
            int length = 0;

            buffer = 0;
            glGetActiveUniform(program, i, 128, &length, &size, &typee, buffer.ptr);

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
            return 0;
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
            
            panic("can't compile shader %s:\n%s", (is_v ? "VERTEX" : "FRAGMENT").ptr, buffer.ptr);
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
            
            char[4096] buffer = 0;
            int l = 0;
            glGetProgramInfoLog(program, buffer.length, &l, buffer.ptr);
            
            panic("can't link program:\n%s", buffer.ptr);
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
        debug check_gl_error(false);

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
                panic("can't find unfiform: %s", name.ptr);
                return 0;
            }

            // uniform.location = location;
        }

        return location;
    }

    // --- BY NAME
    void set_uniform_mat4(const(char)[] name, mat4* value) {
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
       
    void set_uniform_mat4(int location, mat4* value) {
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

