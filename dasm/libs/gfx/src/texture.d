module texture;

import dbg;
import gl;

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
        
    void deinit()
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

    if(format == PixelFormat.Alpha)
        glTexImage2D(target, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, ptr);
    else if (format == PixelFormat.Rgba)
        glTexImage2D(target, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, ptr);
    else assert(false, "nope");



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