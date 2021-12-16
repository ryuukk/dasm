module world.tiles;

import rt.math;
import rt.dbg;
import rt.memz;
import rt.math;

import dawn.gfx;
import dawn.mesh;
import dawn.ecs;

import world.map;

struct Tile
{
    int x;
    int y;
    int type;
    int entity_id;
    int autotile_id;
}

enum CHUNK_SIZE = 128;
enum TILE_SIZE  = 1;

version = TEX_ARR;
struct Chunk
{
    // pos + norm + tex + index 
    version (TEX_ARR)
        enum NUM_VERTICES = 3 + 3 + 2 + 1;
    else
        enum NUM_VERTICES = 3 + 3 + 2;

    int chunkX;
    int chunkY;
    int worldX;
    int worldY;

    Mesh mesh;
    Material mat;
    bool dirty;
    float[] _vertices;
    int[] _indicies;
    int numVertices;
    Map* map;

    mat4 transform;

    void create(Map* map, int chunkX, int chunkY)
    {
        this.map = map;
        this.chunkX = chunkX;
        this.chunkY = chunkY;

        worldX = chunkX * CHUNK_SIZE * TILE_SIZE;
        worldY = chunkY * CHUNK_SIZE * TILE_SIZE;

        auto tiles = CHUNK_SIZE * CHUNK_SIZE;
        auto vertCount  = CHUNK_SIZE * CHUNK_SIZE * 4;
        auto indexCount = CHUNK_SIZE * CHUNK_SIZE * 6;
        numVertices = vertCount;

        _vertices = engine.allocator.alloc_array!float(vertCount * NUM_VERTICES);
        _indicies = engine.allocator.alloc_array!int(indexCount);

        _vertices[] = 0.0;
        _indicies[] = 0;

        int vOffset = 0;
        int iOffset = 0;
        for (int i = 0; i < tiles; i++)
        {
            // _indicies[iOffset + 0] = (2 + vOffset);
            // _indicies[iOffset + 1] = (0 + vOffset);
            // _indicies[iOffset + 2] = (1 + vOffset);
            
            // _indicies[iOffset + 3] = (1 + vOffset);
            // _indicies[iOffset + 4] = (3 + vOffset);
            // _indicies[iOffset + 5] = (2 + vOffset);

            _indicies[iOffset + 0] = (0 + vOffset);
            _indicies[iOffset + 1] = (2 + vOffset);
            _indicies[iOffset + 2] = (1 + vOffset);
            
            _indicies[iOffset + 3] = (2 + vOffset);
            _indicies[iOffset + 4] = (3 + vOffset);
            _indicies[iOffset + 5] = (1 + vOffset);

            vOffset += 4;
            iOffset += 6;
        }
        for (int x = 0; x < CHUNK_SIZE; x++)
        {
            for (int y = 0; y < CHUNK_SIZE; y++)
            {
                set_height(x, y, 0.0);
            }                
        }

        auto attrs = VertexAttributes()
            .add(VertexAttribute.position3D())
            .add(VertexAttribute.normal())
            .add(VertexAttribute.tex_coords(0));

        version(TEX_ARR)
            attrs.add(VertexAttribute.tex_index());

        mesh.create(false, vertCount, indexCount, attrs);

        mesh.vb.set_data(_vertices, 0, cast(int) _vertices.length);
        mesh.ib.set_data(_indicies, 0, cast(int) _indicies.length);

        transform = mat4.set(v3(worldX,0, worldY), quat.identity, v3(1,1,1));
    }

    void dispose()
    {
        mesh.dispose();
    }

    void set_height(int x, int y, float height)
    {
        dirty = true;
        int index = (x + y * CHUNK_SIZE) * 4 * NUM_VERTICES;
        int wx = x * TILE_SIZE;
        int wy = y * TILE_SIZE;
        int ts = TILE_SIZE;
        
        int acc = 0;
        // 1
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            version(TEX_ARR)
            acc++;
        }
        // 2
        {
            // pos
            _vertices[index + acc++] = wx+ts;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            version(TEX_ARR)
            acc++;
        }
        // 3
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            version(TEX_ARR)
            acc++;
        }
        // 4
        {
            // pos
            _vertices[index + acc++] = wx+ts;
            _vertices[index + acc++] = height;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0f;
            _vertices[index + acc++] = 1f;
            _vertices[index + acc++] = 0f;
            //uv
            acc++;
            acc++;
            //texIndex
            version(TEX_ARR)
            acc++;
        }
    }
    
    void set(int x, int y, int texIndex, float u, float v, float u2, float v2)
    {
        dirty = true;
        int index = (x + y * CHUNK_SIZE) * 4 * NUM_VERTICES;
        int wx = x * TILE_SIZE;
        int wy = y * TILE_SIZE;
        int ts = TILE_SIZE;

        int acc = 0;
        // 1
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = 0;//tile.height_nw;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0;
            _vertices[index + acc++] = 1;
            _vertices[index + acc++] = 0;
            //uv
            _vertices[index + acc++] = u;//tile.u;
            _vertices[index + acc++] = v;//tile.v;
            // texIndex
            version(TEX_ARR)
            _vertices[index + acc++] = texIndex;//tile.textureIndex;
        }
        // 2
        {
            // pos
            _vertices[index + acc++] = wx+ts;
            _vertices[index + acc++] = 0;//tile.height_ne;
            _vertices[index + acc++] = wy;
            // normal
            _vertices[index + acc++] = 0;
            _vertices[index + acc++] = 1;
            _vertices[index + acc++] = 0;
            //uv
            _vertices[index + acc++] = u2;//tile.u2;
            _vertices[index + acc++] = v;//tile.v;
            // texIndex
            version(TEX_ARR)
            _vertices[index + acc++] = texIndex;//tile.textureIndex;
        }
        // 3
        {
            // pos
            _vertices[index + acc++] = wx;
            _vertices[index + acc++] = 0;//tile.height_sw;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0;
            _vertices[index + acc++] = 1;
            _vertices[index + acc++] = 0;
            //uv
            _vertices[index + acc++] = u;//tile.u;
            _vertices[index + acc++] = v2;//tile.v2;
            // texIndex
            version(TEX_ARR)
            _vertices[index + acc++] = texIndex;//tile.textureIndex;
        }
        // 4
        {
            // pos
            _vertices[index + acc++] = wx+ts;
            _vertices[index + acc++] = 0;//tile.height_se;
            _vertices[index + acc++] = wy+ts;
            // normal
            _vertices[index + acc++] = 0;
            _vertices[index + acc++] = 1;
            _vertices[index + acc++] = 0;
            //uv
            _vertices[index + acc++] = u2;//tile.u2;
            _vertices[index + acc++] = v2;//tile.v2;
            // texIndex
            version(TEX_ARR)
            _vertices[index + acc++] = texIndex;//tile.textureIndex;
        }
    }
    
    int get_tile_index(int x, int y)
    {
        return (x + y * CHUNK_SIZE) * 4 * NUM_VERTICES;
    }

    void upload()
    {
        mesh.vb.set_data(_vertices, 0, cast(int) _vertices.length);
    }
}