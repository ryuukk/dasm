module dawn.gfx;

import rt.dbg;
import rt.time;
import rt.math;
import rt.filesystem;

import dawn.gl;
import dawn.renderer;


version(WASM) import wasm;
version(DESKTOP) import glfw;

void check_gl_error(bool exit = true, string file = __FILE__, int line = __LINE__)
{
    // version (WASM)
    // {}
    // else
    // {
    // int err = glGetError();
    // if (err != 0)
    // {
    //     if(exit)
    //         panic("[{}:{}] GL ERROR: {}", file.ptr, line, err);
    //     else
    //         LERRO("[{}:{}] GL ERROR: {}", file.ptr, line, err);
    // }
    // }
}

version (WASM)
{
    export extern(C) void _Unwind_Resume(void* ex){}
}

void create_engine(int width, int height, on_init_t icb, on_exit_t ecb, on_tick_t tcb)
{
    engine.back_buffer_width = width;
    engine.back_buffer_height = height;
    engine.logical_width = width;
    engine.logical_height = height;

    engine.init_cb = icb;
    engine.exit_cb = ecb;
    engine.tick_cb = tcb;

    version(WASM)
    {
        WAJS_setup_canvas(width, height);

        renderer.create(&engine);
        if (icb)
            icb(&engine);
    }
    else
    {
        if (!glfwInit())
        {
            panic("Unable to init glfw");
        }
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
        glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
        glfwWindowHint(GLFW_RESIZABLE, 1);

        // delay window opening to avoid positioning glitch and white window
        glfwWindowHint(GLFW_VISIBLE, 0);

        engine.window_ptr = glfwCreateWindow(width, height, "-game-", null, null);
        if (!engine.window_ptr)
        {
            glfwTerminate();
            panic("Unnable to create window");
        }
		auto primaryMonitor = glfwGetPrimaryMonitor();

        
		auto vidMode = glfwGetVideoMode(primaryMonitor);

		int windowWidth = 0;
		int windowHeight = 0;
		glfwGetWindowSize(engine.window_ptr, &windowWidth, &windowHeight);

		int windowX = vidMode.width / 2 - windowWidth / 2;
		int windowY = vidMode.height / 2 - windowHeight / 2;
		glfwSetWindowPos(engine.window_ptr, windowX, windowY);


            
        glfwMakeContextCurrent(engine.window_ptr);
        glfwSwapInterval(1);

        update_backbuffer_info();

        GLSupport retVal = loadOpenGL();

        // delay window opening to avoid positioning glitch and white window
        glClearColor(0.0f,0.0f,0.0f,1.0f);
        glfwSwapBuffers(engine.window_ptr);
        glfwShowWindow(engine.window_ptr);

            
        glViewport(0, 0, cast(int)engine.width, cast(int)engine.height);

        glfwSetFramebufferSizeCallback(engine.window_ptr, &on_fb_size);

        // window specific callbacks
        glfwSetWindowFocusCallback(engine.window_ptr, &focusCallback);
        glfwSetWindowIconifyCallback(engine.window_ptr, &iconifyCallback);
        //glfwSetWindowMaximizeCallback(engine, &maximizeCallback);
        glfwSetWindowCloseCallback(engine.window_ptr, &closeCallback);
        glfwSetWindowRefreshCallback(engine.window_ptr, &refreshCallback);

        // input callbacks
        glfwSetKeyCallback(engine.window_ptr, &on_key_cb);
        glfwSetCharCallback(engine.window_ptr, &on_char_cb);
        glfwSetScrollCallback(engine.window_ptr, &on_scroll_cb);
        glfwSetCursorPosCallback(engine.window_ptr, &on_cursor_pos_cb);
        glfwSetMouseButtonCallback(engine.window_ptr, &on_mouse_button_cb);


        renderer.create(&engine);
        if (icb)
            icb(&engine);


        while (!engine.closed)
        {
            glfwMakeContextCurrent(engine.window_ptr);
            glfwSwapInterval(1);

            engine.track();

            glViewport(0, 0, engine.back_buffer_width, engine.back_buffer_height);
	        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	        glClearColor(0.2, 0.2, 0.2, 1);

            engine.tick_cb(&engine, engine.delta_time);
            renderer.tick();

            if (engine.iconified == false)
                engine.input.prepare_next();
            
            engine.queue.clear();

            glfwPollEvents();
            glfwSwapBuffers(engine.window_ptr);

            engine.closed = glfwWindowShouldClose(engine.window_ptr) == 1;
        }

        if(engine.exit_cb)
            engine.exit_cb(&engine);
    }
}

version (DESKTOP)
{
    private // GFX callbacks
    {
        void update_backbuffer_info()
        {
            auto window_ptr = engine.window_ptr;
            glfwGetFramebufferSize(window_ptr, &engine.back_buffer_width, &engine.back_buffer_height);
            glfwGetWindowSize(window_ptr, &engine.logical_width, &engine.logical_height);
        }

        extern (C) void on_fb_size(GLFWwindow* window, int width, int height)
        {
            Engine* self = &engine;

            glViewport(0, 0, width, height);

            update_backbuffer_info();
            self.queue.resize(width, height);

            // TODO: i just need to render the scene so it doesn't flicker, this is WRONG
            //self.on_tick(self, self.gfx.delta_time);

            glfwSwapBuffers(window);
        }

        extern (C) void focusCallback(GLFWwindow* window, int focused)
        {
        }

        extern (C) void iconifyCallback(GLFWwindow* window, int iconified)
        {
        }

        extern (C) void maximizeCallback(GLFWwindow* window, int maximized)
        {
        }

        extern (C) void closeCallback(GLFWwindow* window)
        {
        }

        extern (C) void dropCallback(GLFWwindow* window, int count, const(char*)* names)
        {
            for (int i = 0; i < count; i++)
            {
            }
        }

        extern (C) void refreshCallback(GLFWwindow* window)
        {
        }
    }
}

Engine engine;
Renderer renderer;

alias on_init_t = void function(Engine*);
alias on_exit_t = void function(Engine*);
alias on_tick_t = void function(Engine*, float);

struct Engine
{
    version(DESKTOP) GLFWwindow* window_ptr;
    
    int back_buffer_width = -1;
    int back_buffer_height = -1;
    int logical_width = -1;
    int logical_height = -1;

    bool vsync = true;
    bool iconified;
    bool closed;

    on_init_t init_cb;
    on_exit_t exit_cb;
    on_tick_t tick_cb;

    EventQueue queue;
    Input input;

    double last_frame_time = -1;
    float delta_time = 0;
    long frame_id = 0;
    double frame_counter_start = 0;
    int frames = 0;
    int fps = 0;

    
    HdpiMode hdpi_mode = HdpiMode.LOGICAL;

    void track()
    {
        double time = get_time() / 1000.0;

        if (last_frame_time == -1)
            last_frame_time = time;

        delta_time = time - last_frame_time;

        last_frame_time = time;

        if (time - frame_counter_start >= 1) {
            fps = frames;
            frames = 0;
            frame_counter_start = time;
        }

        frames += 1;
        frame_id += 1;
    }

    float width()
    {
        if (hdpi_mode == HdpiMode.PIXEL) {
            return cast(float) back_buffer_width;
        } else {
            return cast(float) logical_width;
        }
    }

    float height()
    {
        if (hdpi_mode == HdpiMode.PIXEL) {
            return cast(float) back_buffer_height;
        } else {
            return cast(float) logical_height;
        }
    }

    int iwidth()
    {
        return cast(int) width();
    }

    int iheight()
    {
        return cast(int) height();
    }
}

struct Input
{
    int mouse_x = 0;
    int mouse_y = 0;
    int mouse_pressed = 0;
    int delta_x = 0;
    int delta_y = 0;
    bool just_touched = false;
    int pressed_keys = 0;
    bool key_just_pressed = false;
    bool[256] just_pressed_keys = void;
    bool[256] keys_down = void;
    char last_character = 0;
    int logical_mouse_x = 0;
    int logical_mouse_y = 0;

    void reset_polling_states()
    {
        just_touched = false;
        key_just_pressed = false;
        for (int i = 0; i < just_pressed_keys.length; i++)
        {
            just_pressed_keys[i] = false;
        }
    }

    void prepare_next()
    {
        just_touched = false;

        if (key_just_pressed)
        {
            key_just_pressed = false;
            for (int i = 0; i < just_pressed_keys.length; i++)
            {
                just_pressed_keys[i] = false;
            }
        }
        delta_x = 0;
        delta_y = 0;
    }
    bool is_key_pressed(Key key)
    {
        if (key == Key.ANY_KEY) return pressed_keys > 0;

        return keys_down[key];
    }
    bool is_key_just_pressed(Key key)
    {
        if (key == Key.ANY_KEY)
            return key_just_pressed;
        if (cast(int) key < 0 || cast(int) key > 256)
            return false;

        return just_pressed_keys[cast(int) key];
    }
}


version (WASM)
{
    export extern (C) void WA_render()
    {
        engine.track();

        if (engine.tick_cb)
            engine.tick_cb(&engine, engine.delta_time);
        
        renderer.tick();

        if (!engine.iconified)
            engine.input.prepare_next();

        engine.queue.clear();
    }

    export extern (C) void on_key_down(int key)
    {
        Key k = js_to_key(key);

        engine.queue.key_down(k);
        engine.input.pressed_keys += 1;
        engine.input.key_just_pressed = true;
        engine.input.just_pressed_keys[k] = true;
        engine.input.last_character = 0;

        engine.input.keys_down[k] = true;
    }

    export extern (C) void on_key_up(int key)
    {
       Key k = js_to_key(key);

       engine.input.pressed_keys -= 1;
    //    engine.input.keys_down[k] = false;

       engine.queue.key_up(k);
    }

    export extern(C) void on_key_press(int codepoint)
    {
        if ((codepoint & 0xff00) == 0xf700)
            return;
        engine.input.last_character = cast(char) codepoint;
        engine.queue.key_typed(cast(char) codepoint);
    }

    export extern (C) void on_mouse_move(float x, float y)
    {
        engine.input.delta_x = cast(int)(x - engine.input.logical_mouse_x);
        engine.input.delta_y = cast(int)(y - engine.input.logical_mouse_y);
        engine.input.mouse_x = cast(int) x;
        engine.input.mouse_y = cast(int) y;
        engine.input.logical_mouse_x = cast(int) x;
        engine.input.logical_mouse_y = cast(int) y;

        if (engine.hdpi_mode == HdpiMode.PIXEL)
        {
            auto xScale = engine.back_buffer_width / cast(float) engine.logical_width;
            auto yScale = engine.back_buffer_height / cast(float) engine.logical_height;
            engine.input.delta_x = cast(int)(engine.input.delta_x * xScale);
            engine.input.delta_y = cast(int)(engine.input.delta_y * yScale);
            engine.input.mouse_x = cast(int)(engine.input.mouse_x * xScale);
            engine.input.mouse_y = cast(int)(engine.input.mouse_y * yScale);
        }
        if (engine.input.mouse_pressed > 0)
        {
            engine.queue.touch_dragged(engine.input.mouse_x, engine.input.mouse_y, 0);
        }
        else
        {
            engine.queue.mouse_moved(engine.input.mouse_x, engine.input.mouse_y);
        }
    }
    
    export extern (C) void on_mouse_down(int button)
    {
        Mouse m = js_to_mouse(button);
        if (m == Mouse.NONE) return;

        engine.input.mouse_pressed += 1;
        engine.input.just_touched = true;
        engine.queue.touch_down(engine.input.mouse_x, engine.input.mouse_y, 0, m);
    }

    export extern (C) void on_mouse_up(int button)
    {
        Mouse m = js_to_mouse(button);
        if (m == Mouse.NONE) return;

        engine.input.mouse_pressed = max(0, engine.input.mouse_pressed - 1);
        engine.queue.touch_up(engine.input.mouse_x, engine.input.mouse_y, 0, m);
    }

    Mouse js_to_mouse(int button)
    {
        switch (button) with (Mouse)
        {
            case 0: return LEFT;
            case 2: return RIGHT;
            case 1: return MIDDLE;
            default: return NONE;
        }
    }

    Key js_to_key(int key)
    {
        switch (key) with(Key) 
        {
            case 0x20:return KEY_SPACE; // DOM_VK_SPACE -> GLFW_KEY_SPACE
            case 0xDE:return KEY_APOSTROPHE; // DOM_VK_QUOTE -> GLFW_KEY_APOSTROPHE
            case 0xBC:return KEY_COMMA; // DOM_VK_COMMA -> GLFW_KEY_COMMA
            case 0xAD:return KEY_MINUS; // DOM_VK_HYPHEN_MINUS -> GLFW_KEY_MINUS
            case 0xBD:return KEY_MINUS; // DOM_VK_MINUS -> GLFW_KEY_MINUS
            case 0xBE:return KEY_PERIOD; // DOM_VK_PERIOD -> GLFW_KEY_PERIOD
            case 0xBF:return KEY_SLASH; // DOM_VK_SLASH -> GLFW_KEY_SLASH
            case 0x30:return KEY_0; // DOM_VK_0 -> GLFW_KEY_0
            case 0x31:return KEY_1; // DOM_VK_1 -> GLFW_KEY_1
            case 0x32:return KEY_2; // DOM_VK_2 -> GLFW_KEY_2
            case 0x33:return KEY_3; // DOM_VK_3 -> GLFW_KEY_3
            case 0x34:return KEY_4; // DOM_VK_4 -> GLFW_KEY_4
            case 0x35:return KEY_5; // DOM_VK_5 -> GLFW_KEY_5
            case 0x36:return KEY_6; // DOM_VK_6 -> GLFW_KEY_6
            case 0x37:return KEY_7; // DOM_VK_7 -> GLFW_KEY_7
            case 0x38:return KEY_8; // DOM_VK_8 -> GLFW_KEY_8
            case 0x39:return KEY_9; // DOM_VK_9 -> GLFW_KEY_9
            case 0x3B:return KEY_SEMICOLON; // DOM_VK_SEMICOLON -> GLFW_KEY_SEMICOLON
            case 0x3D:return KEY_EQUAL; // DOM_VK_EQUALS -> GLFW_KEY_EQUAL
            case 0xBB:return KEY_EQUAL; // DOM_VK_EQUALS -> GLFW_KEY_EQUAL
            case 0x41:return KEY_A; // DOM_VK_A -> GLFW_KEY_A
            case 0x42:return KEY_B; // DOM_VK_B -> GLFW_KEY_B
            case 0x43:return KEY_C; // DOM_VK_C -> GLFW_KEY_C
            case 0x44:return KEY_D; // DOM_VK_D -> GLFW_KEY_D
            case 0x45:return KEY_E; // DOM_VK_E -> GLFW_KEY_E
            case 0x46:return KEY_F; // DOM_VK_F -> GLFW_KEY_F
            case 0x47:return KEY_G; // DOM_VK_G -> GLFW_KEY_G
            case 0x48:return KEY_H; // DOM_VK_H -> GLFW_KEY_H
            case 0x49:return KEY_I; // DOM_VK_I -> GLFW_KEY_I
            case 0x4A:return KEY_J; // DOM_VK_J -> GLFW_KEY_J
            case 0x4B:return KEY_K; // DOM_VK_K -> GLFW_KEY_K
            case 0x4C:return KEY_L; // DOM_VK_L -> GLFW_KEY_L
            case 0x4D:return KEY_M; // DOM_VK_M -> GLFW_KEY_M
            case 0x4E:return KEY_N; // DOM_VK_N -> GLFW_KEY_N
            case 0x4F:return KEY_O; // DOM_VK_O -> GLFW_KEY_O
            case 0x50:return KEY_P; // DOM_VK_P -> GLFW_KEY_P
            case 0x51:return KEY_Q; // DOM_VK_Q -> GLFW_KEY_Q
            case 0x52:return KEY_R; // DOM_VK_R -> GLFW_KEY_R
            case 0x53:return KEY_S; // DOM_VK_S -> GLFW_KEY_S
            case 0x54:return KEY_T; // DOM_VK_T -> GLFW_KEY_T
            case 0x55:return KEY_U; // DOM_VK_U -> GLFW_KEY_U
            case 0x56:return KEY_V; // DOM_VK_V -> GLFW_KEY_V
            case 0x57:return KEY_W; // DOM_VK_W -> GLFW_KEY_W
            case 0x58:return KEY_X; // DOM_VK_X -> GLFW_KEY_X
            case 0x59:return KEY_Y; // DOM_VK_Y -> GLFW_KEY_Y
            case 0x5a:return KEY_Z; // DOM_VK_Z -> GLFW_KEY_Z
            case 0xDB:return KEY_LEFT_BRACKET; // DOM_VK_OPEN_BRACKET -> GLFW_KEY_LEFT_BRACKET
            case 0xDC:return KEY_BACKSLASH; // DOM_VK_BACKSLASH -> GLFW_KEY_BACKSLASH
            case 0xDD:return KEY_RIGHT_BRACKET; // DOM_VK_CLOSE_BRACKET -> GLFW_KEY_RIGHT_BRACKET
            case 0xC0:return KEY_GRAVE_ACCENT; // DOM_VK_BACK_QUOTE -> GLFW_KEY_GRAVE_ACCENT
            case 0x1B:return KEY_ESCAPE; // DOM_VK_ESCAPE -> GLFW_KEY_ESCAPE
            case 0x0D:return KEY_ENTER; // DOM_VK_RETURN -> GLFW_KEY_ENTER
            case 0x09:return KEY_TAB; // DOM_VK_TAB -> GLFW_KEY_TAB
            case 0x08:return KEY_BACKSPACE; // DOM_VK_BACK -> GLFW_KEY_BACKSPACE
            case 0x2D:return KEY_INSERT; // DOM_VK_INSERT -> GLFW_KEY_INSERT
            case 0x2E:return KEY_DELETE; // DOM_VK_DELETE -> GLFW_KEY_DELETE
            case 0x27:return KEY_RIGHT; // DOM_VK_RIGHT -> GLFW_KEY_RIGHT
            case 0x25:return KEY_LEFT; // DOM_VK_LEFT -> GLFW_KEY_LEFT
            case 0x28:return KEY_DOWN; // DOM_VK_DOWN -> GLFW_KEY_DOWN
            case 0x26:return KEY_UP; // DOM_VK_UP -> GLFW_KEY_UP
            case 0x21:return KEY_PAGE_UP; // DOM_VK_PAGE_UP -> GLFW_KEY_PAGE_UP
            case 0x22:return KEY_PAGE_DOWN; // DOM_VK_PAGE_DOWN -> GLFW_KEY_PAGE_DOWN
            case 0x24:return KEY_HOME; // DOM_VK_HOME -> GLFW_KEY_HOME
            case 0x23:return KEY_END; // DOM_VK_END -> GLFW_KEY_END
            case 0x14:return KEY_CAPS_LOCK; // DOM_VK_CAPS_LOCK -> GLFW_KEY_CAPS_LOCK
            case 0x91:return KEY_SCROLL_LOCK; // DOM_VK_SCROLL_LOCK -> GLFW_KEY_SCROLL_LOCK
            case 0x90:return KEY_NUM_LOCK; // DOM_VK_NUM_LOCK -> GLFW_KEY_NUM_LOCK
            case 0x2C:return KEY_PRINT_SCREEN; // DOM_VK_SNAPSHOT -> GLFW_KEY_PRINT_SCREEN
            case 0x13:return KEY_PAUSE; // DOM_VK_PAUSE -> GLFW_KEY_PAUSE
            case 0x70:return KEY_F1; // DOM_VK_F1 -> GLFW_KEY_F1
            case 0x71:return KEY_F2; // DOM_VK_F2 -> GLFW_KEY_F2
            case 0x72:return KEY_F3; // DOM_VK_F3 -> GLFW_KEY_F3
            case 0x73:return KEY_F4; // DOM_VK_F4 -> GLFW_KEY_F4
            case 0x74:return KEY_F5; // DOM_VK_F5 -> GLFW_KEY_F5
            case 0x75:return KEY_F6; // DOM_VK_F6 -> GLFW_KEY_F6
            case 0x76:return KEY_F7; // DOM_VK_F7 -> GLFW_KEY_F7
            case 0x77:return KEY_F8; // DOM_VK_F8 -> GLFW_KEY_F8
            case 0x78:return KEY_F9; // DOM_VK_F9 -> GLFW_KEY_F9
            case 0x79:return KEY_F10; // DOM_VK_F10 -> GLFW_KEY_F10
            case 0x7A:return KEY_F11; // DOM_VK_F11 -> GLFW_KEY_F11
            case 0x7B:return KEY_F12; // DOM_VK_F12 -> GLFW_KEY_F12
            case 0x60:return KEY_KP_0; // DOM_VK_NUMPAD0 -> GLFW_KEY_KP_0
            case 0x61:return KEY_KP_1; // DOM_VK_NUMPAD1 -> GLFW_KEY_KP_1
            case 0x62:return KEY_KP_2; // DOM_VK_NUMPAD2 -> GLFW_KEY_KP_2
            case 0x63:return KEY_KP_3; // DOM_VK_NUMPAD3 -> GLFW_KEY_KP_3
            case 0x64:return KEY_KP_4; // DOM_VK_NUMPAD4 -> GLFW_KEY_KP_4
            case 0x65:return KEY_KP_5; // DOM_VK_NUMPAD5 -> GLFW_KEY_KP_5
            case 0x66:return KEY_KP_6; // DOM_VK_NUMPAD6 -> GLFW_KEY_KP_6
            case 0x67:return KEY_KP_7; // DOM_VK_NUMPAD7 -> GLFW_KEY_KP_7
            case 0x68:return KEY_KP_8; // DOM_VK_NUMPAD8 -> GLFW_KEY_KP_8
            case 0x69:return KEY_KP_9; // DOM_VK_NUMPAD9 -> GLFW_KEY_KP_9
            case 0x6E:return KEY_KP_DECIMAL; // DOM_VK_DECIMAL -> GLFW_KEY_KP_DECIMAL
            case 0x6F:return KEY_KP_DIVIDE; // DOM_VK_DIVIDE -> GLFW_KEY_KP_DIVIDE
            case 0x6A:return KEY_KP_MULTIPLY; // DOM_VK_MULTIPLY -> GLFW_KEY_KP_MULTIPLY
            case 0x6D:return KEY_KP_SUBTRACT; // DOM_VK_SUBTRACT -> GLFW_KEY_KP_SUBTRACT
            case 0x6B:return KEY_KP_ADD; // DOM_VK_ADD -> GLFW_KEY_KP_ADD
            // case 0x0D:return 335; // DOM_VK_RETURN -> GLFW_KEY_KP_ENTER (DOM_KEY_LOCATION_RIGHT)
            // case 0x61:return 336; // DOM_VK_EQUALS -> GLFW_KEY_KP_EQUAL (DOM_KEY_LOCATION_RIGHT)
            case 0x10:return KEY_LEFT_SHIFT; // DOM_VK_SHIFT -> GLFW_KEY_LEFT_SHIFT
            case 0x11:return KEY_LEFT_CONTROL; // DOM_VK_CONTROL -> GLFW_KEY_LEFT_CONTROL
            case 0x12:return KEY_LEFT_ALT; // DOM_VK_ALT -> GLFW_KEY_LEFT_ALT
            case 0x5B:return KEY_LEFT_SUPER; // DOM_VK_WIN -> GLFW_KEY_LEFT_SUPER
            // case 0x10:return 344; // DOM_VK_SHIFT -> GLFW_KEY_RIGHT_SHIFT (DOM_KEY_LOCATION_RIGHT)
            // case 0x11:return 345; // DOM_VK_CONTROL -> GLFW_KEY_RIGHT_CONTROL (DOM_KEY_LOCATION_RIGHT)
            // case 0x12:return 346; // DOM_VK_ALT -> GLFW_KEY_RIGHT_ALT (DOM_KEY_LOCATION_RIGHT)
            // case 0x5B:return 347; // DOM_VK_WIN -> GLFW_KEY_RIGHT_SUPER (DOM_KEY_LOCATION_RIGHT)
            case 0x5D:return KEY_MENU; // DOM_VK_CONTEXT_MENU -> GLFW_KEY_MENU
            // XXX: GLFW_KEY_WORLD_1, GLFW_KEY_WORLD_2 what are these?
            default: return UNKNOWN;
         }
    }
}
else
{
private // INPUT callbacks
{
    extern (C) void on_key_cb(GLFWwindow* window, int key, int scancode, int action, int mods)
    {
        Engine* self = &engine;
        switch (action)
        {
        case GLFW_PRESS:
            auto convertedKey = glfw_to_keycode(key);
            self.queue.key_down(convertedKey);
            self.input.pressed_keys += 1;
            self.input.key_just_pressed = true;
            self.input.just_pressed_keys[convertedKey] = true;
            self.input.last_character = 0;
            //auto character = keycode_to_char(convertedKey);
            //if (character != 0)
            //    on_char_cb(window, cast(uint) character);
            break;

        case GLFW_RELEASE:
            auto convertedKey = glfw_to_keycode(key);
            self.input.pressed_keys -= 1;
            self.queue.key_up(convertedKey);
            break;

        case GLFW_REPEAT:
            break;

        default:
            break;
        }
    }

    extern (C) void on_char_cb(GLFWwindow* window, uint codepoint)
    {
        if ((codepoint & 0xff00) == 0xf700)
            return;

        Engine* self = &engine;

        self.input.last_character = cast(char) codepoint;
        self.queue.key_typed(cast(char) codepoint);
    }

    extern (C) void on_scroll_cb(GLFWwindow* window, double scrollX, double scrollY)
    {
        Engine* self = &engine;
        self.queue.scrolled(- cast(int)scrollY); // TODO: should be float?
    }

    extern (C) void on_cursor_pos_cb(GLFWwindow* window, double x, double y)
    {
        //Core.input.onCursorPosCallback(x, y);
        Engine* self = &engine;

        self.input.delta_x = cast(int)(x - self.input.logical_mouse_x);
        self.input.delta_y = cast(int)(y - self.input.logical_mouse_y);
        self.input.mouse_x = cast(int) x;
        self.input.mouse_y = cast(int) y;
        self.input.logical_mouse_x = cast(int) x;
        self.input.logical_mouse_y = cast(int) y;

        if (self.hdpi_mode == HdpiMode.PIXEL)
        {
            auto xScale = self.back_buffer_width / cast(float) self.logical_width;
            auto yScale = self.back_buffer_height / cast(float) self.logical_height;
            self.input.delta_x = cast(int)(self.input.delta_x * xScale);
            self.input.delta_y = cast(int)(self.input.delta_y * yScale);
            self.input.mouse_x = cast(int)(self.input.mouse_x * xScale);
            self.input.mouse_y = cast(int)(self.input.mouse_y * yScale);
        }
        if (self.input.mouse_pressed > 0)
        {
            self.queue.touch_dragged(self.input.mouse_x, self.input.mouse_y, 0);
        }
        else
        {
            self.queue.mouse_moved(self.input.mouse_x, self.input.mouse_y);
        }
    }

    extern (C) void on_mouse_button_cb(GLFWwindow* window, int button, int action, int mods)
    {
        Engine* self = &engine;

        int cbntn = convert_glfw_button(button);
        if(button != -1 && cbntn == -1)
            return;

        if(action == GLFW_PRESS)
        {
            self.input.mouse_pressed++;
            self.input.just_touched = true;
            self.queue.touch_down(self.input.mouse_x, self.input.mouse_y, 0, cbntn);
        }
        else 
        {
            self.input.mouse_pressed = max(0, self.input.mouse_pressed - 1); // todo: only accepts float? 
            self.queue.touch_up(self.input.mouse_x, self.input.mouse_y, 0, cbntn);
        }
    }
    
    Key glfw_to_keycode(int key)
    {
        switch (key) with(Key) 
        {
            case GLFW_KEY_SPACE:return KEY_SPACE; // DOM_VK_SPACE -> GLFW_KEY_SPACE
            case GLFW_KEY_APOSTROPHE:return KEY_APOSTROPHE; // DOM_VK_QUOTE -> GLFW_KEY_APOSTROPHE
            case GLFW_KEY_COMMA:return KEY_COMMA; // DOM_VK_COMMA -> GLFW_KEY_COMMA
            case GLFW_KEY_MINUS:return KEY_MINUS; // DOM_VK_HYPHEN_MINUS -> GLFW_KEY_MINUS
            case GLFW_KEY_PERIOD:return KEY_PERIOD; // DOM_VK_PERIOD -> GLFW_KEY_PERIOD
            case GLFW_KEY_SLASH:return KEY_SLASH; // DOM_VK_SLASH -> GLFW_KEY_SLASH
            case GLFW_KEY_0:return KEY_0; // DOM_VK_0 -> GLFW_KEY_0
            case GLFW_KEY_1:return KEY_1; // DOM_VK_1 -> GLFW_KEY_1
            case GLFW_KEY_2:return KEY_2; // DOM_VK_2 -> GLFW_KEY_2
            case GLFW_KEY_3:return KEY_3; // DOM_VK_3 -> GLFW_KEY_3
            case GLFW_KEY_4:return KEY_4; // DOM_VK_4 -> GLFW_KEY_4
            case GLFW_KEY_5:return KEY_5; // DOM_VK_5 -> GLFW_KEY_5
            case GLFW_KEY_6:return KEY_6; // DOM_VK_6 -> GLFW_KEY_6
            case GLFW_KEY_7:return KEY_7; // DOM_VK_7 -> GLFW_KEY_7
            case GLFW_KEY_8:return KEY_8; // DOM_VK_8 -> GLFW_KEY_8
            case GLFW_KEY_9:return KEY_9; // DOM_VK_9 -> GLFW_KEY_9
            case GLFW_KEY_SEMICOLON:return KEY_SEMICOLON; // DOM_VK_SEMICOLON -> GLFW_KEY_SEMICOLON
            case GLFW_KEY_EQUAL:return KEY_EQUAL; // DOM_VK_EQUALS -> GLFW_KEY_EQUAL
            case GLFW_KEY_A:return KEY_A; // DOM_VK_A -> GLFW_KEY_A
            case GLFW_KEY_B:return KEY_B; // DOM_VK_B -> GLFW_KEY_B
            case GLFW_KEY_C:return KEY_C; // DOM_VK_C -> GLFW_KEY_C
            case GLFW_KEY_D:return KEY_D; // DOM_VK_D -> GLFW_KEY_D
            case GLFW_KEY_E:return KEY_E; // DOM_VK_E -> GLFW_KEY_E
            case GLFW_KEY_F:return KEY_F; // DOM_VK_F -> GLFW_KEY_F
            case GLFW_KEY_G:return KEY_G; // DOM_VK_G -> GLFW_KEY_G
            case GLFW_KEY_H:return KEY_H; // DOM_VK_H -> GLFW_KEY_H
            case GLFW_KEY_I:return KEY_I; // DOM_VK_I -> GLFW_KEY_I
            case GLFW_KEY_J:return KEY_J; // DOM_VK_J -> GLFW_KEY_J
            case GLFW_KEY_K:return KEY_K; // DOM_VK_K -> GLFW_KEY_K
            case GLFW_KEY_L:return KEY_L; // DOM_VK_L -> GLFW_KEY_L
            case GLFW_KEY_M:return KEY_M; // DOM_VK_M -> GLFW_KEY_M
            case GLFW_KEY_N:return KEY_N; // DOM_VK_N -> GLFW_KEY_N
            case GLFW_KEY_O:return KEY_O; // DOM_VK_O -> GLFW_KEY_O
            case GLFW_KEY_P:return KEY_P; // DOM_VK_P -> GLFW_KEY_P
            case GLFW_KEY_Q:return KEY_Q; // DOM_VK_Q -> GLFW_KEY_Q
            case GLFW_KEY_R:return KEY_R; // DOM_VK_R -> GLFW_KEY_R
            case GLFW_KEY_S:return KEY_S; // DOM_VK_S -> GLFW_KEY_S
            case GLFW_KEY_T:return KEY_T; // DOM_VK_T -> GLFW_KEY_T
            case GLFW_KEY_U:return KEY_U; // DOM_VK_U -> GLFW_KEY_U
            case GLFW_KEY_V:return KEY_V; // DOM_VK_V -> GLFW_KEY_V
            case GLFW_KEY_W:return KEY_W; // DOM_VK_W -> GLFW_KEY_W
            case GLFW_KEY_X:return KEY_X; // DOM_VK_X -> GLFW_KEY_X
            case GLFW_KEY_Y:return KEY_Y; // DOM_VK_Y -> GLFW_KEY_Y
            case GLFW_KEY_Z:return KEY_Z; // DOM_VK_Z -> GLFW_KEY_Z
            case GLFW_KEY_LEFT_BRACKET:return KEY_LEFT_BRACKET; // DOM_VK_OPEN_BRACKET -> GLFW_KEY_LEFT_BRACKET
            case GLFW_KEY_BACKSLASH:return KEY_BACKSLASH; // DOM_VK_BACKSLASH -> GLFW_KEY_BACKSLASH
            case GLFW_KEY_RIGHT_BRACKET:return KEY_RIGHT_BRACKET; // DOM_VK_CLOSE_BRACKET -> GLFW_KEY_RIGHT_BRACKET
            case GLFW_KEY_GRAVE_ACCENT:return KEY_GRAVE_ACCENT; // DOM_VK_BACK_QUOTE -> GLFW_KEY_GRAVE_ACCENT
            case GLFW_KEY_ESCAPE:return KEY_ESCAPE; // DOM_VK_ESCAPE -> GLFW_KEY_ESCAPE
            case GLFW_KEY_ENTER:return KEY_ENTER; // DOM_VK_RETURN -> GLFW_KEY_ENTER
            case GLFW_KEY_TAB:return KEY_TAB; // DOM_VK_TAB -> GLFW_KEY_TAB
            case GLFW_KEY_BACKSPACE:return KEY_BACKSPACE; // DOM_VK_BACK -> GLFW_KEY_BACKSPACE
            case GLFW_KEY_INSERT:return KEY_INSERT; // DOM_VK_INSERT -> GLFW_KEY_INSERT
            case GLFW_KEY_DELETE:return KEY_DELETE; // DOM_VK_DELETE -> GLFW_KEY_DELETE
            case GLFW_KEY_RIGHT:return KEY_RIGHT; // DOM_VK_RIGHT -> GLFW_KEY_RIGHT
            case GLFW_KEY_LEFT:return KEY_LEFT; // DOM_VK_LEFT -> GLFW_KEY_LEFT
            case GLFW_KEY_DOWN:return KEY_DOWN; // DOM_VK_DOWN -> GLFW_KEY_DOWN
            case GLFW_KEY_UP:return KEY_UP; // DOM_VK_UP -> GLFW_KEY_UP
            case GLFW_KEY_PAGE_UP:return KEY_PAGE_UP; // DOM_VK_PAGE_UP -> GLFW_KEY_PAGE_UP
            case GLFW_KEY_PAGE_DOWN:return KEY_PAGE_DOWN; // DOM_VK_PAGE_DOWN -> GLFW_KEY_PAGE_DOWN
            case GLFW_KEY_HOME:return KEY_HOME; // DOM_VK_HOME -> GLFW_KEY_HOME
            case GLFW_KEY_END:return KEY_END; // DOM_VK_END -> GLFW_KEY_END
            case GLFW_KEY_CAPS_LOCK:return KEY_CAPS_LOCK; // DOM_VK_CAPS_LOCK -> GLFW_KEY_CAPS_LOCK
            case GLFW_KEY_SCROLL_LOCK:return KEY_SCROLL_LOCK; // DOM_VK_SCROLL_LOCK -> GLFW_KEY_SCROLL_LOCK
            case GLFW_KEY_NUM_LOCK:return KEY_NUM_LOCK; // DOM_VK_NUM_LOCK -> GLFW_KEY_NUM_LOCK
            case GLFW_KEY_PRINT_SCREEN:return KEY_PRINT_SCREEN; // DOM_VK_SNAPSHOT -> GLFW_KEY_PRINT_SCREEN
            case GLFW_KEY_PAUSE:return KEY_PAUSE; // DOM_VK_PAUSE -> GLFW_KEY_PAUSE
            case GLFW_KEY_F1:return KEY_F1; // DOM_VK_F1 -> GLFW_KEY_F1
            case GLFW_KEY_F2:return KEY_F2; // DOM_VK_F2 -> GLFW_KEY_F2
            case GLFW_KEY_F3:return KEY_F3; // DOM_VK_F3 -> GLFW_KEY_F3
            case GLFW_KEY_F4:return KEY_F4; // DOM_VK_F4 -> GLFW_KEY_F4
            case GLFW_KEY_F5:return KEY_F5; // DOM_VK_F5 -> GLFW_KEY_F5
            case GLFW_KEY_F6:return KEY_F6; // DOM_VK_F6 -> GLFW_KEY_F6
            case GLFW_KEY_F7:return KEY_F7; // DOM_VK_F7 -> GLFW_KEY_F7
            case GLFW_KEY_F8:return KEY_F8; // DOM_VK_F8 -> GLFW_KEY_F8
            case GLFW_KEY_F9:return KEY_F9; // DOM_VK_F9 -> GLFW_KEY_F9
            case GLFW_KEY_F10:return KEY_F10; // DOM_VK_F10 -> GLFW_KEY_F10
            case GLFW_KEY_F11:return KEY_F11; // DOM_VK_F11 -> GLFW_KEY_F11
            case GLFW_KEY_F12:return KEY_F12; // DOM_VK_F12 -> GLFW_KEY_F12
            case GLFW_KEY_KP_0:return KEY_KP_0; // DOM_VK_NUMPAD0 -> GLFW_KEY_KP_0
            case GLFW_KEY_KP_1:return KEY_KP_1; // DOM_VK_NUMPAD1 -> GLFW_KEY_KP_1
            case GLFW_KEY_KP_2:return KEY_KP_2; // DOM_VK_NUMPAD2 -> GLFW_KEY_KP_2
            case GLFW_KEY_KP_3:return KEY_KP_3; // DOM_VK_NUMPAD3 -> GLFW_KEY_KP_3
            case GLFW_KEY_KP_4:return KEY_KP_4; // DOM_VK_NUMPAD4 -> GLFW_KEY_KP_4
            case GLFW_KEY_KP_5:return KEY_KP_5; // DOM_VK_NUMPAD5 -> GLFW_KEY_KP_5
            case GLFW_KEY_KP_6:return KEY_KP_6; // DOM_VK_NUMPAD6 -> GLFW_KEY_KP_6
            case GLFW_KEY_KP_7:return KEY_KP_7; // DOM_VK_NUMPAD7 -> GLFW_KEY_KP_7
            case GLFW_KEY_KP_8:return KEY_KP_8; // DOM_VK_NUMPAD8 -> GLFW_KEY_KP_8
            case GLFW_KEY_KP_9:return KEY_KP_9; // DOM_VK_NUMPAD9 -> GLFW_KEY_KP_9
            case GLFW_KEY_KP_DECIMAL:return KEY_KP_DECIMAL; // DOM_VK_DECIMAL -> GLFW_KEY_KP_DECIMAL
            case GLFW_KEY_KP_DIVIDE:return KEY_KP_DIVIDE; // DOM_VK_DIVIDE -> GLFW_KEY_KP_DIVIDE
            case GLFW_KEY_KP_MULTIPLY:return KEY_KP_MULTIPLY; // DOM_VK_MULTIPLY -> GLFW_KEY_KP_MULTIPLY
            case GLFW_KEY_KP_SUBTRACT:return KEY_KP_SUBTRACT; // DOM_VK_SUBTRACT -> GLFW_KEY_KP_SUBTRACT
            case GLFW_KEY_KP_ADD:return KEY_KP_ADD; // DOM_VK_ADD -> GLFW_KEY_KP_ADD
            // case 0x0D:return 335; // DOM_VK_RETURN -> GLFW_KEY_KP_ENTER (DOM_KEY_LOCATION_RIGHT)
            // case 0x61:return 336; // DOM_VK_EQUALS -> GLFW_KEY_KP_EQUAL (DOM_KEY_LOCATION_RIGHT)
            case GLFW_KEY_LEFT_SHIFT:return KEY_LEFT_SHIFT; // DOM_VK_SHIFT -> GLFW_KEY_LEFT_SHIFT
            case GLFW_KEY_LEFT_CONTROL:return KEY_LEFT_CONTROL; // DOM_VK_CONTROL -> GLFW_KEY_LEFT_CONTROL
            case GLFW_KEY_LEFT_ALT:return KEY_LEFT_ALT; // DOM_VK_ALT -> GLFW_KEY_LEFT_ALT
            case GLFW_KEY_LEFT_SUPER:return KEY_LEFT_SUPER; // DOM_VK_WIN -> GLFW_KEY_LEFT_SUPER
            // case 0x10:return 344; // DOM_VK_SHIFT -> GLFW_KEY_RIGHT_SHIFT (DOM_KEY_LOCATION_RIGHT)
            // case 0x11:return 345; // DOM_VK_CONTROL -> GLFW_KEY_RIGHT_CONTROL (DOM_KEY_LOCATION_RIGHT)
            // case 0x12:return 346; // DOM_VK_ALT -> GLFW_KEY_RIGHT_ALT (DOM_KEY_LOCATION_RIGHT)
            // case 0x5B:return 347; // DOM_VK_WIN -> GLFW_KEY_RIGHT_SUPER (DOM_KEY_LOCATION_RIGHT)
            case GLFW_KEY_MENU:return KEY_MENU; // DOM_VK_CONTEXT_MENU -> GLFW_KEY_MENU
            // XXX: GLFW_KEY_WORLD_1, GLFW_KEY_WORLD_2 what are these?
            default: return UNKNOWN;
         }
    }

    Mouse convert_glfw_button(int button)
    {
        switch (button) with (Mouse)
        {
            case 0: return LEFT;
            case 1: return RIGHT;
            case 2: return MIDDLE;
            default: return NONE;
        }
    }
}
}


// events
enum EventType: ubyte
{
    QUIT,

    GFX_RESIZE,

    INPUT_KEY_DOWN,
    INPUT_KEY_UP,
    INPUT_KEY_TYPED,
    INPUT_TOUCH_DOWN,
    INPUT_TOUCH_UP,
    INPUT_TOUCH_DRAGGED,
    INPUT_MOUSE_MOVED,
    INPUT_SCROLLED,
}

struct Event
{
    long time;
    EventType type;
    bool consumed;
    union
    {
        // GFX
        Resize resize;

        // INPUT
        KeyDown key_down;
        KeyUp key_up;
        KeyTyped key_typed;
        TouchDown touch_down;
        TouchUp touch_up;
        TouchDragged touch_dragged;
        TouchMoved touch_moved;
        Scrolled scrolled;
    }
}


struct Resize
{
    int width;
    int height;
}

struct KeyDown
{
    int key;
}

struct KeyUp
{
    int key;
}

struct KeyTyped
{
    char character;
}

struct TouchDown
{
    int screen_x;
    int screen_y;
    int pointer;
    int button;
}

struct TouchUp
{
    int screen_x;
    int screen_y;
    int pointer;
    int button;
}

struct TouchDragged
{
    int screen_x;
    int screen_y;
    int pointer;
}

struct TouchMoved
{
    int screen_x;
    int screen_y;
}

struct Scrolled
{
    int amount;
}


enum MAX_QUEUD_EVENTS = 16;
struct EventQueue
{
    Event[MAX_QUEUD_EVENTS] queue = void;
    long current_event_time = 0;
    int queue_C = 0;
    
    void clear()
    {
        queue_C = 0;
    }
    
    int opApply(scope int delegate(Event*) dg)
    {
        int result;
        for (int i = 0; i < queue_C; i++)
        {
            auto e = &queue[i];
            if(e.consumed) continue;
            
            current_event_time = e.time;

            if ((result = dg(e)) != 0)
                break;
        }
        return result;
    }

    /*
        queue.on_key_down {
        }
    */

    bool resize(int width, int height) {
        Event e;
        e.time = get_time();
        e.type = EventType.GFX_RESIZE;
        e.resize.width = width;
        e.resize.height = height;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool key_down(int keycode) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_KEY_DOWN;
        e.key_down.key = keycode;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool key_up(int keycode) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_KEY_UP;
        e.key_up.key = keycode;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool key_typed(char character) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_KEY_TYPED;
        e.key_typed.character = character;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool touch_down(int screenX, int screenY, int pointer, int button) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_TOUCH_DOWN;
        e.touch_down.screen_x = screenX;
        e.touch_down.screen_y = screenY;
        e.touch_down.pointer = pointer;
        e.touch_down.button = button;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool touch_up(int screenX, int screenY, int pointer, int button) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_TOUCH_UP;
        e.touch_up.screen_x = screenX;
        e.touch_up.screen_y = screenY;
        e.touch_up.pointer = pointer;
        e.touch_up.button = button;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool touch_dragged(int screenX, int screenY, int pointer) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_TOUCH_DRAGGED;
        e.touch_dragged.screen_x = screenX;
        e.touch_dragged.screen_y = screenY;
        e.touch_dragged.pointer = pointer;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool mouse_moved(int screenX, int screenY) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_MOUSE_MOVED;
        e.touch_moved.screen_x = screenX;
        e.touch_moved.screen_y = screenY;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }

    bool scrolled(int amount) {
        Event e;
        e.time = get_time();
        e.type = EventType.INPUT_SCROLLED;
        e.scrolled.amount = amount;

        queue[queue_C] = e;
        queue_C = (queue_C + 1) % MAX_QUEUD_EVENTS;
        return false;
    }
}



enum Key
{
    UNKNOWN,
    KEY_SPACE,
    KEY_APOSTROPHE,
    KEY_COMMA,
    KEY_MINUS,
    KEY_PERIOD,
    KEY_SLASH,
    KEY_0,
    KEY_1,
    KEY_2,
    KEY_3,
    KEY_4,
    KEY_5,
    KEY_6,
    KEY_7,
    KEY_8,
    KEY_9,
    KEY_SEMICOLON,
    KEY_EQUAL,
    KEY_A,
    KEY_B,
    KEY_C,
    KEY_D,
    KEY_E,
    KEY_F,
    KEY_G,
    KEY_H,
    KEY_I,
    KEY_J,
    KEY_K,
    KEY_L,
    KEY_M,
    KEY_N,
    KEY_O,
    KEY_P,
    KEY_Q,
    KEY_R,
    KEY_S,
    KEY_T,
    KEY_U,
    KEY_V,
    KEY_W,
    KEY_X,
    KEY_Y,
    KEY_Z,
    KEY_LEFT_BRACKET,
    KEY_BACKSLASH,
    KEY_RIGHT_BRACKET,
    KEY_GRAVE_ACCENT,
    KEY_ESCAPE,
    KEY_ENTER,
    KEY_TAB,
    KEY_BACKSPACE,
    KEY_INSERT,
    KEY_DELETE,
    KEY_RIGHT,
    KEY_LEFT,
    KEY_DOWN,
    KEY_UP,
    KEY_PAGE_UP,
    KEY_PAGE_DOWN,
    KEY_HOME,
    KEY_END,
    KEY_CAPS_LOCK,
    KEY_SCROLL_LOCK,
    KEY_NUM_LOCK,
    KEY_PRINT_SCREEN,
    KEY_PAUSE,
    KEY_F1,
    KEY_F2,
    KEY_F3,
    KEY_F4,
    KEY_F5,
    KEY_F6,
    KEY_F7,
    KEY_F8,
    KEY_F9,
    KEY_F10,
    KEY_F11,
    KEY_F12,
    KEY_KP_0,
    KEY_KP_1,
    KEY_KP_2,
    KEY_KP_3,
    KEY_KP_4,
    KEY_KP_5,
    KEY_KP_6,
    KEY_KP_7,
    KEY_KP_8,
    KEY_KP_9,
    KEY_KP_DECIMAL,
    KEY_KP_DIVIDE,
    KEY_KP_MULTIPLY,
    KEY_KP_SUBTRACT,
    KEY_KP_ADD,
    KEY_LEFT_SHIFT,
    KEY_LEFT_CONTROL,
    KEY_LEFT_ALT,
    KEY_LEFT_SUPER,
    KEY_MENU,
    
    ANY_KEY
}

enum Mouse
{
    NONE,
    LEFT,
    RIGHT,
    MIDDLE
}

enum HdpiMode 
{
    LOGICAL, PIXEL
}


