module dawn.model.node;

import rt.math;
import rt.memory;
import rt.collections.array;

enum MAX_BONES = 30;
enum MAX_CHILDREN_NODES = 6;

struct Node
{
    char[32] id = 0;

    bool inherit_transform = true;
    bool is_animated = false;

    v3 translation = v3(0, 0, 0);
    quat rotation = quat.identity;
    v3 scale = v3(1, 1, 1);

    mat4 local_transform = mat4.identity;
    mat4 global_transform = mat4.identity;

    Node* parent = null;
    Arr!(Node*, MAX_CHILDREN_NODES) children;
    Arr!(NodePart, 4) parts;

    void from(Node* other, Allocator* allocator)
    {
        id = other.id;
        
        is_animated = other.is_animated;
        inherit_transform = other.inherit_transform;

        translation = other.translation;
        rotation = other.rotation;
        scale = other.scale;

        local_transform = other.local_transform;
        global_transform = other.global_transform;

        for (int i = 0; i < other.parts.length; i++)
        {
            auto otherPart = &other.parts[i];
            parts.add(otherPart.copy());
        }
        for (int i = 0; i < other.children.length; i++)
        {
            auto otherChild = other.children[i];
        
            auto child = allocator.create!Node;
            child.from(otherChild, allocator);
            child.parent = &this;
            children.add(child);
        }
    }

    void calculate_local_transform()
    {
        if (!is_animated)
            local_transform = mat4.set(translation, rotation, scale);
    }

    void calculate_world_transform()
    {
        if (inherit_transform && parent != null)
            global_transform = mat4.mult(parent.global_transform, local_transform);
        else
            global_transform = local_transform;
    }

    void calculate_transforms(bool recursive)
    {
        calculate_local_transform();
        calculate_world_transform();

        if (recursive)
        {
            for (int i = 0; i < children.length; i++)
                children[i].calculate_transforms(true);
        }
    }

    void calculate_bone_transforms(bool recursive)
    {
        foreach (NodePart* part; parts)
        {
            if (part.inv_bind_transforms.length == 0 || part.bones.length == 0
                    || part.inv_bind_transforms.length != part.bones.length)
            {
                continue;
            }
            auto n = part.inv_bind_transforms.length;
            for (int i = 0; i < n; i++)
            {
                auto node = part.inv_bind_transforms[i].node;
                assert(node);

                mat4 globalTransform = part.inv_bind_transforms[i].node.global_transform;
                mat4 invTransform = part.inv_bind_transforms[i].transform;
                part.bones[i] = mat4.mult(globalTransform, invTransform);
            }
        }

        if (recursive)
        {
            foreach (Node* child; children)
                child.calculate_bone_transforms(true);
        }
    }
}

struct InvBoneBind
{
    Node* node;
    mat4 transform;
}

struct NodePart
{
    int meshpart_index = 0;
    int material_index = 0;
    Arr!(InvBoneBind, MAX_BONES) inv_bind_transforms;
    Arr!(mat4, MAX_BONES) bones;
    int num_bones = 0;
    bool enabled = true;

    NodePart copy()
    {
        NodePart ret;
        ret.meshpart_index = meshpart_index;
        ret.material_index = material_index;
        for (int i = 0; i < inv_bind_transforms.length; i++)
            ret.inv_bind_transforms.add(inv_bind_transforms[i]);
        for (int i = 0; i < bones.length; i++)
            ret.bones.add(bones[i]);
        ret.num_bones = num_bones;
        return ret;
    }
}


// TODO: make this less ugly, use slices
Node* find_node(string id, Node*[] slice)
{
    char[64] tmp = 0;
    for (int i = 0; i < id.length; i++)
        tmp[i] = id[i];
    
    return find_node(tmp, slice);
}

Node* find_node(ref char[32] id, Node*[] slice, bool recursive = true, bool ignoreCase = false)
{
        Node* node = null;
        auto n = slice.length;

        if(ignoreCase)
        {
            for (auto i = 0; i < n; ++i) {
                node = slice[i];
                if(equal(node.id, id)) return node;
            }
        } else
        {
            for (auto i = 0; i < n; ++i) {
                node = slice[i];
                if(equal(node.id, id)) return node;
            }
        }

        if(recursive)
        {
            for (auto i = 0; i < n; ++i) {
                if ((node = find_node(id, slice[i].children.get_slice())) != null) return node;
            }
        }

        return null;
}

Node* find_node(ref char[64] id, Node*[] slice, bool recursive = true, bool ignoreCase = false)
{
        Node* node = null;
        auto n = slice.length;

        if(ignoreCase)
        {
            for (auto i = 0; i < n; ++i) {
                node = slice[i];
                if(equal(node.id, id)) return node;
            }
        } else
        {
            for (auto i = 0; i < n; ++i) {
                node = slice[i];
                if(equal(node.id, id)) return node;
            }
        }

        if(recursive)
        {
            for (auto i = 0; i < n; ++i) {
                if ((node = find_node(id, slice[i].children.get_slice())) != null) return node;
            }
        }

        return null;
}

bool equal(T)(const(T)[] a, const(T)[] b)
{
    int strcmp(const(char)* l, const(char)* r)
    {
        for (; *l==*r && *l; l++, r++){}
        return *cast(ubyte*)l - *cast(ubyte*)r;
    }
	return strcmp(a.ptr, b.ptr) == 0;
}