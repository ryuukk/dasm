module dawn.texture;

import rt.dbg;
import dawn.gl;
import dawn.gfx;

struct Texture2D 
{
    uint gl_target;
    uint gl_handle;
    TextureFilter filter_min = TextureFilter.Nearest;
    TextureFilter filter_mag = TextureFilter.Nearest;
    TextureWrap wrap_u = TextureWrap.ClampToEdge;
    TextureWrap wrap_v = TextureWrap.ClampToEdge;

    uint width = 0;
    uint height = 0;

    PixelFormat format;
        
    void dispose()
    {
        if (gl_handle == 0)
            return;
        glDeleteTextures(1, &gl_handle);
        gl_handle = 0;
    }

    void bind()
    {
        glBindTexture(gl_target, gl_handle);
    }

	void bind(int unit)
    {
		glActiveTexture(GL_TEXTURE0 + unit); //since this is sequential, this works
		glBindTexture(gl_target, gl_handle);

	} 

    void set_data(ubyte[] data, uint width, uint height)
    {
        set_data(data.ptr, width, height);
    }

    void set_data(ubyte* data, uint width, uint height)
    {
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

        if(format == PixelFormat.Luminance)
            glTexImage2D(gl_target, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, data);
        else
            glTexImage2D(gl_target, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    }
}

struct Framebuffer
{
    uint width = 0;
    uint height = 0;

    uint fbo;
    Texture2D tex_depth;
    Texture2D tex_color;

    bool has_depth;
    bool has_color;
    bool auto_resize;

    void dispose()
    {
        if(fbo == 0) return;

        glDeleteFramebuffers(1, &fbo);  
        
        if(has_color)
            tex_color.dispose();
        
        if(has_depth)
            tex_depth.dispose();

        fbo = 0;
    }

    void create(uint width, uint height, bool color, bool depth, bool autoResize)
    {
        assert(width > 0);
        assert(height > 0);

        this.width = width;
        this.height = height;

        has_color = color;
        has_depth = depth;

        // Bind FBO
        glGenFramebuffers(1, &fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);

        if(color)
        {
            enum internal_format = GL_RGBA; 
            enum format = GL_RGBA;
            // Generate texture
            tex_color = Texture2D();
            tex_color.gl_target = GL_TEXTURE_2D;
            tex_color.width = width;
            tex_color.height = height;
            
            glGenTextures(1, &tex_color.gl_handle);
            glBindTexture(GL_TEXTURE_2D, tex_color.gl_handle);
            glTexImage2D(GL_TEXTURE_2D, 0, internal_format, width, height, 0, format, GL_UNSIGNED_BYTE, null);

            // Set up texture parameters
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, tex_color.gl_target, tex_color.gl_handle, 0);
            
			glDrawBuffer(GL_COLOR_ATTACHMENT0);
            glBindTexture(GL_TEXTURE_2D, 0);

            auto sts_c = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            if (sts_c != GL_FRAMEBUFFER_COMPLETE)
                LERRO("problem with fb-color! {}", sts_c);
            assert(sts_c == GL_FRAMEBUFFER_COMPLETE);
        }

        if(depth)
        {
            // Generate depth buffer
            tex_depth = Texture2D();
            tex_depth.gl_target = GL_TEXTURE_2D;
            tex_depth.width = width;
            tex_depth.height = height;
            
            glGenTextures(1, &tex_depth.gl_handle);
            glBindTexture(GL_TEXTURE_2D, tex_depth.gl_handle);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT16, width, height, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_SHORT, null);

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, tex_depth.gl_target, tex_depth.gl_handle, 0);
            glBindTexture(GL_TEXTURE_2D, 0);
        }

        auto sts = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (sts != GL_FRAMEBUFFER_COMPLETE)
            writeln("incomplete! {}", sts);
		assert(sts == GL_FRAMEBUFFER_COMPLETE);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        debug check_gl_error();
    }
    
    void bind() {
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glViewport(0, 0, width, height);
    }

    void unbind_v(uint width, uint height) {
        
         debug check_gl_error();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, width, height);
         debug check_gl_error();
    }
    void unbind_n() {
         debug check_gl_error();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, width, height);
         debug check_gl_error();
    }
}

/*
Texture2D load(const(char)[] file)
{
    import decoders.png;
    
    auto a = read_image(file, 4);
    if (a.e) {
        panic("*** load error: %d",  a.e);
    } 
    scope(exit) a.free();

    uint target = GL_TEXTURE_2D;
    uint handle;
    glGenTextures(1, &handle);
    glBindTexture(target, handle);


    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(target, 0, GL_RGBA, a.w, a.h, 0, GL_RGBA, GL_UNSIGNED_BYTE, a.buf8.ptr);

    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glBindTexture(target, 0);

    auto ret = Texture2D();
    ret.gl_target = target;
    ret.gl_handle = handle;
    ret.width = a.w;
    ret.height = a.h;

    return ret;
}
*/
Texture2D create_texture(uint width, uint height, ubyte* ptr, PixelFormat format = PixelFormat.Rgba)
{
    uint target = GL_TEXTURE_2D;
    uint handle;
    glGenTextures(1, &handle);
    glBindTexture(target, handle);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    if (format == PixelFormat.Alpha)
        glTexImage2D(target, 0, GL_ALPHA, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, ptr);
    else if (format == PixelFormat.Rgb)
        glTexImage2D(target, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, ptr);
    else if (format == PixelFormat.Rgba)
        glTexImage2D(target, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, ptr);
    else
    {
        assert(false, "nope");
    }

    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glBindTexture(target, 0);

    auto ret = Texture2D();
    ret.gl_target = target;
    ret.gl_handle = handle;
    ret.width = width;
    ret.height = height;
    ret.format = format;
    return ret;
}

Texture2D create_texture_array(uint width, uint height, int depth, PixelFormat format = PixelFormat.Rgba)
{
    uint target = GL_TEXTURE_2D_ARRAY;
    uint glformat = GL_RGBA;
    uint handle;
    glGenTextures(1, &handle);
    glBindTexture(target, handle);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    // TODO: add other formats
    if (format == PixelFormat.Rgba)
        glformat = GL_RGBA;
    else
        assert(false, "nope");
    
    glTexImage3D(target, 0, glformat, width, height, depth, 0, glformat, GL_UNSIGNED_BYTE, null);


    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glBindTexture(target, 0);

    auto ret = Texture2D();
    ret.gl_target = target;
    ret.gl_handle = handle;
    ret.width = width;
    ret.height = height;
    ret.format = format;
    return ret;
}

void add_texture(Texture2D* tex, int index, ubyte* buffer)
{
    assert(tex.gl_target == GL_TEXTURE_2D_ARRAY);

    uint glformat = GL_RGBA;
    if (tex.format == PixelFormat.Rgba)
        glformat = GL_RGBA;
    else
        assert(false, "nope");

    glBindTexture(GL_TEXTURE_2D_ARRAY, tex.gl_handle);

    glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, index, tex.width, tex.height, 1, glformat, GL_UNSIGNED_BYTE, buffer);

    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glBindTexture(tex.gl_target, 0);

    debug check_gl_error();
}

final enum TextureFilter
{
    Nearest, // gl.GL_NEAREST
    Linear, // gl.GL_LINEAR
    MipMap, // gl.GL_LINEAR_MIPMAP_LINEAR
    MipMapNearestNearest, // gl.GL_NEAREST_MIPMAP_NEAREST
    MipMapLinearNearest, // gl.GL_LINEAR_MIPMAP_NEAREST
    MipMapNearestLinear, // gl.GL_NEAREST_MIPMAP_LINEAR
    MipMapLinearLinear, // gl.GL_LINEAR_MIPMAP_LINEAR
}

final enum TextureWrap 
{
    MirroredRepeat, // gl.GL_MIRRORED_REPEAT
    ClampToEdge, // gl.GL_CLAMP_TO_EDGE
    Repeat, // gl.GL_REPEAT
}

final enum PixelFormat
{
    Alpha,
    Rgb,
    Rgba,
    Luminance,
    LuminanceAlpha
}
