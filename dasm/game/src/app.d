module app;

import rt.math;
import rt.time;
import rt.memory;
import rt.dbg;

import dawn.gfx;
import dawn.renderer;
import dawn.gl;
import dawn.mesh;
import dawn.camera;
import dawn.assets;
import dawn.texture;

import states.splash;
import states.login;
import states.gameplay;

enum StateID
{
    NONE,
    SPLASH, LOGIN, GAMEPLAY,
    MAX
}

struct State
{
    alias init_cb_t = void function(State*);
    alias exit_cb_t = void function(State*);
    alias render_cb_t = void function(State*, float dt);

    Context* ctx;
    init_cb_t init_cb;
    render_cb_t render_cb;
    exit_cb_t exit_cb;

    float t_out = 0;
    float t_in = 0;
}

struct Context
{
    State[StateID.MAX] states = [

        StateID.SPLASH: {
            init_cb: &splash_init,
            render_cb: &splash_render,
        },

        StateID.LOGIN: {
            init_cb: &login_init,
            render_cb: &login_render,
        },

        StateID.GAMEPLAY: {
            init_cb: &gameplay_init,
            render_cb: &gameplay_render,
        },
    ];
    StateID curr_state;
    StateID next_state;

    Framebuffer fb;

    bool in_transition = false;
    bool transition_finished = true;

    float transition_time = 0.75;
    float transition_current = 0.0;
}

Context ctx;

void main()
{
    LINFO("main() found");
    create_engine(1280, 720, &on_start, &on_exit, &on_tick);
}

void on_start(Engine* e)
{
    for(int i = 0; i < StateID.MAX; i++)
    {
        auto state = &ctx.states[i];
        state.ctx = &ctx;
        if (state.init_cb)
            state.init_cb(state);
    }

    ctx.fb.create(e.iwidth, e.iheight, true, true, true);
}

void on_exit(Engine* e)
{
    for(int i = 0; i < StateID.MAX; i++)
    {
        auto state = &ctx.states[i];
        if (state.exit_cb)
            state.exit_cb(state);
    }
    LINFO("--end");
}

void on_tick(Engine* e, float dt)
{
    
    if (ctx.curr_state == StateID.NONE && ctx.next_state == StateID.NONE)
    {
        set_state(StateID.SPLASH);
    }

    if (ctx.next_state != StateID.NONE)
    {
        ctx.curr_state = ctx.next_state;
        ctx.next_state = StateID.NONE;
        LINFO("New current state: {}", ctx.next_state);
    }

    ctx.fb.bind();

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0.2, 0.2, 0.6, 1.0);

    auto state = &ctx.states[ctx.curr_state];
    if (state.render_cb)
        state.render_cb(state, dt);
    
    ctx.fb.unbind_n();


    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0.2, 0.2, 0.6, 1.0);
    renderer.state.set_depth_state( DepthState.Default);
    renderer.spritebatch.begin();
    renderer.spritebatch.draw(&ctx.fb.tex_depth, 256, 0, 256, 256, true);
    renderer.spritebatch.draw(&ctx.fb.tex_color, 0, 0, 256, 256, true);
    renderer.spritebatch.draw(&ctx.fb.tex_color, 0, 0, e.width, e.height, true);
    renderer.spritebatch.end();
}

State* get_current_state()
{
    return &ctx.states[ctx.curr_state];
}

void set_state(StateID id)
{
    ctx.next_state = id;
    ctx.states[id].t_in = ctx.transition_time;

    if (ctx.curr_state != StateID.NONE)
        ctx.states[ctx.curr_state].t_out = ctx.transition_time;
}

void draw_fade_in()
{}

void draw_fade_out()
{}
