import gfx;
import dbg;
import freetype;
import font;
import math;
import memory;
import texture;


FontAtlas ui_font;

FontAtlas result;


void main()
{
    create_engine(800, 600, &init, null, &tick);
}

void init(Engine* e)
{
    FontConfig conf = {
        file: "res/fonts/kreon-regular.ttf",
        size: 14,
        outline: true,
        outline_size: 1,
        color: Colorf.WHITE,
        color_outline: Colorf.BLACK,
        gradient: false,
    };
    ui_font = load(conf);
}

void tick(Engine* e, float dt)
{
    import bindbc.opengl;

    
    renderer.spritebatch.begin();

    renderer.spritebatch.draw(&ui_font.atlas,0,0,256,256);

    renderer.spritebatch.end();
}


FontAtlas load(FontConfig config)
{
    FontAtlas ret;

    FT_Library ft;
    FT_Face face;

    FT_Init_FreeType(&ft);

    if(!ft) panic("Can't init freetype");


    if (config.file_data.length > 0)
        FT_New_Memory_Face(ft, config.file_data.ptr, cast(int) config.file_data.length, 0, &face);
    else
        FT_New_Face(ft, config.file.ptr, 0, &face);

    

    if(!face) panic("Can't load font: %s", config.file.ptr);

    bool has_kerning = FT_HAS_KERNING(face);

    LINFO("Font {} has kerning data", config.file.ptr);

    //enum DPI = 72;
    //enum DPI = 96;
    //FT_Set_Char_Size(face, 0, size << 6, DPI, DPI);
    FT_Set_Pixel_Sizes(face, 0, config.size);

    ret.atlas_width = 0;
    ret.atlas_height = 0;

    enum TMP_SIZE = 512;

    float invTexWidth = 1.0f / TMP_SIZE;
    float invTexHeight = 1.0f / TMP_SIZE;
    int ps = TMP_SIZE * TMP_SIZE * 4;
    ubyte* pngData = cast(ubyte*) malloc(ps);
    memset(pngData, 0, ps);

    enum PADDING = 4;
    int penx = PADDING;
    int peny = PADDING;

    for (int i = 32; i < NUM_GLYPHS; i++)
    {
        auto index = FT_Get_Char_Index(face, i);
        FT_Load_Glyph(face, index, FT_LOAD_RENDER);


        FT_Bitmap* bitmap = &face.glyph.bitmap;

        int width =  bitmap.width;
        int height = bitmap.rows;


        width += (config.outline_size * 2);
        height += (config.outline_size * 2);

        
        if ((penx + width + PADDING) >= TMP_SIZE)
        {
            penx = PADDING;
            peny += ((face.size.metrics.height >> 6) + 1) + (config.outline_size * 2);
        }

        ubyte get_pixel_a(int x, int y)
        {
            int pi = y * TMP_SIZE + x;
            return pngData[pi * 4 + 3];
        }
        void set_pixel(int x, int y, ubyte r, ubyte g, ubyte b, ubyte a)
        {
            if (x < 0 || y < 0) return;
            if (x >= TMP_SIZE || y >= TMP_SIZE) return;
            
            int pi = y * TMP_SIZE + x;
            pngData[pi * 4 + 0] |= r;
            pngData[pi * 4 + 1] |= g;
            pngData[pi * 4 + 2] |= b;
            pngData[pi * 4 + 3] |= a;
        }

        void apply(ubyte* source, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
        {
            ubyte r = cast(ubyte) (config.color.r * 255);
            ubyte g = cast(ubyte) (config.color.g * 255);
            ubyte b = cast(ubyte) (config.color.b * 255);
            ubyte a = cast(ubyte) (config.color.a * 255);
            
            for (int row = 0; row < h; ++row)
            {
                for (int col = 0; col < w; ++col)
                {
                    int x = tox + col;
                    int y = toy + row;
                    auto p = source[row * pitch + col];
                    int pfi = y * TMP_SIZE + x;
                    if(p > 0)
                    {

                        // if outline, blend the colors
                        if(config.outline)
                        {
                            ubyte[4] tmp = [r, g, b, p];
                            blend(
                                pngData[pfi * 4 .. pfi * 4 + 4],
                                tmp,
                                pngData[pfi * 4 .. pfi * 4 + 4],
                            );
                        }
                        else
                            set_pixel(x, y, r, g, b, p);
                    }
                }
            }
        }
        
        void apply_gradient(ubyte* source, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
        {
            ubyte r = cast(ubyte) (config.color.r * 255);
            ubyte g = cast(ubyte) (config.color.g * 255);
            ubyte b = cast(ubyte) (config.color.b * 255);
            ubyte a = cast(ubyte) (config.color.a * 255);

            float step = (config.mid - config.top) / (h/2f);
            float mult = config.top;
            float midY = h / 2f;
            
            for (int row = 0; row < midY; ++row)
            {
                for (int col = 0; col < w; ++col)
                {
                    int x = tox + col;
                    int y = toy + row;
                    auto p = source[row * pitch + col];
                    int pfi = y * TMP_SIZE + x;
                    if(p > 0)
                    {
                        //float percent = 1 - row / cast(float)h;
                        float percent = mult;

                        // if outline, blend the colors
                        if(config.outline)
                        {
                            ubyte[4] tmp = [cast(ubyte) (r * percent), cast(ubyte) (g * percent), cast(ubyte) (b * percent), p];
                            blend(
                                pngData[pfi * 4 .. pfi * 4 + 4],
                                tmp,
                                pngData[pfi * 4 .. pfi * 4 + 4],
                            );
                        }
                        else
                            set_pixel(x, y, r, g, b, p);

                    }
                }
                mult += step;
            }

            step = (config.bottom - config.mid) / (h - midY);
            mult = config.mid;
            for (int row = cast(int)midY; row < h; ++row)
            {
                for (int col = 0; col < w; ++col)
                {
                    int x = tox + col;
                    int y = toy + row;
                    auto p = source[row * pitch + col];
                    int pfi = y * TMP_SIZE + x;
                    if(p > 0)
                    {
                        //float percent = 1 - row / cast(float)h;
                        float percent = mult;

                        // if outline, blend the colors
                        if(config.outline)
                        {
                            ubyte[4] tmp = [cast(ubyte) (r * percent), cast(ubyte) (g * percent), cast(ubyte) (b * percent), p];
                            blend(
                                pngData[pfi * 4 .. pfi * 4 + 4],
                                tmp,
                                pngData[pfi * 4 .. pfi * 4 + 4],
                            );
                        }
                        else
                            set_pixel(x, y, r, g, b, p);

                    }
                }
                mult += step;
            }
        }

        void apply_outline(ubyte* source, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
        {
            ubyte r = cast(ubyte) (config.color_outline.r * 255);
            ubyte g = cast(ubyte) (config.color_outline.g * 255);
            ubyte b = cast(ubyte) (config.color_outline.b * 255);
            ubyte a = cast(ubyte) (config.color_outline.a * 255);

            for(int ox = -config.outline_size; ox <= config.outline_size; ox++)
            for(int oy = -config.outline_size; oy <= config.outline_size; oy++)
            {
                for (int row = 0; row < h; ++row)
                {
                    for (int col = 0; col < w; ++col)
                    {
                        int x = tox + col + ox + config.outline_size;
                        int y = toy + row + oy + config.outline_size;
                        auto p = source[row * pitch + col];
                        int pfi = y * TMP_SIZE + x;

                        if(p > 0)
                        {
                            //ubyte[4] tmp = [0, 0, 0, p];
                            //blend(
                            //	pngData[pfi * 4 .. pfi * 4 + 4],
                            //	tmp,
                            //	pngData[pfi * 4 .. pfi * 4 + 4],
                            //);
                            set_pixel(x, y, r, g, b, p );
                        }
                    }
                }
            }
        }

        apply(bitmap.buffer, bitmap.pitch, bitmap.width, bitmap.rows, penx + config.outline_size, peny + config.outline_size, &width, &height);
        
        if(config.gradient)
            apply_gradient(bitmap.buffer, bitmap.pitch, bitmap.width, bitmap.rows, penx + config.outline_size, peny + config.outline_size, &width, &height);
        

        if(config.outline)
            apply_outline(bitmap.buffer, bitmap.pitch, bitmap.width, bitmap.rows, penx, peny, &width, &height);
        

        auto info = &ret.glyphs[i];
        info.width =   cast(ubyte) width;
        info.height =  cast(ubyte) height;

        info.advance = cast(byte) ( (face.glyph.metrics.horiAdvance >> 6) + config.outline_size);
        
        info.id = index;
        info.character = cast(char) i;
        info.brearing_x = cast(byte)( face.glyph.bitmap_left + config.outline_size );
        info.brearing_y = cast(byte)( face.glyph.bitmap_top + config.outline_size );

        info.u = penx * invTexWidth;
        info.v = peny * invTexWidth;
        info.u2 = (penx + info.width) * invTexWidth;
        info.v2 = (peny + info.height) * invTexHeight;

        if(has_kerning)
        {
            for(int j = 32; j < NUM_GLYPHS; j++)
            {
                byte kx;
                byte ky;
                get_kerning(face, i, j, &kx, &ky);
                info.kerning_value[j] = kx;
            }
        }


        if(i == ' ')
        {
            ret.space_x_advance = info.advance;
            info.width = info.advance;
            info.u2 = (penx + info.width) * invTexWidth;
            info.v2 = (peny + info.height) * invTexHeight;
        }

        if(i == 'x')
        {
            ret.x_height = cast(int) (face.glyph.metrics.height >> 6);
            LINFO("Found x height: {}", ret.x_height);
        }
        if(i == 'X')
        {
            ret.cap_height = cast(int) (face.glyph.metrics.height >> 6);
            LINFO("Found cap height: {}", ret.cap_height);
        }
        penx += info.width + 1; 
    }
    
    ret.line_height = cast(int) roundf( (face.size.metrics.height >> 6) + (config.outline_size) );
    ret.ascent = cast(int) (face.size.metrics.descender >> 6);
    ret.descent = cast(int) (face.size.metrics.ascender >> 6);

    ret.ascent -= ret.cap_height;
    ret.down = -ret.line_height;

    ret.atlas = create_texture(TMP_SIZE, TMP_SIZE, pngData);
    ret.atlas_width = TMP_SIZE;
    ret.atlas_height = TMP_SIZE;

    // import dawn.image;
    // write_image("font.png", TMP_SIZE, TMP_SIZE,  pngData [0 ..TMP_SIZE*TMP_SIZE * 4]);

    free(pngData);
    FT_Done_FreeType(ft);


    LINFO("Loaded font atlas of size: {}:{} lineHeight: {} ascent: {} descent: {} capHeight: {}, xHeight: {}",
        TMP_SIZE, TMP_SIZE, ret.line_height, ret.ascent, ret.descent, ret.cap_height, ret.x_height);
    version(CHECK_GL) check_gl_error(false);

    return ret;
}

struct FontConfig
{
	string file;
	int size;
	Colorf color;

	bool outline;
	int outline_size;
	Colorf color_outline;

	bool gradient;
	float top = 1;
	float mid = 1;
	float bottom = 0.7;

	ubyte[] file_data;
}

void blend(ubyte[] result, ubyte[] fg, ubyte[] bg)
{
    uint alpha = fg[3] + 1;
    uint inv_alpha = 256 - fg[3];
    result[0] = cast(ubyte)((alpha * fg[0] + inv_alpha * bg[0]) >> 8);
    result[1] = cast(ubyte)((alpha * fg[1] + inv_alpha * bg[1]) >> 8);
    result[2] = cast(ubyte)((alpha * fg[2] + inv_alpha * bg[2]) >> 8);
    result[3] = 0xff;
}

private void get_kerning(FT_Face face, int a, int b, byte* x, byte* y)
{
	FT_Vector vec = {};
	FT_Get_Kerning(
			face,
			FT_Get_Char_Index(face, a),
			FT_Get_Char_Index(face, b),
			FT_Kerning_Mode.FT_KERNING_DEFAULT,
			&vec
	);
	*x = cast(byte)(vec.x >> 6);
	*y = cast(byte)(vec.y >> 6);
}