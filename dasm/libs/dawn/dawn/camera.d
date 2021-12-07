module dawn.camera;

import rt.math;


struct Camera 
{
    bool is_perspective;
    v3 position = v3(0,0, 0);
    v3 direction = v3(0,0, -1);
    v3 up = v3(0,1, 0);

    mat4 projection = mat4.identity();
    mat4 view = mat4.identity();
    mat4 combined = mat4.identity();
    mat4 inv_projection_view = mat4.identity();

    float near = 1.0;
    float far = 100.0;
    float viewport_width = 0.0;
    float viewport_height = 0.0;

    bool perspective = true;
    float fov = 67;
    float zoom = 1.0;

    static Camera init_ortho(float w, float h, bool ydown = false) {
        Camera ret;
        ret.perspective = false;
        ret.viewport_width = w;
        ret.viewport_height = h;
        ret.near = 0.0;

        if(ydown)
        {
            ret.up = v3.set(0, -1, 0);
            ret.direction = v3.set(0, 0, 1);
        }
        else
        {
            ret.up = v3.set(0, 1, 0);
            ret.direction = v3.set(0, 0, -1);
        }
            ret.position = v3.set(w * 0.5, h * 0.5, 0);
        ret.update();
        return ret;
    }
    
    static Camera init_perspective(float fov, float w, float h) {
        Camera ret;
        ret.perspective = true;
        ret.fov = fov;
        ret.viewport_width = w;
        ret.viewport_height = h;
        ret.near = 0.1;
        ret.update();
        return ret;
    }

    void update() {
        if (perspective) {
            update_perspective();
        } else {
            update_orthographic();
        }
    }

    void update_perspective() {
        float aspect = viewport_width / viewport_height;
        projection = mat4.create_projection(abs(near), abs(far), fov, aspect);

        view = mat4.create_look_at(position, position + direction, up);

        // TODO: double check
        combined = projection * view;
    }

    void update_orthographic() {
        projection = mat4.create_orthographic(
            zoom * -viewport_width * 0.5,
            zoom * (viewport_width * 0.5),
            zoom * -(viewport_height * 0.5),
            zoom * viewport_height * 0.5,
            near, far
        );

        view = mat4.create_look_at(position, position + direction, up);
        combined = projection * view;
    }

    void look_at(float x, float y, float z)
    {
        auto tmpVec = (v3(x, y, z) - position).nor();

        if (!tmpVec.is_zero())
        {
            float dot = tmpVec.dot(up); // up and direction must ALWAYS be orthonormal vectors
            if ( abs(dot - 1) < 0.000000001f)
            {
                // Collinear
                up = direction * -1;
            }
            else if (abs(dot + 1) < 0.000000001f)
            {
                // Collinear opposite
                up = direction;
            }
            direction = tmpVec;
            normalize_up();
        }
    }
    
    void normalize_up()
    {
        auto tmpVec = direction.crs(up).nor();
        up = tmpVec.crs(direction).nor();
    }

    void rotate(in v3 axis, float angle)
    {
            direction = v3.rotate(direction, axis, angle);
            up = v3.rotate(up, axis, angle);
    }

    /// world to screen
    v3 project(v3 world, float vp_x, float vp_y, float vp_w, float vp_h)
    {
        world.prj(combined);
        world.x = vp_w * (world.x + 1) / 2 + vp_x;
		world.y = vp_h * (world.y + 1) / 2 + vp_y;
		world.z = (world.z + 1) / 2;
		return world;
    }

    /// screen to world
    /*
    v3 unproject (v3 screen, float vpx, float vpy, float vpw, float vph, float screenHeight) 
    {
		float x = screen.x - vpx, y = screenHeight - screen.y - vpy;
		screen.x = (2 * x) / vpw - 1;
		screen.y = (2 * y) / vph - 1;
		screen.z = 2 * screen.z - 1;
		screen.prj(inv_projection_view);
		return screen;
	}

    Ray get_pick_ray(float screenX, float screenY, float vpx, float vpy, float vpw, float vph) {
        Ray ray;
        ray.origin = v3(screenX, screenY, 0);
        ray.direction = v3(screenX, screenY, 1);
		unproject(ray.origin, vpx, vpy, vpw, vph);
		unproject(ray.direction, vpx, vpy, vpw, vph);
		ray.direction -= ray.origin;
        ray.direction = ray.direction.nor();
		return ray;
	}
    */
}
