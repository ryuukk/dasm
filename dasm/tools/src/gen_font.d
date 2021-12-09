import rt.dbg;
import rt.math;
import rt.memory;

import freetype;

import dawn.gfx;
import dawn.renderer;
import dawn.font;
import dawn.texture;

import mu = dawn.microui;

mu.Context* ui_ctx;

FontCache ui_fc;
FontAtlas ui_font;

FontAtlas result_font;
FontCache result_fc;

char[256] out_dat_pat = "res/fonts/font.dat";
char[256] out_tex_path = "res/fonts/font.png";

char[256] test_text = "This is a test!";

ubyte* png_data;

FontConfig conf = {
    file: "res/fonts/kreon-regular.ttf",
    size: 32,
    outline: true,
    outline_size: 2,
    color: Colorf.WHITE,
    color_outline: Colorf.BLACK,
    gradient: true,
};

void main()
{
    create_engine(1280, 720, &init, null, &tick);
}

void init(Engine* e)
{
    FontConfig uiConf = {
        file: "res/fonts/kreon-regular.ttf",
        size: 14,
        outline: true,
        outline_size: 1,
        color: Colorf.WHITE,
        color_outline: Colorf.BLACK,
        gradient: false,
    };
    ui_font = load(uiConf);

    ui_fc.create(&ui_font, false);

    result_font = load(conf);
    result_fc.create(&result_font, false);

    ui_ctx = e.allocator.create_noinit!(mu.Context);
    mu.init(ui_ctx);

    ui_ctx.style.font = cast(mu.Font) &ui_fc;
    ui_ctx.text_width = &text_width;
    ui_ctx.text_height = &text_height;

    assert(ui_ctx.text_width);
    assert(ui_ctx.text_height);
}

void tick(Engine* e, float dt)
{
    auto batch = &e.renderer.spritebatch;
    batch.begin();
    batch.draw_rect(8,8, result_font.atlas_width, result_font.atlas_height);
    batch.draw(&result_font.atlas,8,8, result_font.atlas_width, result_font.atlas_height);
    batch.end();

    result_fc.clear();
    result_fc.add_text(test_text, 8, e.height);

    batch.begin();
    ui_fc.draw(batch);
    batch.end();

    batch.begin();
    result_fc.draw(batch);
    batch.end();

    process_ui(ui_ctx);

    mu.begin(ui_ctx);
    make_ui();
    mu.end(ui_ctx);

    render_ui(ui_ctx, &ui_fc, batch);
}

void make_ui()
{
    enum W = 300;
    int H = engine.iheight - 16;
    auto x = engine.iwidth  - W - 8;
    auto y = 8;
    if (mu.begin_window_ex(ui_ctx, "Font Gen", mu.rect(x, y, W, H), mu.OPT_NOCLOSE))
    {
        mu.Container* win = mu.get_current_container(ui_ctx);
        win.rect.w = mu.max(win.rect.w, 300);
        win.rect.h = mu.max(win.rect.h, 240);

        mu.layout_row(ui_ctx, [120, -1], 0);

        // font path
        mu.label(ui_ctx, "font path");
        mu.textbox(ui_ctx, out_dat_pat.ptr, out_dat_pat.length);

        // tex path
        mu.label(ui_ctx, "tex path");
        mu.textbox(ui_ctx, out_tex_path.ptr, out_tex_path.length);

        // font size
        mu.label(ui_ctx, "size");
        float f = cast(float) conf.size;
        mu.slider(ui_ctx, &f, 1, 72);
        conf.size = cast(int)f;

        // font outline
        mu.layout_row(ui_ctx, [-1], 0);
        mu.checkbox(ui_ctx, "outline", &conf.outline);
        if (conf.outline)
        {
            mu.layout_row(ui_ctx, [120, -1], 0);
            mu.label(ui_ctx, "outline size");
            float fo = cast(float) conf.outline_size;
            mu.slider(ui_ctx, &fo, 1, 72);
            conf.outline_size = cast(int)fo;

            // TODO: outline color
        }

        // font gradient
        mu.layout_row(ui_ctx, [-1], 0);
        mu.checkbox(ui_ctx, "gadient", &conf.gradient);
        if (conf.gradient)
        {
            // TODO: more gradient settings
            //  - color
            //  - orientation
        }

        mu.layout_row(ui_ctx, [-1], 40);
        mu.draw_box(ui_ctx, mu.Rect(0,0,32,32), mu.color(Color.CHARTREUSE.tupleof));

        // buttons
        mu.layout_row(ui_ctx, [-1], 40);
        if(mu.button(ui_ctx, "Generate"))
        {
            LINFO("generate font");
            result_font = load(conf);
        }

        mu.layout_row(ui_ctx, [-1], 40);
        if(mu.button(ui_ctx, "Export"))
        {
            LINFO("export font");
            export_font();
        }
        mu.layout_row(ui_ctx, [-1], -1);
        mu.textbox(ui_ctx, test_text.ptr, test_text.length);

        mu.end_window(ui_ctx);
    }
}

void export_font()
{
    import rt.filesystem;
    import rt.readers;

    OutputFile file;
    if (!file.open(cast(string) out_dat_pat))
        LERRO("can't open file: {}", out_dat_pat);
    scope(exit) file.close();

    ubyte[4096] buffer = 0;

    PWriter writer;
    writer.buffer = buffer;

    // version
    writer.write_byte(1);

    // info
    writer.write_int(result_font.line_height);
    writer.write_int(result_font.ascent);
    writer.write_int(result_font.descent);
    writer.write_int(result_font.space_x_advance);
    writer.write_int(result_font.down);
    writer.write_int(result_font.x_height);
    writer.write_int(result_font.cap_height);

    // glyphs
    writer.write_int(NUM_GLYPHS);
    foreach (ref g; result_font.glyphs)
    {
        writer.write_uint(g.id);
        writer.write_int(g.character);
        writer.write_ubyte(g.width);
        writer.write_ubyte(g.height);
        writer.write_byte(g.brearing_x);
        writer.write_byte(g.brearing_y);
        writer.write_byte(g.advance);
        writer.write_float(g.u);
        writer.write_float(g.v);
        writer.write_float(g.u2);
        writer.write_float(g.v2);

        // for kernings length
        auto kpos = writer.position;
        writer.write_byte(0);
        ubyte num_k = 0;
        foreach(c, k; g.kerning_value)
        {
            if (k != 0)
            {
                writer.write_int(cast(int)c);
                writer.write_byte(k);
                num_k++;
            }
        }
        auto cpos = writer.position;
        writer.position = kpos;
        writer.write_ubyte(num_k);
        writer.position = cpos;
    }

    writer.write_int(result_font.atlas_width);
    writer.write_int(result_font.atlas_height);


    file.write(buffer.ptr, writer.position);
    file.flush();

    import img = dawn.image;

    LINFO("saving texture to {}", out_tex_path);
    auto err = img.write_image(out_tex_path, TMP_SIZE, TMP_SIZE, png_data[0 .. TMP_SIZE*TMP_SIZE * 4]);
    if (err != 0)
        LERRO("can't export texture {}", img.IF_ERROR[err]);
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

// TODO: compute desired texture size automatically
enum TMP_SIZE = 512;

FontAtlas load(FontConfig config)
{
    FontAtlas ret;

    FT_Library ft;
    FT_Face face;

    FT_Init_FreeType(&ft);

    if(!ft) panic("can't init freetype");


    if (config.file_data.length > 0)
        FT_New_Memory_Face(ft, config.file_data.ptr, cast(int) config.file_data.length, 0, &face);
    else
        FT_New_Face(ft, config.file.ptr, 0, &face);

    

    if(!face) panic("can't load font: %s", config.file.ptr);

    bool has_kerning = FT_HAS_KERNING(face);

    LINFO("font {} has kerning data", config.file.ptr);
    LINFO("size: {}", config.size);

    //enum DPI = 72;
    //enum DPI = 96;
    //FT_Set_Char_Size(face, 0, size << 6, DPI, DPI);
    FT_Set_Pixel_Sizes(face, 0, config.size);

    ret.atlas_width = 0;
    ret.atlas_height = 0;

    float invTexWidth = 1.0f / TMP_SIZE;
    float invTexHeight = 1.0f / TMP_SIZE;
    int ps = TMP_SIZE * TMP_SIZE * 4;

    if (png_data)
        free(png_data);
    png_data = cast(ubyte*) malloc(ps);
    memset(png_data, 0, ps);

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

        apply(&config, bitmap.buffer, png_data, bitmap.pitch, bitmap.width, bitmap.rows, penx + config.outline_size, peny + config.outline_size, &width, &height);
        
        if(config.gradient)
            apply_gradient(&config, bitmap.buffer, png_data, bitmap.pitch, bitmap.width, bitmap.rows, penx + config.outline_size, peny + config.outline_size, &width, &height);
        

        if(config.outline)
            apply_outline(&config, bitmap.buffer, png_data, bitmap.pitch, bitmap.width, bitmap.rows, penx, peny, &width, &height);
        

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
            LINFO("found x height: {}", ret.x_height);
        }
        if(i == 'X')
        {
            ret.cap_height = cast(int) (face.glyph.metrics.height >> 6);
            LINFO("found cap height: {}", ret.cap_height);
        }
        penx += info.width + 1; 
    }
    
    ret.line_height = cast(int) roundf( (face.size.metrics.height >> 6) + (config.outline_size) );
    ret.ascent = cast(int) (face.size.metrics.descender >> 6);
    ret.descent = cast(int) (face.size.metrics.ascender >> 6);

    ret.ascent -= ret.cap_height;
    ret.down = -ret.line_height;

    ret.atlas = create_texture(TMP_SIZE, TMP_SIZE, png_data);
    ret.atlas_width = TMP_SIZE;
    ret.atlas_height = TMP_SIZE;

    // import dawn.image;
    // write_image("font.png", TMP_SIZE, TMP_SIZE,  pngData [0 ..TMP_SIZE*TMP_SIZE * 4]);

    // free(pngData);
    FT_Done_FreeType(ft);


    LINFO("loaded font atlas of size: {}:{} lineHeight: {} ascent: {} descent: {} capHeight: {}, xHeight: {}",
        TMP_SIZE, TMP_SIZE, ret.line_height, ret.ascent, ret.descent, ret.cap_height, ret.x_height);
    version(CHECK_GL) check_gl_error(false);

    return ret;
}


ubyte get_pixel_a(ubyte* pngData, int x, int y)
{
    int pi = y * TMP_SIZE + x;
    return pngData[pi * 4 + 3];
}

void set_pixel(ubyte* pngData, int x, int y, ubyte r, ubyte g, ubyte b, ubyte a)
{
    if (x < 0 || y < 0) return;
    if (x >= TMP_SIZE || y >= TMP_SIZE) return;
    
    int pi = y * TMP_SIZE + x;
    pngData[pi * 4 + 0] |= r;
    pngData[pi * 4 + 1] |= g;
    pngData[pi * 4 + 2] |= b;
    pngData[pi * 4 + 3] |= a;
}

// TODO: apply_* use a struct instead of an endless number of parameters..

void apply(FontConfig* config, ubyte* source, ubyte* pngData, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
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
                    set_pixel(pngData, x, y, r, g, b, p);
            }
        }
    }
}

void apply_gradient(FontConfig* config, ubyte* source, ubyte* pngData, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
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
                    set_pixel(pngData, x, y, r, g, b, p);

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
                    set_pixel(pngData, x, y, r, g, b, p);

            }
        }
        mult += step;
    }
}

void apply_outline(FontConfig* config, ubyte* source, ubyte* pngData, int pitch, int w, int h, int tox, int toy, int* outW, int* outH)
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
                    set_pixel(pngData, x, y, r, g, b, p );
                }
            }
        }
    }
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