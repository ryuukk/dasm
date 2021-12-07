module dawn.model.animation;

import rt.dbg;
import rt.math;
import rt.collections.array;
import rt.collections.hashmap;

import dawn.model.node;
import dawn.model.instance;


alias TransformMap = HashMap!(Node*, Transform);
struct AnimationDesc
{

    Animation* animation = null;
    float speed = 0.0f;
    float time = 0.0f;
    float offset = 0.0f;
    float duration = 0.0f;
    int loop_count;

    void* user_data = null;
    void function(AnimationDesc*) on_end;
    void function(AnimationDesc*) on_loop;

    bool opEquals()(auto ref const AnimationDesc rhs) const 
    {
        return animation == rhs.animation;
    }

    float update(float delta)
    {
        if (loop_count != 0 && animation != null)
        {
            int loops;
            float diff = speed * delta;
            if (duration != 0.0f)
            {
 				time += diff;
				if (speed < 0) {
					float invTime = duration - time;
					loops = cast(int)abs(invTime / duration);
					invTime = abs(invTime % duration);
					time = duration - invTime;
				} else {
					loops = cast(int)abs(time / duration);
					time = abs(time % duration);
				}
			} else
					loops = 1;

            for (int i = 0; i < loops; ++i)
            {
                if (loop_count > 0) loop_count--;
                // if(loopCount != 0) && listener != nullptr) listener.onLoop(this); // todo: figure out callbacks
                if (loop_count != 0 && on_loop) on_loop(&this);
                if (loop_count == 0)
                {
                    float result = (((loops - 1) - i) * duration) + (diff < 0.0f ? (duration - time) : time);
                    time = (diff < 0.0f) ? 0.0f : duration;
                    // if (listener != nullptr) listener.onEnd(this); // todo: figure out callbacks
                    if (on_end) on_end(&this);
                    return result;
                }
            }
            return -1;
        }
        else
            return delta;
    }
}

struct AnimationController
{
    ModelInstance* target = null;

    AnimationDesc previous = AnimationDesc(null);
    AnimationDesc current = AnimationDesc(null);
    AnimationDesc queued = AnimationDesc(null);
    
    float queued_transition_time = 0;
    float transition_current_time = 0;
    float transition_target_time = 0;
    
    bool in_action;
    bool paused;
    bool allow_same_animation;
    bool just_changed_animation_ = false;
    
    private bool _applying = false;
    
    void update(float delta)
    {
        if (paused) return;
        if (previous.animation != null && ((transition_current_time += delta) >= transition_target_time)) {
            remove_anim(previous.animation);
            just_changed_animation_ = true;

            // pool ?
            //delete previous;
            //previous = nullptr;
            //pool.delete_object(previous);
            previous = AnimationDesc(null);
        }

        if (just_changed_animation_) {
            target.calculate_transforms();
            just_changed_animation_ = false;
        }

        if (current.animation == null || current.loop_count == 0 || current.animation == null) 
            return;

        float remain = current.update(delta);

        if (remain >= 0.0f && queued.animation != null) {
            in_action = false;
            animate(queued, queued_transition_time);
            queued = AnimationDesc(null);
        
            if(remain > 0.0f ) 
                update(remain);
            
            return;
        }

        if (previous.animation != null)
        {
            apply_animations(previous.animation, previous.offset + previous.time, current.animation, current.offset + current.time, transition_current_time / transition_target_time);
        }
        else
            apply_animation(current.animation, current.offset + current.time);
    }

    void begin()
    {
        assert(!_applying);
        _applying = true;
    }

    void apply(Animation* animation, float time, float weight)
    {
        assert(_applying);

        // TODO: pass transforms when i add animation blending
        g_apply_animation(null, weight, animation, time);
    }

    void end()
    {
        assert(_applying);
        
        // TODO: uncomment once animation blending added
        //foreach (ref entry; transforms.byPair())
        //{
        //    entry.key.localTransform = entry.value.tomat4();
        //    //pool.free(entry.value);
        //}
        //transforms.clear();
        
        target.calculate_transforms();
        _applying = false;
    }

    void remove_anim(Animation* animation)
    {
        foreach (ref NodeAnimation nodeAnim; animation.node_anims)
            nodeAnim.node.is_animated = false;
    }

    void apply_animation(Animation* animation, float time)
    {
        assert(!_applying);
        g_apply_animation(null, 1.0f, animation, time);
        target.calculate_transforms();
    }

    void apply_animations(Animation* anim1, float time1, Animation* anim2, float time2, float weight)
    {
        not_implemented("a");
        
        // if (anim2 == null || weight == 0.0f)
        //     apply_animation(anim1, time1);
        // else if (anim1 == null || weight == 1.0f)
        //     apply_animation(anim2, time2);
        // else if (_applying)
        // {
        //     assert(!_applying);
        // }
        // else {
        //     begin();
        //     apply(anim1, time1, 1.0f);
        //     apply(anim2, time2, weight);
        //     end();
        // }
    }

    void animate(ref AnimationDesc anim, float transitionTime)
    {
        if (current.animation == null || current.loop_count == 0)
            current = anim;
        else if (in_action)
            queue(anim, transitionTime);
        else if (!allow_same_animation  && current.animation == anim.animation) {
            anim.time = current.time;

            // pool ?
            //delete current;
            //pool.delete_object(current);

            current = anim;
        } else {
            if (previous.animation != null) {
                remove_anim(previous.animation);

                // pool ?
                //delete previous;
                //pool.delete_object(previous);
                previous = AnimationDesc(null);
            }
            previous = current;
            current = anim;
            transition_current_time = 0.0f;
            transition_target_time = transitionTime;
        }
        //return anim;
    }

    void queue(ref AnimationDesc anim, float transitionTime)
    {
        if (current.animation == null || current.loop_count == 0)
            animate(anim, transitionTime);
        else {
            if (queued.animation != null)
            {
                // pool ?
                //delete queued;
                //pool.delete_object(queued);
            }
            queued = anim;
            queued_transition_time = transitionTime;
            if (current.loop_count < 0) current.loop_count = 1;
        }
        //return anim;
    }

    bool animate(const(char)[] id, float offset = 0.0f, float duration = -1.0f, int loopCount = -1, float speed = 1, float transitionTime = 0.0f)
    {
        auto animation = target.get_animation(id);
        if(animation == null)
            return false;

        //auto* desc = pool.new_object();
        auto desc = AnimationDesc();
        desc.animation = animation;
        desc.loop_count = loopCount;
        desc.speed = speed;
        desc.offset = offset;
        desc.duration = duration < 0 ? (animation.duration - offset) : duration;
        desc.time = speed < 0 ? desc.duration : 0.0f;

        animate(desc, transitionTime);

        //return desc;
        return true;
    }
       
}

pragma(inline)
{
    private int get_first_kf_at(T)(ref Array!T arr, float time)
    {
        int lastIndex = cast(int) arr.length - 1;

        // edges cases : time out of range always return first index
        if (lastIndex <= 0 || time < arr[0].keytime || time > arr[lastIndex].keytime)
            return 0;

        // binary search
        int minIndex = 0;
        int maxIndex = lastIndex;

        while (minIndex < maxIndex)
        {
            int i = (minIndex + maxIndex) / 2;
            if (time > arr[i + 1].keytime)
            {
                minIndex = i + 1;
            }
            else if (time < arr[i].keytime)
            {
                maxIndex = i - 1;
            }
            else
            {
                return i;
            }
        }
        return minIndex;
    }

    private v3 get_translation_at(ref NodeAnimation nodeAnim, float time)
    {
        if (nodeAnim.translation.length == 0)
            return nodeAnim.node.translation;
        if (nodeAnim.translation.length == 1)
            return nodeAnim.translation[0].value;

        int index = get_first_kf_at(nodeAnim.translation, time);

        auto firstKeyframe = nodeAnim.translation[index];
        v3 result = firstKeyframe.value;


        if (++index < nodeAnim.translation.length)
        {
            auto secondKeyframe = nodeAnim.translation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = v3.lerp(result, secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }

    private quat get_rotation_at(ref NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.rotation.length == 0)
            return nodeAnim.node.rotation;
        if (nodeAnim.rotation.length == 1)
            return nodeAnim.rotation[0].value;

        int index = get_first_kf_at(nodeAnim.rotation, time);

        auto firstKeyframe = nodeAnim.rotation[index];
        quat result = firstKeyframe.value;

        if (++index < nodeAnim.rotation.length)
        {
            auto secondKeyframe = nodeAnim.rotation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            //result = quat.lerp(result, secondKeyframe.value, t);
            result.slerp(secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }

    private v3 get_scaling_at(ref NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.scaling.length == 0)
            return nodeAnim.node.scale;
        if (nodeAnim.scaling.length == 1)
            return nodeAnim.scaling[0].value;

        int index = get_first_kf_at(nodeAnim.scaling, time);

        auto firstKeyframe = nodeAnim.scaling[index];
        v3 result = firstKeyframe.value;

        if (++index < nodeAnim.scaling.length)
        {
            auto secondKeyframe = nodeAnim.scaling[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = v3.lerp(result, secondKeyframe.value, t);
            //result = secondKeyframe.value;
        }
        return result;
    }
    
    private Transform get_node_anim_transform(ref NodeAnimation nodeAnim, float time)
    {
        Transform transform;
        transform.translation = get_translation_at(nodeAnim, time);
        transform.rotation = get_rotation_at(nodeAnim, time);
        transform.scale = get_scaling_at(nodeAnim, time);
        return transform;
    }
    
    void apply_node_anim_directly(ref NodeAnimation nodeAnim, float time)
    {
        Node* node = nodeAnim.node;
        node.is_animated = true;
        Transform transform = get_node_anim_transform(nodeAnim, time);
        node.local_transform = transform.tomat4();
    }

    void apply_node_animation_blending()
    {
        not_implemented();
    }

    void g_apply_animation(TransformMap* map, float alpha, Animation* animation, float time)
    {
        if(map)
        {
            // TODO: blending
            not_implemented();
        }
        else
        {
            foreach(ref NodeAnimation nodeAnim; animation.node_anims)
                apply_node_anim_directly(nodeAnim, time);
        }
    }
}


struct NodeAnimation
{
    Node* node;
    Array!(NodeKeyframe!v3) translation;
    Array!(NodeKeyframe!quat) rotation;
    Array!(NodeKeyframe!v3) scaling;

    bool is_empty()
    {
        return (translation.length + rotation.length + scaling.length) == 0; 
    }
}

struct Animation
{
    char[32] id = 0;
    float duration = 0f;
    Array!NodeAnimation node_anims;
}

struct NodeKeyframe(T)
{
    T value;
    float keytime = 0f;
 
    alias value this;
}

struct Transform
{
    v3 translation = v3(0, 0, 0);
    quat rotation = quat.identity;
    v3 scale = v3(1, 1, 1);

    pragma(inline)
    {
        mat4 tomat4()
        {
            return mat4.set(translation, rotation, scale);
        }

        Transform idt()
        {
            translation = v3();
            rotation = quat.identity;
            scale = v3(1f, 1f, 1f);
            return this;
        }

        Transform set(const ref Transform other)
        {
            return set(other.translation, other.rotation, other.scale);
        }

        Transform set(const ref v3 t, const ref quat r, const ref v3 s)
        {
            translation = t;
            rotation = r;
            scale = s;
            return this;
        }

        Transform lerp(const ref v3 targetT, const ref quat targetR, const ref v3 targetS, float alpha)
        {
            translation = v3.lerp(translation, targetT, alpha);
            rotation.slerp(targetR, alpha);//quat.slerp(rotation, targetR, alpha);
            scale = v3.lerp(scale, targetS, alpha);
            //translation = targetT;
            //rotation = targetR;
            //scale = targetS;
            return this;
        }

        Transform lerp(const ref Transform transform, float alpha)
        {
            return lerp(transform.translation, transform.rotation, transform.scale, alpha);
        }
    }
}
