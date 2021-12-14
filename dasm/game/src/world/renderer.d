module world.renderer;

import rt.dbg;
import rt.memz;
import rt.collections.array;
import rt.math;

import dawn.gfx;
import dawn.camera;
import dawn.mesh;
import dawn.texture;
import dawn.gl;
import dawn.model;
import dawn.assets;


struct EntityRenderer
{
    enum MAX_POOL = 512 * 2;
    Arr!(EntityShader, 8) shaders;
    int num_shaders;

    Array!(Renderable*) renderables;
    Array!(Renderable) pool;
    int used;

    const(char)[] entity_fs = import("res/shaders/entity.fs");
    const(char)[] entity_vs = import("res/shaders/entity.vs");

    Texture2D no_tex;
    ubyte[] no_tex_buffer = cast(ubyte[]) import("res/textures/uv_grid.png");
    int num_bones = 30;

    void create()
    {
        LINFO("create entity renderer");
        // TODO: replace this trash with proper allocator 
        renderables = Array!(Renderable*).createWith(engine.allocator, MAX_POOL);
        pool = Array!(Renderable).createWith(engine.allocator, MAX_POOL);
        for(int i = 0; i < MAX_POOL; i++)
            pool.add(Renderable());
        

        LINFO("decode default texture");
        import dawn.image: read_image;
        auto im = read_image(no_tex_buffer, 4);
        scope(exit) im.free();

        LINFO("create default texture {}:{} {}", im.w, im.h, im.c);
        no_tex = create_texture(im.w, im.h, im.buf8.ptr);
        LINFO("default texture created");

        LINFO("entity renderer created");
    }

    EntityShader* get_shader(Renderable* renderable)
    {   
        if(renderable.shader)
        {
            if(renderable.shader.can_render(renderable))
            {
                return renderable.shader;
            }
        }

        foreach(EntityShader* shader; shaders)
        {
            if(shader.can_render(renderable))
                return shader;
        }

        LINFO("no cached shader found for: {}, try build one", renderable.meshpart.id.ptr);
        auto shader = create_shader(renderable);
        shader.init();
        shaders.add(shader);

        return shaders.back_ptr();
    }

    EntityShader create_shader(Renderable* renderable)
    {
        import rt.str;

        /+ 
            TODO: improve this shit
                - one builder for defines
                - then use that for both vs/fs
                - easy
         +/

        EntityShader shader;
        shader.no_tex = &no_tex;

        char[4096] buffer_vs = 0;
        char[4096] buffer_fs = 0;

        auto builder_vs = StringBuilder();
        builder_vs.buffer = buffer_vs;
        
        auto builder_fs = StringBuilder();
        builder_fs.buffer = buffer_fs;

        auto attributesMask =  renderable.material ? renderable.material.getMask() : 0;
        
        // vertex
        {
            builder_vs.append_string("#version 300 es\n");
            builder_vs.append_string("#ifdef GL_ES\n");
            builder_vs.append_string("precision lowp float;\n");
            builder_vs.append_string("#endif\n");

            if(renderable.bones.length > 0 && num_bones > 0)
            {
                builder_vs.append_string("#define SKINNED\n");
                builder_vs.append_string("#define NUM_BONES ");
                builder_vs.append_int(cast(int) num_bones);
                builder_vs.append_string("\n");
            }
            if(attributesMask & AttributeType.DIFFUSE_TEXTURE)
                builder_vs.append_string("#define TEXTURE\n");
        }

        // fragment
        {
            builder_fs.append_string("#version 300 es\n");
            builder_fs.append_string("#ifdef GL_ES\n");
            builder_fs.append_string("precision lowp float;\n");
            builder_fs.append_string("#endif\n");

            if(attributesMask & AttributeType.DIFFUSE_TEXTURE)
                builder_fs.append_string("#define TEXTURE\n");
        }


        // LINFO("create shader with: \nVS:\n{}\n\nFS:\n{}", builder_vs.buffer.ptr, builder_fs.buffer.ptr);

        builder_vs.append_string(entity_vs);
        builder_fs.append_string(entity_fs);

        //LINFO("Entity vertex shader:\n%s", builder_vs.buffer.ptr);
        //LINFO("Entity fragment shader:\n%s", builder_fs.buffer.ptr);

        shader.create(renderable, builder_vs.slice(), builder_fs.slice(), num_bones);
        
        return shader;
    }

    void render(ModelInstance* model)
    {
        void check_node(Node* node)
        {
            foreach (NodePart* part; node.parts)
            {
                if (part.enabled == false)
                    continue;

                // TODO: automatically grow renderables
                int idx = used++;
                Renderable* renderable = &pool[idx];
                renderables.add(renderable);

                renderable.bones = part.bones.get_slice();
                renderable.meshpart.from(&model.model.parts[part.meshpart_index]);
                renderable.material = &model.model.materials[part.material_index];

                if (renderable.bones.length > 0)
                    renderable.world_transform = mat4.multiply(model.transform, node.global_transform);
                else
                    renderable.world_transform = model.transform;
            }
        }


        int offset = used;
        foreach(Node* node; model.nodes)
        {
            check_node(node);

            foreach(Node* child; node.children)
                check_node(child);
        }
        
        for(int i = offset; i < used; i++)
        {
            Renderable* renderable = renderables[i];
            renderable.shader = get_shader(renderable);
        }

    }

    void render(Mesh* mesh, mat4 transform)
    {
        int index = used++;
        assert(pool.length > index, "pool is full");
        
        Renderable* renderable = &pool[index];
        renderables.add(renderable);
        
        renderable.world_transform = transform;
        renderable.bones = null;
        renderable.material = null;
        renderable.meshpart.set("custom", mesh, GL_TRIANGLES);

        renderable.shader = get_shader(renderable);
    }

    v3 get_translation(ref mat4 worldTransform, ref v3 center) 
    {
        if (center.is_zero())
            return worldTransform.get_translation();
        else if (!worldTransform.has_rot_or_scl())
            return worldTransform.get_translation() + center;
        else
            return v3.transform(center, worldTransform);
    }
    
    void flush(Camera* camera)
    {
        import rt.sort;

        // TODO: sort
        sort(renderables.get_slice(), (ref Renderable* left, ref Renderable* right)
        {
            // check blending
            auto tmpV1 = get_translation(left.world_transform, left.meshpart.center);
            auto tmpV2 = get_translation(right.world_transform, right.meshpart.center);

            return 0;
        });

        EntityShader* current = null;
        for (int i = 0; i < used; i++)
        {
            Renderable* renderable = renderables[i];
            if (current != renderable.shader)
            {
                if (current != null)
                    current.end();

                current = renderable.shader;

                current.begin(camera);
            }

            current.render(renderable, camera);
        }

        if (current != null)
            current.end();

        for (int i = 0; i < used; i++)
        {
            Renderable* renderable = renderables[i];
            renderable.shader = null;
            renderable.meshpart.reset();
            renderable.material = null;
            renderable.bones = null;
        }

        used = 0;
        renderables.clear();
    }
}

struct EntityShader
{
    // Global uniforms
    int u_time;
    int u_projTrans;
    int u_viewTrans;
    int u_projViewTrans;
    int u_cameraPosition;
    
    // Object uniforms
    int u_worldTrans;
    int u_bones;
    int u_diffuseTexture;
    int u_diffuseUVTransform;

    // Light uniforms
    int u_fogColor;


    bool animation = false;
    
    Texture2D* no_tex = null;
    ShaderProgram program;

    ulong attributes_mask;
    ulong vertex_mask;

    Mesh* current_mesh = null;

    int num_bones = 0;

    void create(Renderable* renderable, const(char)[] vs, const(char)[] fs, int numBones)
    {
        num_bones = numBones;
        program.create(vs, fs);
        if(!program.is_compiled)
            panic("can't build shader");

        vertex_mask = renderable.meshpart.mesh.vb.attributes.get_mask_with_size_packed();

        if (renderable.material)
            attributes_mask = renderable.material.getMask();
        debug check_gl_error();
    }

    void init()
    {
        u_time = program.fetch_uniform_location("u_time", false);
        u_projTrans = program.fetch_uniform_location("u_projTrans", false);
        u_viewTrans = program.fetch_uniform_location("u_viewTrans", false);
        u_projViewTrans = program.fetch_uniform_location("u_projViewTrans", false);
        u_cameraPosition = program.fetch_uniform_location("u_cameraPosition", false);
    
        u_worldTrans = program.fetch_uniform_location("u_worldTrans", false);
        u_bones = program.fetch_uniform_location("u_bones", false);

        u_diffuseTexture = program.fetch_uniform_location("u_diffuseTexture", false);
        u_diffuseUVTransform = program.fetch_uniform_location("u_diffuseUVTransform", false);

        u_fogColor = program.fetch_uniform_location("u_fogColor", false);

        // &LINFO("u_time:           %i",u_time);
        // LINFO("u_projTrans:      %i",u_projTrans);
        // LINFO("u_viewTrans:      %i",u_viewTrans);
        // LINFO("u_projViewTrans:  %i",u_projViewTrans);
        // LINFO("u_cameraPosition: %i",u_cameraPosition);
    
        // LINFO("u_worldTrans:     %i",u_worldTrans);
        // LINFO("u_bones:          %i",u_bones);

        // LINFO("u_diffuseTexture:     %i",u_diffuseTexture);
        // LINFO("u_diffuseUVTransform: %i",u_diffuseUVTransform);

        // LINFO("u_fogColor: %i",u_fogColor);
        
    }

    bool can_render(Renderable* renderable)
    {
        ulong mask = combine_attributes(renderable);
        return 
        attributes_mask == mask &&
        vertex_mask == renderable.meshpart.mesh.vb.attributes.get_mask_with_size_packed()
        ;
    }

    void begin(Camera* camera)
    {
        if(!program.is_compiled)
            panic("shader problem");

        current_mesh = null;

        program.bind();
        debug check_gl_error();

        // bind global

        if(u_time > 0)
            program.set_uniformf(u_time, 0.0f); // TODO: implement that
        
        program.set_uniform_mat4(u_projViewTrans, camera.combined);
        program.set_uniform4f(u_cameraPosition, camera.position.x, camera.position.y, camera.position.z, 1.1001f / (camera.far * camera.far));

        if(u_fogColor >= 0)
            program.set_uniform4f(u_fogColor, 0,0,0,1);

        debug check_gl_error();
    }

    void render(Renderable* renderable, Camera* camera)
    {
        if(current_mesh != renderable.meshpart.mesh)
        {
            if(current_mesh) 
            {
                current_mesh.unbind(&program, null);
                debug check_gl_error();
            }
            
            current_mesh = renderable.meshpart.mesh;
            current_mesh.bind(&program, null);
            debug check_gl_error();
        }

        // bind object
        
        program.set_uniform_mat4(u_worldTrans, renderable.world_transform);
        debug check_gl_error();

        if(u_bones >= 0 && renderable.bones.length > 0)
        {
           int count = cast(int) renderable.bones.length;
           if(count > num_bones) count = num_bones;
        
           program.set_uniform_mat4_array(u_bones, count, renderable.bones);
           debug check_gl_error();
        }

        // blending
        // metarial

        if (renderable.material)
        {
            for(int i = 0; i < renderable.material.num_attrs; i++)
            {
                Attribute* attr = &renderable.material.attributes[i];
                switch (attr.type) with (AttributeType)
                {
                    case DIFFUSE_TEXTURE:
                        if (!attr.diffuse_tex.texture.base.is_ready()) break;
                        attr.diffuse_tex.texture.tex.bind();
                        program.set_uniformi("u_diffuseTexture", 0);
                        program.set_uniform4f("u_diffuseUVTransform", 0, 0, 1, 1);
                    break;
                    default: assert(0);
                }
            }
        }


        // env

        // light
        //program.set_uniform4f()


        renderable.meshpart.render(&program, false);

        debug check_gl_error();

    }

    void end()
    {
        if(current_mesh)
        {
            current_mesh.unbind(&program, null);
            current_mesh = null;
            debug check_gl_error();
        }
        else
        {
        }
    }
}

struct Renderable
{
    mat4 world_transform;
    MeshPart meshpart;
    Material* material = null;
    //Environment* environment;
    mat4[] bones;
    EntityShader* shader = null;
}


struct CModel
{
    import dawn.model.animation;
    ModelAsset* model;
    AnimationController controller;
}

struct CCube
{

}

ulong combine_attributes(Renderable* renderable)
{
    ulong mask = 0;
    //if(renderable.environement) mask |= renderable.environement.mask;
    if(renderable.material) mask |= renderable.material.mask;
    return mask;
}