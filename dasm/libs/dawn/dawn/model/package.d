module dawn.model;

import rt.collections.array;
import rt.collections.hashmap;
import rt.memz;
import rt.dbg;
import rt.math;
import rt.readers;

public import dawn.model.node;
public import dawn.model.animation;
public import dawn.model.instance;

import dawn.mesh;
import dawn.assets;

enum MAX_MESH       = 4;
enum MAX_MATERIAL   = 4;
enum MAX_ANIMATIONS = 10;
enum MAX_NODES  = 2;
enum MAX_CHILDREN_NODES = 6;
enum MAX_PARTS  = 4;

// TODO: bad..
HashMap!(NodePart*, InvBoneBindInfo[MAX_BONES]) nodePartBones;

struct Model
{
    Arr!(Mesh, MAX_MESH) meshes;
    Arr!(Material, MAX_MATERIAL) materials;
    Arr!(Animation, MAX_ANIMATIONS) animations;
    Arr!(Node*, MAX_NODES) nodes;
    Arr!(MeshPart, MAX_PARTS) parts;

    Allocator* allocator;
    
    void dispose()
    {
        void free_node(Node* node)
        {
            foreach(Node* n; node.children)
            {
                free_node(n);
                allocator.free(n);
            }
        }

        foreach(Node* node; nodes)
        {
            free_node(node);
            allocator.free(node);
        }

        foreach(Mesh* mesh; meshes)
        {
            mesh.dispose();
        }

        foreach(Animation* anim; animations)
        {
            foreach(NodeAnimation* nanim; anim.node_anims)
            {
                if(nanim.translation.length > 0)
                    nanim.translation.dispose();
                if(nanim.rotation.length > 0)
                    nanim.rotation.dispose();
                if(nanim.scaling.length > 0)
                    nanim.scaling.dispose();
            }
            if(anim.node_anims.length > 0)
                anim.node_anims.dispose();
        }
        nodePartBones.clear();


        foreach(Material* mat; materials)
        {
            for(int i = 0; i < mat.num_attrs; i++)
            {
                Attribute* attr = &mat.attributes[i];
                if (attr.type & AttributeType.DIFFUSE_TEXTURE)
                    attr.diffuse_tex.texture.base.decrement_ref_count();
            }
        }
    }
    
    void load(ref PReader reader, Allocator* allocator, ResourceCache* cache)
    {
        this.allocator = allocator;
        nodePartBones.allocator = allocator;

        //benchmark("load_meshes", { 
            load_meshes(reader);
        //});

        //benchmark("load_materials", { 
            load_materials(reader, cache);
        //});

        //benchmark("load_nodes", { 
            load_nodes(reader);
        //});

        //benchmark("load_nodes", { 
            load_animations(reader);
        //});

        auto magic = reader.read_cstring();
        assert(magic == "-END-");

        //benchmark("calculate_transforms", { 
            calculate_transforms();
        //});

        nodePartBones.clear();
    }

    void load_meshes(ref PReader reader)
    {
        auto mc = reader.read_ubyte();
        //ARRAY meshes.create(allocator, mc);

        for (int i = 0; i < mc; i++)
        {
            VertexAttributes attributes;

            auto num_attributes = reader.read_ubyte();
            for (int j = 0; j < num_attributes; j++)
            {
                auto attribute = reader.read_cstring();
                switch (attribute)
                {
                case "POSITION":
                    attributes.add(VertexAttribute.position3D());
                    break;
                case "NORMAL":
                    attributes.add(VertexAttribute.normal());
                    break;
                case "COLOR":
                    attributes.add(VertexAttribute.color_unpacked());
                    break;
                case "TEXCOORD0":
                    attributes.add(VertexAttribute.tex_coords(0));
                    break;
                case "BLENDWEIGHT0":
                    attributes.add(VertexAttribute.blend_weight(0));
                    break;
                case "BLENDWEIGHT1":
                    attributes.add(VertexAttribute.blend_weight(1));
                    break;
                case "BLENDWEIGHT2":
                    attributes.add(VertexAttribute.blend_weight(2));
                    break;
                case "BLENDWEIGHT3":
                    attributes.add(VertexAttribute.blend_weight(3));
                    break;
                    default: panic("attribute: {} not supported!", attribute.ptr);
                }
            }

            //if(expextedAttributes != 0)
            //{
            //    if(attributes.mask != expextedAttributes)
            //    {
            //        panic!("Loaded a model with wrong expected attributes %ui != %ui")
            //         (expextedAttributes, attributes.mask);
            //    }
            //}

            auto num_vertices = reader.read_int();
            auto vertices = cast(float[]) reader.read_slice(num_vertices * 4);

            auto num_indices = reader.read_int();
            
            auto indices = cast(int[]) reader.read_slice(num_indices * 4);

            int vertexes = cast(int) num_vertices / (attributes.vertex_size / 4);

            
            Mesh mesh;
            mesh.create(true, vertexes, num_indices, attributes);
            mesh.vb.set_data(vertices, 0, num_vertices);
            if(num_indices > 0)
            {
                mesh.ib.set_data(indices, 0, num_indices);
            }

            meshes.add(mesh);

            auto num_parts = reader.read_ubyte();
            //ARRAY parts.create(allocator, num_parts);
            for (int k = 0; k < num_parts; k++)
            {
                auto id = reader.read_cstring();
                auto pt = reader.read_ubyte();
                auto offset = reader.read_int();
                auto size = reader.read_int();
                
                MeshPart part;
                memcpy(part.id, id, id.length + 1);

                part.primitive_type = pt;
                part.offset = offset;
                part.mesh = &meshes[i];
                part.size = num_indices > 0 ?  size : vertexes;
                parts.add(part);
            }

            foreach(MeshPart* part; parts)
            {
                part.update();
            }
        }
    }

    void load_materials(ref PReader reader, ResourceCache* cache)
    {
        auto num_materials = reader.read_ubyte();
        //ARRAY materials.create(allocator, num_materials);
        for (int i = 0; i < num_materials; i++)
        {
            auto id = reader.read_cstring();

            Material material;
            memcpy(material.id, id, id.length + 1);

            auto flags = reader.read_ubyte();

            if(flags & UsagColorFlag.fcDiffuse)
            {
                auto r = reader.read_float();
                auto g = reader.read_float();
                auto b = reader.read_float();
            }
            
            if(flags & UsagColorFlag.fcAmbient)
            {
                auto r = reader.read_float();
                auto g = reader.read_float();
                auto b = reader.read_float();
            }
            
            if(flags & UsagColorFlag.fcEmissive)
            {
                auto r = reader.read_float();
                auto g = reader.read_float();
                auto b = reader.read_float();
                //printf("fcEmissive: %f:%f:%f\n", r, g, b);
            }

            if(flags & UsagColorFlag.fcSpecular)
            {
                auto r = reader.read_float();
                auto g = reader.read_float();
                auto b = reader.read_float();
                //printf("fcSpecular: %f:%f:%f\n", r, g, b);
            }
            
            if(flags & UsagColorFlag.fcShininess)
            {
                auto v = reader.read_float();
                //printf("fcShininess: %f\n", v);
            }
            
            if(flags & UsagColorFlag.fcOpacity)
            {
                auto v = reader.read_float();
                //printf("fcOpacity: %f\n", v);
            }

            auto num_textures = reader.read_ubyte();
            for (int j = 0; j < num_textures; j++)
            {
                auto tex_id = reader.read_cstring();
	            auto tex_path = reader.read_cstring();
	            auto uv_t_x = reader.read_float();
	            auto uv_t_y = reader.read_float();
            
	            auto uv_s_x = reader.read_float();
	            auto uv_s_y = reader.read_float();

	            auto usage = reader.read_ubyte();

                LINFO("load tex: {}", tex_path);
                import rt.str;
                import m = rt.memz;

                DiffuseTexAttribute ta;
                m.memcpy(ta.id.ptr, tex_path.ptr, tex_path.length);
                assert(tex_path.length < 32);

                // TODO: this is an ugly piece of shitty code

                char[256] buffer = 0;
                StringBuilder sb;
                sb.buffer = buffer;
                sb.append_string("res/textures/");
                sb.append_string(tex_path);
                
                ta.texture = cache.load!(TextureAsset)(buffer);
                

                Attribute attr;
                attr.diffuse_tex = ta;
                attr.type = AttributeType.DIFFUSE_TEXTURE;
                // TODO: set material
                //material.add(  )
                material.set(attr);
            }

            materials.add(material);
        }
    }
    Node* load_node(ref PReader reader)
    {
        Node* node = allocator.create!Node();

        //ARRAY node.parts.create(allocator);
        auto node_id = reader.read_cstring();
        
        memcpy(node.id, node_id, node_id.length + 1);
        node.id[$-1] = '\0';
        
        node.rotation = reader.read_quat();
        node.scale = reader.read_vec3();
        node.translation = reader.read_vec3();

        auto num_parts = reader.read_ubyte();
        for (int j = 0; j < num_parts; j++)
        {
            auto meshpart_id = reader.read_cstring();
            auto material_id = reader.read_cstring();

            NodePart node_part;

            foreach(mi, MeshPart* meshpart; parts)
            {
                if(equal(meshpart.id, meshpart_id))
                    node_part.meshpart_index = cast(int) mi;
            }
            foreach(mi, Material* material; materials)
            {
                if(equal(material.id, material_id))
                    node_part.material_index = cast(int) mi;
            }
        
            InvBoneBindInfo[MAX_BONES] invBoneBind = void;
            auto num_bones = reader.read_ubyte();
            node_part.num_bones = num_bones;
            for (int k = 0; k < num_bones; k++)
            {
                auto bone_id = reader.read_cstring();

        
                auto t_t = reader.read_vec3();
                auto t_r = reader.read_quat();
                auto t_s = reader.read_vec3();

                auto transform = mat4.set(
                    t_t, t_r, t_s
                );

                node_part.bones.add(transform);

                InvBoneBindInfo bi;
                bi.transform = transform;
                memcpy(bi.id, bone_id, bone_id.length + 1);
                invBoneBind[k] = bi;
            }

            auto num_uv_mappin = reader.read_ubyte();
            for (int l = 0; l < num_uv_mappin; l++)
            {}
            
            node.parts.add(node_part);

            // TODO: figure out hashmap with pointer as key isue

            if (num_bones > 0)
            {
                auto ptr = &node.parts[j];
                nodePartBones.set(ptr, invBoneBind);
            }
        }

        auto num_children = reader.read_ubyte();
        //ARRAY node.children.create(allocator);
        for (int k = 0; k < num_children; k++)
        {
            auto c = load_node(reader);
            c.parent = node;
            node.children.add(c);
        }

        return node;
    }
    
    void load_nodes(ref PReader reader)
    {


        auto num_nodes = reader.read_ubyte();
        //ARRAY nodes.create(allocator, num_nodes);

        for (int i = 0; i < num_nodes; i++)
        {
            auto n = load_node(reader);
            nodes.add(n);
        }

        // compute invBind
        foreach(pair; nodePartBones)
        {
            auto count = pair.key.num_bones;
            for (int j = 0; j < count; j++)
            {
                auto a = pair.value[j];
                auto node = find_node(a.id, nodes.get_slice());
                if(!node) panic("can't find node: %s", a.id.ptr);

                auto invTransform = mat4.inv(a.transform);
                pair.key.inv_bind_transforms.add(InvBoneBind(node, invTransform));
            }

        }
    }

    void load_animations(ref PReader reader)
    {
        auto num_animations = reader.read_ubyte();
        //ARRAY animations.create(allocator, num_animations);
        for (int i = 0; i < num_animations; i++)
        {
            auto anim_id = reader.read_cstring();

            Animation animation;
            memcpy(animation.id, anim_id, anim_id.length + 1);

            auto num_node_anims = reader.read_ubyte();
            assert(num_node_anims > 0);

            animation.node_anims.create(allocator, num_node_anims);            
            for (int j = 0; j < num_node_anims; j++)
            {
                auto node_id = reader.read_cstring();

                assert(node_id.length > 0);

                NodeAnimation nodeAnim;
                nodeAnim.node = find_node(node_id, nodes.get_slice());

                if(!nodeAnim.node) panic("can't find node: %s", node_id.ptr);

                auto num_kf_translations = reader.read_ubyte();
                if(num_kf_translations > 0)
                    nodeAnim.translation.create(allocator, num_kf_translations);
                for (int k  = 0; k < num_kf_translations; k++)
                {
                    auto time = reader.read_float() / 1000.0f;
                    if(time > animation.duration)
                        animation.duration = time;

                    auto v = reader.read_vec3();
		            
                    auto kf = NodeKeyframe!(v3)(v, time);
                    nodeAnim.translation.add(kf);
                }
                
                auto num_kf_rotations = reader.read_ubyte();
                if(num_kf_rotations > 0)
                    nodeAnim.rotation.create(allocator, num_kf_rotations);
                for (int k  = 0; k < num_kf_rotations; k++)
                {
                    auto time = reader.read_float() / 1000.0f;
                    if(time > animation.duration)
                        animation.duration = time;

                    auto r = reader.read_quat();
		            
                    auto kf = NodeKeyframe!(quat)(r, time);
                    nodeAnim.rotation.add(kf);
                }
                
                auto num_kf_scale = reader.read_ubyte();
                if(num_kf_scale > 0)
                    nodeAnim.scaling.create(allocator, num_kf_scale);
                for (int k  = 0; k < num_kf_scale; k++)
                {
                    auto time = reader.read_float() / 1000.0f;
                    if(time > animation.duration)
                        animation.duration = time;

                    auto v = reader.read_vec3();

                    auto kf = NodeKeyframe!(v3)( v, time );
                    nodeAnim.scaling.add(kf);
                }

                //printf("KF_translations: %i\n", num_kf_translations);
                //printf("KF_rotations: %i\n", num_kf_rotations);
                //printf("KF_scales: %i\n", num_kf_scale);

                if (!nodeAnim.is_empty())
                    animation.node_anims.add(nodeAnim);
            }

            if(animation.duration > 10) panic("waiiiiiiiit %s %f", animation.id.ptr, animation.duration);

            animations.add(animation);
        }
    }

    void calculate_transforms()
    {
        int n = cast(int) nodes.length;
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculate_transforms(true);
        }
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculate_bone_transforms(true);
        }
    }
}


struct InvBoneBindInfo
{
    char[64] id = 0;
    mat4 transform;
}

quat read_quat(ref PReader reader)
{
    quat ret;
    ret.x = reader.read_float();
    ret.y = reader.read_float();
    ret.z = reader.read_float();
    ret.w = reader.read_float();
    return ret;
}
v3 read_vec3(ref PReader reader)
{
    v3 ret;
    ret.x = reader.read_float();
    ret.y = reader.read_float();
    ret.z = reader.read_float();
    return ret;
}


void memcpy(char[] dst, string src, size_t len)
{
//     int l = cast(int) len;

//     for(int i = 0; i < len; i++)
//     {
//         if (i >= src.length) break;
//         if (i >= dst.length) break;
//         dst[i] = src[i];
//     }
import m = rt.memz;
    m.memcpy(dst.ptr, src.ptr, len);
}