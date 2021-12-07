module dawn.font;
version(DESKTOP) :

import rt.math;
import rt.dbg;
import rt.memory;

import freetype;
import dawn.texture;

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