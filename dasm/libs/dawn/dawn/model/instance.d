module dawn.model.instance;

import rt.collections.array;

import rt.math;
import rt.memz;
import rt.dbg;

import dawn.model;
import dawn.model.node;
import dawn.model.animation;
import dawn.mesh;

struct ModelInstance
{
    enum bool share_keyframes = true;
    
    Model* model = null;
    Arr!(Material, MAX_MATERIAL) materials;
    Arr!(Node*, MAX_NODES) nodes;
    Arr!(Animation, MAX_ANIMATIONS) animations;
    Allocator* allocator;

    mat4 transform = mat4.identity;

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

        foreach(Animation* anim; animations)
        {
            if(share_keyframes == false)
            foreach(NodeAnimation* nanim; anim.node_anims)
            {
                nanim.translation.dispose();
                nanim.rotation.dispose();
                nanim.scaling.dispose();
            }
            anim.node_anims.dispose();
        }
    }

    void load(Model* model, Allocator* allocator)
    {
        assert(model);
        
        this.model = model;
        this.allocator = allocator;

        copy_nodes();
        invalidate();
        copy_animations();
        calculate_transforms();
    }

    void copy_nodes()
    {
        assert(model);
        for (int i = 0; i < model.nodes.length; i++)
        {
            auto node = model.nodes.get(i);
            auto copy = allocator.create!Node;

            copy.from(node, allocator);
            nodes.add(copy);
        }
    }

    void copy_animations()
    {
        foreach(Animation* modelAnim; model.animations)
        {
            auto animation = Animation();
            memcpy(animation.id.ptr, modelAnim.id.ptr, modelAnim.id.length);
            animation.duration = modelAnim.duration;
            if(animation.duration > 10) panic("wait a minute %f", animation.duration);
            
            animation.node_anims.create(allocator, modelAnim.node_anims.length);
            
            foreach(NodeAnimation* nanim; modelAnim.node_anims)
            {
                auto node = find_node(nanim.node.id, nodes.get_slice());
                if(node == null) panic("can't find node: %s", nanim.node.id.ptr);

                auto nodeAnim = NodeAnimation();
                nodeAnim.node = node;
        
                if(share_keyframes)
                {
                    nodeAnim.translation = nanim.translation;
                    nodeAnim.rotation = nanim.rotation;
                    nodeAnim.scaling = nanim.scaling;
                }
                else
                {
                    if(!nanim.translation.empty())
                    {
                        nodeAnim.translation.create(allocator, nanim.translation.length);
                        for (int i = 0; i < nanim.translation.length; ++i) {
                            auto kf = &nanim.translation[i];
                            if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                            auto kff = NodeKeyframe!(v3)(kf.value, kf.keytime);
                            nodeAnim.translation.add(kff);
                        }
                    }
                    if(!nanim.rotation.empty())
                    {
                        nodeAnim.rotation.create(allocator, nanim.rotation.length);
                        for (int i = 0; i < nanim.rotation.length; ++i) {
                            auto kf = &nanim.rotation[i];
                            if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                            auto kff = NodeKeyframe!(quat)(kf.value, kf.keytime);
                            nodeAnim.rotation.add(kff);
                        }
                    }
                    if(!nanim.scaling.empty())
                    {
                        nodeAnim.scaling.create(allocator, nanim.scaling.length);
                        for (int i = 0; i < nanim.scaling.length; ++i) {
                            auto kf = &nanim.scaling[i];
                            if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                            auto kff = NodeKeyframe!(v3)(kf.value, kf.keytime);
                            nodeAnim.scaling.add(kff);
                        }
                    }
                }

                if ((!nodeAnim.translation.empty())
               || (!nodeAnim.rotation.empty())
               || (!nodeAnim.scaling.empty()))
                   animation.node_anims.add(nodeAnim);
            }

            if(!animation.node_anims.empty())
                animations.add(animation);
        }
    }

    void invalidate()
    {
        foreach(Node* node; nodes)
        {
            invalidate_node(node);
        }
    }

    private void invalidate_node(Node* node)
    {
        foreach(NodePart* part; node.parts)
        {
            if(part.inv_bind_transforms.length > 0)
            {
                for (int i = 0; i < part.inv_bind_transforms.length; i++)
                {
                    auto node = find_node(part.inv_bind_transforms.get(i).node.id, nodes.get_slice());
                    part.inv_bind_transforms[i].node = node;
                }
            }
            // TODO: invalidate materials
        }


        foreach(Node* child; node.children)
            invalidate_node(child);
    }

    void copy_materials()
    {

    }

    void calculate_transforms()
    {
        int n = nodes.length;
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculate_transforms(true);
        }

        for (int i = 0; i < n; i++)
        {
            nodes[i].calculate_bone_transforms(true);
        }
    }

    Animation* get_animation(const(char)[] id)
    {
        import core.stdc.string: strcmp;
        foreach(Animation* anim; animations)
        {
            if(strcmp(id.ptr, anim.id.ptr) == 0) return anim;
        }
        return null;
    }
}
