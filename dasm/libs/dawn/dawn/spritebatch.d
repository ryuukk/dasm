module dawn.spritebatch;

import dawn.texture;
import dawn.gl;
import dawn.mesh;
import dawn.gfx;
import dawn.renderer: BlendState;

import rt.dbg;
import rt.math;
import rt.memz;


struct SpriteBatch
{
    enum COUNT = 5000;
    private Mesh _mesh;

    private float[] _vertices;
    private int _idx;
    private uint _lastTextureHandle;
    private float _invTexWidth;
    private float _invTexHeight;

    private bool _drawing;

    private mat4 _transformMatrix = mat4.identity();
    private mat4 _projectionMatrix = mat4.identity();

    BlendState blend_state = BlendState.AlphaBlend;

    private ShaderProgram _shader;
    ShaderProgram* custom_shader = null;
    private bool _ownsShader;

    Color color = Color.WHITE;

    int renderCalls = 0;
    int totalRenderCalls = 0;
    int maxSpritesInBatch = 0;

    Texture2D pixel;

    void create(Engine* engine)
    {
        //assert(size < 8191, "spritebatch too big");

        _vertices = MALLOCATOR.alloc_array!float(COUNT * 20);

        auto attrs = VertexAttributes();
        attrs.add(VertexAttribute.position2D());
        attrs.add(VertexAttribute.color_packed());
        attrs.add(VertexAttribute.tex_coords(0));


        _mesh.create(false, COUNT * 4, COUNT * 6, attrs);
    
        _projectionMatrix = mat4.create_orthographic_offcenter(0f, 0f, engine.width, engine.height);

        for (int i = 0; i < _vertices.length; i++)
            _vertices[i] = 0f;

        int len = COUNT * 6;
        int[] indices = MALLOCATOR.alloc_array!int(len);
        scope(exit) MALLOCATOR.base.free(indices.ptr);
        
        int j = 0;
        for (int i = 0; i < len; i += 6, j += 4)
        {
            indices[i + 0] = j;
            indices[i + 1] = (j + 1);
            indices[i + 2] = (j + 2);
            indices[i + 3] = (j + 2);
            indices[i + 4] = (j + 3);
            indices[i + 5] =  j;
        }
        _mesh.ib.set_data(indices, 0, cast(uint) indices.length);

        //if (defaultShader is null)
        //{
            _shader = ShaderProgram();
            _shader.create(vs, fs);
            assert(_shader.is_compiled);
            _ownsShader = true;
        //}
        //else
        //    _shader = defaultShader;

        ubyte[4] tmp = [0xff, 0xff, 0xff, 0xff];
        pixel = create_texture(1,1, tmp.ptr);
    }

    void set_proj(const ref mat4 projection)
    {
        assert(!_drawing, "must call end");
        _projectionMatrix = projection;
    }

    void begin()
    {
        assert(!_drawing, "must call end");
        renderCalls = 0;

        if(custom_shader != null)
            custom_shader.bind();
        else
            _shader.bind();

        setup_matrices();
        _drawing = true;
    }

    void end()
    {
        assert(_drawing, "must call begin");
        if (_idx > 0)
            flush();
        _lastTextureHandle = 0;
        _drawing = false;
    }

    void flush()
    {
        if (_idx == 0)
            return;
            
        engine.renderer.state.set_blend_state(blend_state);

        renderCalls++;
        totalRenderCalls++;

        int spritesInBatch = _idx / 20;
        if (spritesInBatch > maxSpritesInBatch)
            maxSpritesInBatch = spritesInBatch;
        int count = spritesInBatch * 6;

        glBindTexture(GL_TEXTURE_2D, _lastTextureHandle);
        //_lastTexture.bind();
        _mesh.vb.set_data(_vertices, 0, _idx);


        if(custom_shader != null)
            _mesh.render(custom_shader, GL_TRIANGLES, 0, count, true);
        else
            _mesh.render(&_shader, GL_TRIANGLES, 0, count, true);

        _idx = 0;
    }

    private void setup_matrices()
    {
        _shader.set_uniform_mat4("u_proj", _projectionMatrix);
        _shader.set_uniform_mat4("u_trans", _transformMatrix);
        _shader.set_uniformi("u_texture", 0);
    }

    private void switch_tex(Texture2D* texture)
    {
        flush();
        _lastTextureHandle = texture.gl_handle;
        _invTexWidth = 1.0f / texture.width;
        _invTexHeight = 1.0f / texture.height;
    }

    void draw(Texture2D* texture, float[] v, uint offset, uint count)
    {
        auto verticesLength = cast(int) _vertices.length;
        auto remainingVertices = verticesLength;
        if(texture.gl_handle != _lastTextureHandle)
            switch_tex(texture);
        else
        {
            remainingVertices -= _idx;
            if(remainingVertices == 0)
            {
                flush();
                remainingVertices = verticesLength;
            }
        }

        int copyCount = min(remainingVertices, count);
        //arraycopy(src, srcPos,dest,destPos, length)
		//arraycopy(spriteVertices, offset, vertices, idx, copyCount);
        _vertices[_idx .. _idx + copyCount] = v[offset .. copyCount];

        _idx += copyCount;
        count -= copyCount;
        while(count > 0)
        {
            offset += copyCount;
            flush();
            copyCount = min(verticesLength, count);

            //arraycopy(spriteVertices, offset, vertices, 0, copyCount);
            _vertices[0 .. copyCount] = v[offset .. copyCount];

            _idx += copyCount;
            count -= copyCount;
        }
    }

    void draw(Texture2D* texture, float x, float y, float width, float height, bool upside = false)
    {
        assert(_drawing, "must call begin");

        if (texture.gl_handle != _lastTextureHandle)
            switch_tex(texture);
        else if (_idx == _vertices.length) //
            flush();

        float x2 = x + width;
        float y2 = y + height;
        float u = 0;
        float v = 1;
        float u2 = 1;
        float v2 = 0;

        if(upside)
        {
            u = 0;
            v = 0;
            u2 = 1;
            v2 = 1;
        }

        float fint = color.to_float_bits();

        int idx = _idx;
        _vertices[idx + 0] = x;
        _vertices[idx + 1] = y;
        _vertices[idx + 2] = fint;
        _vertices[idx + 3] = u;
        _vertices[idx + 4] = v;

        _vertices[idx + 5] = x2;
        _vertices[idx + 6] = y;
        _vertices[idx + 7] = fint;
        _vertices[idx + 8] = u2;
        _vertices[idx + 9] = v;

        _vertices[idx + 10] = x2;
        _vertices[idx + 11] = y2;
        _vertices[idx + 12] = fint;
        _vertices[idx + 13] = u2;
        _vertices[idx + 14] = v2;

        _vertices[idx + 15] = x;
        _vertices[idx + 16] = y2;
        _vertices[idx + 17] = fint;
        _vertices[idx + 18] = u;
        _vertices[idx + 19] = v2;

        _idx = idx + 20;
    }

	void draw (Texture2D* texture,
        ref Rectf region,
        float x, float y,
        float originX, float originY,
        float width, float height,
	    float scaleX, float scaleY, float rotation) 
    {
        if (texture.gl_handle != _lastTextureHandle) {
			switch_tex(texture);
		} else if (_idx == _vertices.length) //
			flush();

		// bottom left and top right corner points relative to origin
		float worldOriginX = x + originX;
		float worldOriginY = y + originY;
		float fx = -originX;
		float fy = -originY;
		float fx2 = width - originX;
		float fy2 = height - originY;

		// scale
		if (scaleX != 1 || scaleY != 1) {
			fx *= scaleX;
			fy *= scaleY;
			fx2 *= scaleX;
			fy2 *= scaleY;
		}

		// construct corner points, start from top left and go counter clockwise
		float p1x = fx;
		float p1y = fy;
		float p2x = fx;
		float p2y = fy2;
		float p3x = fx2;
		float p3y = fy2;
		float p4x = fx2;
		float p4y = fy;
		float x1;
		float y1;
		float x2;
		float y2;
		float x3;
		float y3;
		float x4;
		float y4;

		// rotate
		if (rotation != 0) {
            rotation = -rotation;
			float cos = cosf(rotation);
			float sin = sinf(rotation);

			x1 = cos * p1x - sin * p1y;
			y1 = sin * p1x + cos * p1y;

			x2 = cos * p2x - sin * p2y;
			y2 = sin * p2x + cos * p2y;

			x3 = cos * p3x - sin * p3y;
			y3 = sin * p3x + cos * p3y;

			x4 = x1 + (x3 - x2);
			y4 = y3 - (y2 - y1);
		} else {
			x1 = p1x;
			y1 = p1y;

			x2 = p2x;
			y2 = p2y;

			x3 = p3x;
			y3 = p3y;

			x4 = p4x;
			y4 = p4y;
		}

		x1 += worldOriginX;
		y1 += worldOriginY;
		x2 += worldOriginX;
		y2 += worldOriginY;
		x3 += worldOriginX;
		y3 += worldOriginY;
		x4 += worldOriginX;
		y4 += worldOriginY;


        float invTexWidth = 1.0f / texture.width;
        float invTexHeight = 1.0f / texture.height;

		float u = region.x * invTexWidth;
		float v = (region.y + region.height) * invTexHeight;
		float u2 = (region.x + region.width) * invTexWidth;
		float v2 = region.y * invTexHeight;

        float color = this.color.to_float_bits();
		int idx = _idx;
        _vertices[idx + 0] = x1;
		_vertices[idx + 1] = y1;
		_vertices[idx + 2] = color;
		_vertices[idx + 3] = u;
		_vertices[idx + 4] = v;

		_vertices[idx + 5] = x4;
		_vertices[idx + 6] = y4;
		_vertices[idx + 7] = color;
		_vertices[idx + 8] = u2;
		_vertices[idx + 9] = v;

		_vertices[idx + 10] = x3;
		_vertices[idx + 11] = y3;
		_vertices[idx + 12] = color;
		_vertices[idx + 13] = u2;
		_vertices[idx + 14] = v2;

		_vertices[idx + 15] = x2;
		_vertices[idx + 16] = y2;
		_vertices[idx + 17] = color;
		_vertices[idx + 18] = u;
		_vertices[idx + 19] = v2;
		_idx = idx + 20;
    }

    void draw_line(float x, float y, float x2, float y2)
    {
        float angle = atan2f(y2 - y, x2 - x);
        float dst = dst(x, y, x2, y2);

        draw(&pixel, Rectf(0,0,1,1), x, y, 0,0, dst, 1, 1, 1, angle);
    }

    void draw_line2(float x, float y, float angle, float length)
    {
        draw(&pixel, Rectf(0,0,1,1), x, y, 0,0, length, 1, 1, 1, angle);
    }


    void sonofbitcher(float x, float y, float angle, float length)
    {
        draw(&pixel, Rectf(0,0,1,1), x, y, 0,0, length, 1, 1, 1, angle);
    }

    void draw_rect(Rectf rect)
    {
        draw_rect(rect.tupleof);
    }
    void draw_rect(float x, float y, float width, float height)
    {
        // _
        draw_line(x, y              , x + width, y);
        draw_line(x, y + height, x + width, y + height);

        // |
        draw_line(x, y, x      , y + height);
        draw_line(x + width, y , x + width, y + height);
    }
    
    void draw_rect_filled(float x, float y, float w, float h)
    {
        draw(&pixel, x, y, w, h);
    }
    
    void draw_rect_d(Rectf rect)
    {
        // _
        draw_line(rect.x, rect.y, rect.x + rect.width, rect.y);
        draw_line(rect.x, rect.y - rect.height, rect.x + rect.width, rect.y - rect.height);

        // |
        draw_line(rect.x, rect.y, rect.x, rect.y - rect.height);
        draw_line(rect.x + rect.width, rect.y, rect.x + rect.width, rect.y - rect.height);
    }
    

    void set_color(ubyte r, ubyte g, ubyte b, ubyte a)
    {
        color.r = r;
        color.g = g;
        color.b = b;
        color.a = a;
    }
    void set_color(float r, float g, float b, float a)
    {
        color.r = cast(ubyte) (r * 255);
        color.g = cast(ubyte) (g * 255);
        color.b = cast(ubyte) (b * 255);
        color.a = cast(ubyte) (a * 255);
    }

    void set_projection(in mat4 m)
    {
        _projectionMatrix = m;
    }
}



enum vs = `#version 300 es
#ifdef GL_ES
precision lowp float;
#endif

in vec4 a_position;
in vec4 a_color;
in vec2 a_texCoord0;

uniform mat4 u_proj;
uniform mat4 u_trans;

out vec4 v_color;
out vec2 v_texCoords;

void main() {
    v_color = a_color;
    v_color.a = v_color.a * (255.0/254.0);
    v_texCoords = a_texCoord0;
    gl_Position = u_proj * u_trans * a_position;
}
`
;
enum fs = `#version 300 es
#ifdef GL_ES
precision lowp float;
#endif

in vec4 v_color;
in vec2 v_texCoords;

uniform sampler2D u_texture;

out vec4 f_color;

void main() {
    f_color = v_color * texture(u_texture, v_texCoords);
    //if(f_color.a == 0) discard;
}
`
;