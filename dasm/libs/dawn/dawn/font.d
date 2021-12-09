module dawn.font;

import rt.math;
import rt.dbg;
import rt.memory;

import dawn.texture;
import dawn.spritebatch;

enum NUM_GLYPHS = 128;

struct GlyphInfo
{
	uint id;
	char character;
	ubyte width;
	ubyte height;
	byte brearing_x;
	byte brearing_y;
	byte advance;

	float u = 0;
	float v = 0;
	float u2 = 0;
	float v2 = 0;

	byte[NUM_GLYPHS] kerning_value = 0;

	byte get_kerning(char ch)
	{
		if(ch < 0 || ch >= kerning_value.length) return 0;
		return kerning_value[ch];
	}
}


struct FontAtlas
{
	Texture2D atlas;
	GlyphInfo[NUM_GLYPHS] glyphs;
	int atlas_width;
	int atlas_height;

	int line_height;
	int ascent;
	int descent;
	int space_x_advance;
	int down;
	int x_height;
	int cap_height;

	float scale_x = 1.0;
	float scale_y = 1.0;
	bool enable_markup;


	void destroy()
	{
		atlas.dispose();
	}


	GlyphInfo* get_glyph(char c) return
	{
		if( c < 0 || c >= glyphs.length)
			return null;

		return &glyphs[c];
	}

	Rectf get_bounds(const char* str, int start, int end)
	{
		return get_bounds(cast(string) str[start .. end], start, end);
	}
	Rectf get_bounds(string str, int start, int end)
	{
		Rectf bounds = Rectf(0,0,0,0);

		int width = 0;
		GlyphInfo* lastGlyph = null;
		while (start < end) {
			char ch = str[start++];
			if (ch == '[' && enable_markup) {
				if (!(start < end && str[start] == '[')) { // non escaped '['
					while (start < end && str[start] != ']')
						start++;
					start++;
					continue;
				}
				start++;
			}
			lastGlyph = get_glyph(ch);
			if (lastGlyph != null) {
				width += lastGlyph.advance;
				break;
			}
		}
		while (start < end) {
			char ch = str[start++];
			if (ch == '[' && enable_markup) {
				if (!(start < end && str[start] == '[')) { // non escaped '['
					while (start < end && str[start] != ']')
						start++;
					start++;
					continue;
				}
				start++;
			}
			GlyphInfo* g = get_glyph(ch);
			if (g != null) {
				width += lastGlyph.get_kerning(ch);
				lastGlyph = g;
				width += g.advance;
			}
		}
		bounds.width = width * scale_x;
		bounds.height = cap_height;
		return bounds;
	}
}

enum HAlignment
{
	LEFT,
	CENTER,
	RIGHT
}

struct FontCache
{
	FontAtlas* font;
	float[] vertices;
	int idx;
	float x = 0;
	float y = 0;
	float color = 0;
	bool integer = true;
	int glyph_count;

	bool text_changed;
	float old_tint = 0;
	int chars_count;

	Rectf bounds = Rectf(0,0,0,0);

	void create(FontAtlas* font, bool integer)
	{
		this.font = font;
		this.integer = integer;
		color = old_tint = Color.WHITE.to_float_bits();
	}

	void set_pos(float x, float y)
	{
    	translate(x - this.x, y - this.y);
	}

	void translate(float xAmount, float yAmount)
	{
		if (xAmount == 0 && yAmount == 0)
			return;
		if (integer)
		{
			xAmount = roundf(xAmount);
			yAmount = roundf(yAmount);
		}
		x += xAmount;
		y += yAmount;
	}

	void set_tint(Color tint)
	{
		float floatTint = tint.to_float_bits();
		if (text_changed || old_tint != floatTint) {
			text_changed = false;
			old_tint = floatTint;
			//markup.tint(this, tint);
		}
	}

	void set_colors(float color, int start, int end)
	{
		//for (int i = start * 20 + 2, n = end * 20; i < n; i += 5)
		for (int i = start * 20 + 2, n = min(end * 20, idx); i < n; i += 5)
			vertices[i] = color;
	}

	void draw(SpriteBatch* batch)
	{
		batch.draw(&font.atlas, vertices, 0, idx);
	}

	void clear()
	{
		x = 0;
		y = 0;
		glyph_count = 0;
		chars_count = 0;
		idx = 0;
		//markup.clear();
	}
	Rectf add_text(char[] text, float x, float y)
	{
		import rt.str;

		auto l = str_len(text.ptr);
		return add_text(cast(string)text, x, y, 0, l);
	}
	Rectf add_text(string text, float x, float y)
	{
		return add_text(text, x, y, 0, cast(int) text.length);
	}

	Rectf add_text(string text, float x, float y, int start, int end)
	{
		require_sequence(text, start, end);

		// if(x < bounds.x) bounds.x = x;
		// if(y < bounds.y) bounds.y = y;

		y += font.ascent;

		bounds.width = add_to_cache(text, x, y, start, end);
		bounds.height = font.cap_height;

		return bounds;
	}
    
	int bindex_of(char[] text, char ch, int start)
	{
		import rt.str;
		int n = str_len(text.ptr);
		for (; start < n; start++)
			if (text[start] == ch) return start;
		return n;
	}
	
	Rectf add_multiline_text(string text, float x, float y, float alignmentWidth, int alignment)
	{
		import rt.str;

		auto length = str_len(text.ptr);

		require_sequence(text, 0, length);

		y += font.ascent;

		float maxWidth = 0;
		float startY = y;
		int start = 0;
		int numLines = 0;
		while (start < length) {
			int lineEnd = bindex_of(cast(char[]) text, '\n', start);
			float xOffset = 0;
			if (alignment != HAlignment.LEFT) {
				float lineWidth = font.get_bounds(text, start, lineEnd).width;
				xOffset = alignmentWidth - lineWidth;
				if (alignment == HAlignment.CENTER) xOffset /= 2;
			}
			float lineWidth = add_to_cache(text, x + xOffset, y, start, lineEnd);
			maxWidth = max(maxWidth, lineWidth);
			start = lineEnd + 1;
			y += font.ascent;
			numLines++;
		}
		bounds.width = maxWidth;
		bounds.height = font.cap_height + (numLines - 1) * font.line_height;

		return bounds;
	}

	void require_sequence(string text, int start, int end)
	{
        int newGlyphCount = font.enable_markup ? count_glyphs(text, start, end) : end - start;
        require(newGlyphCount);
	}

	void require(int glyphCount)
	{
		int vertexCount = idx + glyphCount * 20;

		if(!vertices)
		{
			auto mem = malloc(vertexCount * 4);
			vertices =	cast(float[])  mem[0 .. vertexCount * 4];
		}
		else
		{

            auto newSize = vertexCount * 4;
            if (vertices.length < vertexCount)
            {
                auto newmem = malloc(newSize);
                memcpy(newmem, vertices.ptr, vertices.length * 4);

                free(vertices.ptr);
                vertices = cast(float[]) newmem[0 .. newSize];

                //auto mem = realloc(vertices.ptr, vertexCount * 4);
			    //vertices =	cast(float[])  mem[0 .. vertexCount * 4];
            }

		}
	}

	int count_glyphs(string text, int start, int end)
	{
		int count = end - start;
		while (start < end)
		{
			char ch = text[start++];
			if (ch == '[')
			{
				count--;
				if (!(start < end && text[start] == '['))
				{
					// non escaped '['
					while (start < end && text[start] != ']')
					{
						start++;
						count--;
					}

					count--;
				}

				start++;
			}
		}
		return count;
	}

	float add_to_cache(string text, float x, float y, int start, int end)
	{
		float startX = x;
		GlyphInfo* lastGlyph = null;
		text_changed = start < end;
		if(font.scale_x == 1 && font.scale_y == 1)
		{
			while(start < end)
			{
				char ch = text[start++];
				if(ch == '[' && font.enable_markup)
				{
                	if(!(start < end && text[start] == '['))
					{
						not_implemented();
					}
					start++;
				}
				lastGlyph = font.get_glyph(ch);
				if(lastGlyph != null)
				{
					add_glyph(lastGlyph, x + lastGlyph.brearing_x, y + (lastGlyph.brearing_y - lastGlyph.height), lastGlyph.width, lastGlyph.height);
					x+= lastGlyph.advance;
					break;
				}
			}

			while(start < end)
			{
				auto ch = text[start++];
				if (ch == '[' && font.enable_markup)
				{
					if (!(start < end && text[start] == '['))
					{
						not_implemented();
					}

					start++;
				}

				auto g = font.get_glyph(ch);
				if (g != null)
				{
					x += lastGlyph.get_kerning(ch);
					lastGlyph = g;
					add_glyph(lastGlyph, x + g.brearing_x, y + (g.brearing_y - g.height), g.width, g.height);
					x += g.advance;
				}
			}
		}
		else
		{
			not_implemented();
		}

		return x - startX;
	}

	void add_glyph(GlyphInfo* glyph, float x, float y, float width, float height)
	{
		float x2 = x + width;
		float y2 = y + height;

		float u = glyph.u;
		float v = glyph.v2;
		float u2 = glyph.u2;
		float v2 = glyph.v;

		//float u = glyph.u;
		//float v = glyph.v;
		//float u2 = glyph.u2;
		//float v2 = glyph.v2;

		// if (!_glyphIndices.empty())
		// {
		// 	_glyphIndices[page].emplace_back(_glyphCount++);
		// }


		if (integer)
		{
			x = roundf(x);
			y = roundf(y);
			x2 = roundf(x2);
			y2 = roundf(y2);
		}

		int cur = idx;
		idx += 20;

		vertices[cur++] = x;
		vertices[cur++] = y;
		vertices[cur++] = color;
		vertices[cur++] = u;
		vertices[cur++] = v;

		vertices[cur++] = x;
		vertices[cur++] = y2;
		vertices[cur++] = color;
		vertices[cur++] = u;
		vertices[cur++] = v2;

		vertices[cur++] = x2;
		vertices[cur++] = y2;
		vertices[cur++] = color;
		vertices[cur++] = u2;
		vertices[cur++] = v2;

		vertices[cur++] = x2;
		vertices[cur++] = y;
		vertices[cur++] = color;
		vertices[cur++] = u2;
		vertices[cur] = v;

		chars_count++;
	}
}
