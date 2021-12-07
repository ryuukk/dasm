module dawn.microui;

version (DESKTOP):

import core.stdc.stdlib;
import core.stdc.stdio;
//import core.stdc.string;

import rt.memory;
import rt.str;
import rt.dbg;

enum VERSION = "2.01";
enum LAST_COMMIT = "05d7b46c9cf650dd0c5fbc83a9bebf87c80d02a5";

enum COMMANDLIST_SIZE = (256 * 1024);
enum ROOTLIST_SIZE = 32;
enum CONTAINERSTACK_SIZE = 32;
enum CLIPSTACK_SIZE = 32;
enum IDSTACK_SIZE = 32;
enum LAYOUTSTACK_SIZE = 16;
enum CONTAINERPOOL_SIZE = 48;
enum TREENODEPOOL_SIZE = 48;
enum MAX_WIDTHS = 16;
alias REAL = float;
enum REAL_FMT = "%.3g";
enum SLIDER_FMT = "%.2f";
enum MAX_FMT = 127;


alias cmp_cb = extern(C) int function(const(void*), const(void*));

// TODO: implement for WASM
extern(C) void qsort (
  void* base,
  ulong nmemb,
  ulong size,
  cmp_cb compare
);
extern(C) int sprintf (
  scope char* s,
  scope const(char*) format, ...
);
extern(C) double strtod (
  scope inout(char)* nptr,
  scope inout(char)** endptr
);

T min(T)(T a, T b) { return a < b ? a : b; }
T max(T)(T a, T b) { return a > b ? a : b; }
T clamp(T)(T x, T a, T b) { return min(b, max(a, x)); }

enum {
  CLIP_PART = 1,
  CLIP_ALL
}

enum {
  COMMAND_JUMP = 1,
  COMMAND_CLIP,
  COMMAND_RECT,
  COMMAND_TEXT,
  COMMAND_ICON,
  COMMAND_MAX
}

enum {
  COLOR_TEXT,
  COLOR_BORDER,
  COLOR_WINDOWBG,
  COLOR_TITLEBG,
  COLOR_TITLETEXT,
  COLOR_PANELBG,
  COLOR_BUTTON,
  COLOR_BUTTONHOVER,
  COLOR_BUTTONFOCUS,
  COLOR_BASE,
  COLOR_BASEHOVER,
  COLOR_BASEFOCUS,
  COLOR_SCROLLBASE,
  COLOR_SCROLLTHUMB,
  COLOR_MAX
}

enum {
  ICON_CLOSE = 1,
  ICON_CHECK,
  ICON_COLLAPSED,
  ICON_EXPANDED,
  ICON_MAX
}

enum {
  RES_ACTIVE       = (1 << 0),
  RES_SUBMIT       = (1 << 1),
  RES_CHANGE       = (1 << 2)
}

enum {
  OPT_ALIGNCENTER  = (1 << 0),
  OPT_ALIGNRIGHT   = (1 << 1),
  OPT_NOINTERACT   = (1 << 2),
  OPT_NOFRAME      = (1 << 3),
  OPT_NORESIZE     = (1 << 4),
  OPT_NOSCROLL     = (1 << 5),
  OPT_NOCLOSE      = (1 << 6),
  OPT_NOTITLE      = (1 << 7),
  OPT_HOLDFOCUS    = (1 << 8),
  OPT_AUTOSIZE     = (1 << 9),
  OPT_POPUP        = (1 << 10),
  OPT_CLOSED       = (1 << 11),
  OPT_EXPANDED     = (1 << 12)
}

enum {
  MOUSE_LEFT       = (1 << 0),
  MOUSE_RIGHT      = (1 << 1),
  MOUSE_MIDDLE     = (1 << 2)
}

enum {
  KEY_SHIFT        = (1 << 0),
  KEY_CTRL         = (1 << 1),
  KEY_ALT          = (1 << 2),
  KEY_BACKSPACE    = (1 << 3),
  KEY_RETURN       = (1 << 4),
  KEY_LEFT         = (1 << 5),
  KEY_RIGHT        = (1 << 6),
}


alias Id = uint;
alias Real = REAL;
alias Font = void*;

struct Vec2
{
  alias data this;
  union
  {
    struct
    {
      int x;
      int y;
    }

    int[2] data;
  }
}

struct Rect
{
  alias data this;
  union
  {
    struct
    {
      int x;
      int y;
      int w;
      int h;
    }

    struct
    {
      int[2] pos;
      int[2] size;
    } 

    int[4] data;
  }
}
struct Color { ubyte r, g, b, a; }
struct PoolItem { Id id; int last_update; }

struct BaseCommand { int type, size; }
struct JumpCommand { BaseCommand base; void *dst; }
struct ClipCommand { BaseCommand base; Rect rect; }
struct RectCommand { BaseCommand base; Rect rect; Color color; }
struct TextCommand { BaseCommand base; Font font; Vec2 pos; Color color; char[1] str; }
struct IconCommand { BaseCommand base; Rect rect; int id; Color color; }

union Command {
  int type;
  BaseCommand base;
  JumpCommand jump;
  ClipCommand clip;
  RectCommand rect;
  TextCommand text;
  IconCommand icon;
}

struct Layout {
  Rect body;
  Rect next;
  Vec2 position;
  Vec2 size;
  Vec2 max;
  int [MAX_WIDTHS] widths;
  int items;
  int item_index;
  int next_row;
  int next_type;
  int indent;
} 

struct Container {
  Command *head;
  Command *tail;
  Rect rect;
  Rect body;
  Vec2 content_size;
  Vec2 scroll;
  int zindex;
  int open;
}

struct Style {
  Font font;
  Vec2 size;
  int padding;
  int spacing;
  int indent;
  int title_height;
  int scrollbar_size;
  int thumb_size;
  Color [COLOR_MAX] colors;
}
struct Context {
  /* callbacks */
  int function (Font font, const char *str, int len) text_width;
  int function (Font font) text_height;
  void function (Context *ctx, Rect rect, int colorid) draw_frame;
  /* core state */
  Style _style;
  Style *style;
  Id hover;
  Id focus;
  Id last_id;
  Rect last_rect;
  int last_zindex;
  int updated_focus;
  int frame;
  Container *hover_root;
  Container *next_hover_root;
  Container *scroll_target;
  char[MAX_FMT] number_edit_buf;
  Id number_edit;
  /* stacks */
  Stack!(char, COMMANDLIST_SIZE) command_list;
  Stack!(Container*, ROOTLIST_SIZE) root_list;
  Stack!(Container*, CONTAINERSTACK_SIZE) container_stack;
  Stack!(Rect, CLIPSTACK_SIZE) clip_stack;
  Stack!(Id, IDSTACK_SIZE) id_stack;
  Stack!(Layout, LAYOUTSTACK_SIZE) layout_stack;
  /* retained state pools */
  PoolItem[CONTAINERPOOL_SIZE] container_pool;
  Container[CONTAINERPOOL_SIZE] containers;
  PoolItem[TREENODEPOOL_SIZE] treenode_pool;
  /* input state */
  Vec2 mouse_pos;
  Vec2 last_mouse_pos;
  Vec2 mouse_delta;
  Vec2 scroll_delta;
  int mouse_down;
  int mouse_pressed;
  int key_down;
  int key_pressed;
  char[32] input_text;
}

struct Stack(T, int N)
{
  int idx;
  T[N] items;
}

void push(T, int N)(Stack!(T, N)* stk, T value)
{
    expect(stk.idx < (stk.items).sizeof / (*stk.items.ptr).sizeof);
    stk.items[stk.idx++] = value;
}

void pop(T, int N)(Stack!(T, N)* stk)
{
    expect(stk.idx > 0);
    stk.idx--;
}

void expect(bool x, string file = __FILE__, int line = __LINE__)
{
  if(!x) 
  {
    //printf("error man: %s:%d\n", file.ptr, line);
    panic("error man {} {}", file, line);
  }
}





__gshared Rect unclipped_rect = Rect(0, 0, 0x1000000, 0x1000000 );

__gshared Style default_style = Style(
  /* font | size | padding | spacing | indent */
  null, vec2( 68, 10 ), 5, 4, 24,
  /* title_height | scrollbar_size | thumb_size */
  24, 12, 8,
  [
    Color( 230, 230, 230, 255 ), /* COLOR_TEXT */
    Color( 25,  25,  25,  255 ), /* COLOR_BORDER */
    Color( 50,  50,  50,  255 ), /* COLOR_WINDOWBG */
    Color( 25,  25,  25,  255 ), /* COLOR_TITLEBG */
    Color( 240, 240, 240, 255 ), /* COLOR_TITLETEXT */
    Color( 0,   0,   0,   0   ), /* COLOR_PANELBG */
    Color( 75,  75,  75,  255 ), /* COLOR_BUTTON */
    Color( 95,  95,  95,  255 ), /* COLOR_BUTTONHOVER */
    Color( 115, 115, 115, 255 ), /* COLOR_BUTTONFOCUS */
    Color( 30,  30,  30,  255 ), /* COLOR_BASE */
    Color( 35,  35,  35,  255 ), /* COLOR_BASEHOVER */
    Color( 40,  40,  40,  255 ), /* COLOR_BASEFOCUS */
    Color( 43,  43,  43,  255 ), /* COLOR_SCROLLBASE */
    Color( 30,  30,  30,  255 )  /* COLOR_SCROLLTHUMB */
  ]
);


Vec2 vec2(int x, int y) {
  Vec2 res;
  res.x = x; res.y = y;
  return res;
}


Rect rect(int x, int y, int w, int h) {
  Rect res;
  res.x = x; res.y = y; res.w = w; res.h = h;
  return res;
}


Color color(int r, int g, int b, int a) {
  Color res;
  res.r = cast(ubyte)r; res.g =cast(ubyte) g; res.b =cast(ubyte) b; res.a =cast(ubyte) a;
  return res;
}


static Rect expand_rect(Rect rect, int n) {
  return Rect(rect.x - n, rect.y - n, rect.w + n * 2, rect.h + n * 2);
}


static Rect intersect_rects(Rect r1, Rect r2) {
  int x1 = max(r1.x, r2.x);
  int y1 = max(r1.y, r2.y);
  int x2 = min(r1.x + r1.w, r2.x + r2.w);
  int y2 = min(r1.y + r1.h, r2.y + r2.h);
  if (x2 < x1) { x2 = x1; }
  if (y2 < y1) { y2 = y1; }
  return rect(x1, y1, x2 - x1, y2 - y1);
}


static int rect_overlaps_vec2(Rect r, Vec2 p) {
  return p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h;
}


static void draw_frame(Context *ctx, Rect rect, int colorid) {
  draw_rect(ctx, rect, ctx.style.colors[colorid]);
  if (colorid == COLOR_SCROLLBASE  ||
      colorid == COLOR_SCROLLTHUMB ||
      colorid == COLOR_TITLEBG) { return; }
  /* draw border */
  if (ctx.style.colors[COLOR_BORDER].a) {
    draw_box(ctx, expand_rect(rect, 1), ctx.style.colors[COLOR_BORDER]);
  }
}

int button(Context* ctx, const char * label) { return button_ex(ctx, label, 0, OPT_ALIGNCENTER); }
int textbox(Context* ctx, char * buf, int bufsz)        { return textbox_ex(ctx, buf, bufsz, 0); }
int slider(Context* ctx, Real* value, Real lo, Real hi)      { return slider_ex(ctx, value, lo, hi, 0, SLIDER_FMT, OPT_ALIGNCENTER); }
int number(Context* ctx, Real* value, Real step)        { return number_ex(ctx, value, step, SLIDER_FMT, OPT_ALIGNCENTER); }
int header(Context* ctx, const char* label)              { return header_ex(ctx, label, 0); }
int begin_treenode(Context* ctx,const char* label)      { return begin_treenode_ex(ctx, label, 0); }
int begin_window(Context* ctx, const char* title, Rect rect)  { return begin_window_ex(ctx, title, rect, 0); }
void begin_panel(Context* ctx, const char* name)          { begin_panel_ex(ctx, name, 0); }




void init(Context *ctx) {
  memset(ctx, 0, (*ctx).sizeof);
  ctx.draw_frame = &draw_frame;
  ctx._style = default_style;
  ctx.style = &ctx._style;
}


void begin(Context *ctx) {
  expect(ctx.text_width && ctx.text_height);
  ctx.command_list.idx = 0;
  ctx.root_list.idx = 0;
  ctx.scroll_target = null;
  ctx.hover_root = ctx.next_hover_root;
  ctx.next_hover_root = null;
  ctx.mouse_delta.x = ctx.mouse_pos.x - ctx.last_mouse_pos.x;
  ctx.mouse_delta.y = ctx.mouse_pos.y - ctx.last_mouse_pos.y;
  ctx.frame++;
}


extern(C) int compare_zindex(const void *a, const void *b) {
  return (*cast(Container**) a).zindex - (*cast(Container**) b).zindex;
}


void end(Context *ctx) {
  int i, n;
  /* check stacks */
  expect(ctx.container_stack.idx == 0);
  expect(ctx.clip_stack.idx      == 0);
  expect(ctx.id_stack.idx        == 0);
  expect(ctx.layout_stack.idx    == 0);

  /* handle scroll input */
  if (ctx.scroll_target) {
    ctx.scroll_target.scroll.x += ctx.scroll_delta.x;
    ctx.scroll_target.scroll.y += ctx.scroll_delta.y;
  }

  /* unset focus if focus id was not touched this frame */
  if (!ctx.updated_focus) { ctx.focus = 0; }
  ctx.updated_focus = 0;

  /* bring hover root to front if mouse was pressed */
  if (ctx.mouse_pressed && ctx.next_hover_root &&
      ctx.next_hover_root.zindex < ctx.last_zindex &&
      ctx.next_hover_root.zindex >= 0
  ) {
    bring_to_front(ctx, ctx.next_hover_root);
  }

  /* reset input state */
  ctx.key_pressed = 0;
  ctx.input_text[0] = '\0';
  ctx.mouse_pressed = 0;
  ctx.scroll_delta = vec2(0, 0);
  ctx.last_mouse_pos = ctx.mouse_pos;

  /* sort root containers by zindex */
  n = ctx.root_list.idx;
  qsort(ctx.root_list.items.ptr, cast(ulong)n, (Container*).sizeof, &compare_zindex);

  /* set root container jump commands */
  for (i = 0; i < n; i++) {
    Container *cnt = ctx.root_list.items[i];
    /* if this is the first container then make the first command jump to it.
    ** otherwise set the previous container's tail to jump to this one */
    if (i == 0) {
      Command *cmd = cast(Command*) ctx.command_list.items;
      cmd.jump.dst = cast(char*) cnt.head + (JumpCommand).sizeof;
    } else {
      Container *prev = ctx.root_list.items[i - 1];
      prev.tail.jump.dst = cast(char*) cnt.head + (JumpCommand).sizeof;
    }
    /* make the last container's tail jump to the end of command list */
    if (i == n - 1) {
      cnt.tail.jump.dst = ctx.command_list.items.ptr + ctx.command_list.idx;
    }
  }
}


void set_focus(Context *ctx, Id id) {
  ctx.focus = id;
  ctx.updated_focus = 1;
}


/* 32bit fnv-1a hash */
enum HASH_INITIAL = 2166136261;

static void hash(Id *hash, const void *data, int size) {
  ubyte *p = cast(ubyte*)data;
  while (size--) {
    *hash = (*hash ^ *p++) * 16777619;
  }
}


Id get_id(Context *ctx, const void *data, int size) {
  int idx = ctx.id_stack.idx;
  Id res = (idx > 0) ? ctx.id_stack.items[idx - 1] : HASH_INITIAL;
  hash(&res, data, size);
  ctx.last_id = res;
  return res;
}


void push_id(Context *ctx, const void *data, int size) {
  push(&ctx.id_stack, get_id(ctx, data, size));
}


void pop_id(Context *ctx) {
  pop(&ctx.id_stack);
}


void push_clip_rect(Context *ctx, Rect rect) {
  Rect last = get_clip_rect(ctx);
  push(&ctx.clip_stack, intersect_rects(rect, last));
}


void pop_clip_rect(Context *ctx) {
  pop(&ctx.clip_stack);
}


Rect get_clip_rect(Context *ctx) {
  expect(ctx.clip_stack.idx > 0);
  return ctx.clip_stack.items[ctx.clip_stack.idx - 1];
}


int check_clip(Context *ctx, Rect r) {
  Rect cr = get_clip_rect(ctx);
  if (r.x > cr.x + cr.w || r.x + r.w < cr.x ||
      r.y > cr.y + cr.h || r.y + r.h < cr.y   ) { return CLIP_ALL; }
  if (r.x >= cr.x && r.x + r.w <= cr.x + cr.w &&
      r.y >= cr.y && r.y + r.h <= cr.y + cr.h ) { return 0; }
  return CLIP_PART;
}


static void push_layout(Context *ctx, Rect body, Vec2 scroll) {
  Layout layout;
  int width = 0;
  memset(&layout, 0, (layout).sizeof);
  layout.body = rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h);
  layout.max = vec2(-0x1000000, -0x1000000);
  push(&ctx.layout_stack, layout);
  layout_row(ctx, 1, &width, 0);
}


static Layout* get_layout(Context *ctx) {
  return &ctx.layout_stack.items[ctx.layout_stack.idx - 1];
}


static void pop_container(Context *ctx) {
  Container *cnt = get_current_container(ctx);
  Layout *layout = get_layout(ctx);
  cnt.content_size.x = layout.max.x - layout.body.x;
  cnt.content_size.y = layout.max.y - layout.body.y;
  /* pop container, layout and id */
  pop(&ctx.container_stack);
  pop(&ctx.layout_stack);
  pop_id(ctx);
}


Container* get_current_container(Context *ctx) {
  expect(ctx.container_stack.idx > 0);
  return ctx.container_stack.items[ ctx.container_stack.idx - 1 ];
}


static Container* get_container(Context *ctx, Id id, int opt) {
  Container *cnt;
  /* try to get existing container from pool */
  int idx = pool_get(ctx, ctx.container_pool.ptr, CONTAINERPOOL_SIZE, id);
  if (idx >= 0) {
    if (ctx.containers[idx].open || ~opt & OPT_CLOSED) {
      pool_update(ctx, ctx.container_pool.ptr, idx);
    }
    return &ctx.containers[idx];
  }
  if (opt & OPT_CLOSED) { return null; }
  /* container not found in pool: init new container */
  idx = pool_init(ctx, ctx.container_pool.ptr, CONTAINERPOOL_SIZE, id);
  cnt = &ctx.containers[idx];
  memset(cnt, 0, (*cnt).sizeof);
  cnt.open = 1;
  bring_to_front(ctx, cnt);
  return cnt;
}


Container* get_container(Context *ctx, const char *name) {
  Id id = get_id(ctx, name,cast(int) str_len(name));
  return get_container(ctx, id, 0);
}


void bring_to_front(Context *ctx, Container *cnt) {
  cnt.zindex = ++ctx.last_zindex;
}


/*============================================================================
** pool
**============================================================================*/

int pool_init(Context *ctx, PoolItem *items, int len, Id id) {
  int i, n = -1, f = ctx.frame;
  for (i = 0; i < len; i++) {
    if (items[i].last_update < f) {
      f = items[i].last_update;
      n = i;
    }
  }
  expect(n > -1);
  items[n].id = id;
  pool_update(ctx, items, n);
  return n;
}


int pool_get(Context *ctx, PoolItem *items, int len, Id id) {
  int i;
  //unused(ctx);
  for (i = 0; i < len; i++) {
    if (items[i].id == id) { return i; }
  }
  return -1;
}


void pool_update(Context *ctx, PoolItem *items, int idx) {
  items[idx].last_update = ctx.frame;
}


/*============================================================================
** input handlers
**============================================================================*/

void input_mousemove(Context *ctx, int x, int y) {
  ctx.mouse_pos = vec2(x, y);
}


void input_mousedown(Context *ctx, int x, int y, int btn) {
  input_mousemove(ctx, x, y);
  ctx.mouse_down |= btn;
  ctx.mouse_pressed |= btn;
}


void input_mouseup(Context *ctx, int x, int y, int btn) {
  input_mousemove(ctx, x, y);
  ctx.mouse_down &= ~btn;
}


void input_scroll(Context *ctx, int x, int y) {
  ctx.scroll_delta.x += x;
  ctx.scroll_delta.y += y;
}


void input_keydown(Context *ctx, int key) {
  ctx.key_pressed |= key;
  ctx.key_down |= key;
}


void input_keyup(Context *ctx, int key) {
  ctx.key_down &= ~key;
}


void input_text(Context *ctx, const char *text) {
  int len = cast(int) str_len(ctx.input_text.ptr);
  int size = cast(int) str_len(text) + 1;
  expect(len + size <= cast(int) (ctx.input_text).sizeof);
  memcpy(ctx.input_text.ptr + len, text, size);
}


/*============================================================================
** commandlist
**============================================================================*/

Command* push_command(Context *ctx, int type, int size) {
  Command *cmd = cast(Command*) (ctx.command_list.items.ptr + ctx.command_list.idx);
  expect(ctx.command_list.idx + size < COMMANDLIST_SIZE);
  cmd.base.type = type;
  cmd.base.size = size;
  ctx.command_list.idx += size;
  return cmd;
}


int next_command(Context *ctx, Command **cmd) {
  if (*cmd) {
    *cmd = cast(Command*) ((cast(char*) *cmd) + (*cmd).base.size);
  } else {
    *cmd = cast(Command*) ctx.command_list.items;
  }
  while (cast(char*) *cmd != ctx.command_list.items.ptr + ctx.command_list.idx) {
    if ((*cmd).type != COMMAND_JUMP) { return 1; }
    *cmd = cast(Command*) (*cmd).jump.dst;
  }
  return 0;
}


static Command* push_jump(Context *ctx, Command *dst) {
  Command *cmd;
  cmd = push_command(ctx, COMMAND_JUMP, (JumpCommand).sizeof);
  cmd.jump.dst = dst;
  return cmd;
}


void set_clip(Context *ctx, Rect rect) {
  Command *cmd;
  cmd = push_command(ctx, COMMAND_CLIP, (ClipCommand).sizeof);
  cmd.clip.rect = rect;
}


void draw_rect(Context *ctx, Rect rect, Color color) {
  Command *cmd;
  rect = intersect_rects(rect, get_clip_rect(ctx));
  if (rect.w > 0 && rect.h > 0) {
    cmd = push_command(ctx, COMMAND_RECT, (RectCommand).sizeof);
    cmd.rect.rect = rect;
    cmd.rect.color = color;
  }
}


void draw_box(Context *ctx, Rect rect, Color color) {
  draw_rect(ctx, Rect(rect.x + 1, rect.y, rect.w - 2, 1), color);
  draw_rect(ctx, Rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color);
  draw_rect(ctx, Rect(rect.x, rect.y, 1, rect.h), color);
  draw_rect(ctx, Rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color);
}


void draw_text(Context *ctx, Font font, const char *str, int len,
  Vec2 pos, Color color)
{
  Command *cmd;
  Rect rect = rect(pos.x, pos.y, ctx.text_width(font, str, len), ctx.text_height(font));
  int clipped = check_clip(ctx, rect);
  if (clipped == CLIP_ALL ) { return; }
  if (clipped == CLIP_PART) { set_clip(ctx, get_clip_rect(ctx)); }
  /* add command */
  if (len < 0) { len = cast(int) str_len(str); }
  cmd = push_command(ctx, COMMAND_TEXT, cast(int) (TextCommand).sizeof + len);
  memcpy(cmd.text.str.ptr, str, len);
  cmd.text.str.ptr[len] = '\0';
  cmd.text.pos = pos;
  cmd.text.color = color;
  cmd.text.font = font;
  /* reset clipping if it was set */
  if (clipped) { set_clip(ctx, unclipped_rect); }
}


void draw_icon(Context *ctx, int id, Rect rect, Color color) {
  Command *cmd;
  /* do clip command if the rect isn't fully contained within the cliprect */
  int clipped = check_clip(ctx, rect);
  if (clipped == CLIP_ALL ) { return; }
  if (clipped == CLIP_PART) { set_clip(ctx, get_clip_rect(ctx)); }
  /* do icon command */
  cmd = push_command(ctx, COMMAND_ICON, (IconCommand).sizeof);
  cmd.icon.id = id;
  cmd.icon.rect = rect;
  cmd.icon.color = color;
  /* reset clipping if it was set */
  if (clipped) { set_clip(ctx, unclipped_rect); }
}


/*============================================================================
** layout
**============================================================================*/

enum { RELATIVE = 1, ABSOLUTE = 2 };


void layout_begin_column(Context *ctx) {
  push_layout(ctx, layout_next(ctx), vec2(0, 0));
}


void layout_end_column(Context *ctx) {
  Layout *a;
  Layout *b;
  b = get_layout(ctx);
  pop(&ctx.layout_stack);
  /* inherit position/next_row/max from child layout if they are greater */
  a = get_layout(ctx);
  a.position.x = max(a.position.x, b.position.x + b.body.x - a.body.x);
  a.next_row = max(a.next_row, b.next_row + b.body.y - a.body.y);
  a.max.x = max(a.max.x, b.max.x);
  a.max.y = max(a.max.y, b.max.y);
}


void layout_row(Context *ctx, scope const int[] widths, int height)
{
  layout_row(ctx, cast(int)widths.length, widths.ptr, height);
}


void layout_row(Context *ctx, int items, const int *widths, int height) {
  Layout *layout = get_layout(ctx);
  if (widths) {
    expect(items <= MAX_WIDTHS);
    memcpy(layout.widths.ptr, widths, items * (widths[0]).sizeof);
  }
  layout.items = items;
  layout.position = vec2(layout.indent, layout.next_row);
  layout.size.y = height;
  layout.item_index = 0;
}


void layout_width(Context *ctx, int width) {
  get_layout(ctx).size.x = width;
}


void layout_height(Context *ctx, int height) {
  get_layout(ctx).size.y = height;
}


void layout_set_next(Context *ctx, Rect r, int relative) {
  Layout *layout = get_layout(ctx);
  layout.next = r;
  layout.next_type = relative ? RELATIVE : ABSOLUTE;
}


Rect layout_next(Context *ctx) {
  Layout *layout = get_layout(ctx);
  Style *style = ctx.style;
  Rect res;

  if (layout.next_type) {
    /* handle rect set by `layout_set_next` */
    int type = layout.next_type;
    layout.next_type = 0;
    res = layout.next;
    if (type == ABSOLUTE) { return (ctx.last_rect = res); }

  } else {
    /* handle next row */
    if (layout.item_index == layout.items) {
      layout_row(ctx, layout.items, null, layout.size.y);
    }

    /* position */
    res.x = layout.position.x;
    res.y = layout.position.y;

    /* size */
    res.w = layout.items > 0 ? layout.widths[layout.item_index] : layout.size.x;
    res.h = layout.size.y;
    if (res.w == 0) { res.w = style.size.x + style.padding * 2; }
    if (res.h == 0) { res.h = style.size.y + style.padding * 2; }
    if (res.w <  0) { res.w += layout.body.w - res.x + 1; }
    if (res.h <  0) { res.h += layout.body.h - res.y + 1; }

    layout.item_index++;
  }

  /* update position */
  layout.position.x += res.w + style.spacing;
  layout.next_row = max(layout.next_row, res.y + res.h + style.spacing);

  /* apply body offset */
  res.x += layout.body.x;
  res.y += layout.body.y;

  /* update max position */
  layout.max.x = max(layout.max.x, res.x + res.w);
  layout.max.y = max(layout.max.y, res.y + res.h);

  return (ctx.last_rect = res);
}


/*============================================================================
** controls
**============================================================================*/

static int in_hover_root(Context *ctx) {
  int i = ctx.container_stack.idx;
  while (i--) {
    if (ctx.container_stack.items[i] == ctx.hover_root) { return 1; }
    /* only root containers have their `head` field set; stop searching if we've
    ** reached the current root container */
    if (ctx.container_stack.items[i].head) { break; }
  }
  return 0;
}


void draw_control_frame(Context *ctx, Id id, Rect rect,
  int colorid, int opt)
{
  if (opt & OPT_NOFRAME) { return; }
  colorid += (ctx.focus == id) ? 2 : (ctx.hover == id) ? 1 : 0;
  ctx.draw_frame(ctx, rect, colorid);
}


void draw_control_text(Context *ctx, const char *str, Rect rect,
  int colorid, int opt)
{
  Vec2 pos;
  Font font = ctx.style.font;
  int tw = ctx.text_width(font, str, -1);
  push_clip_rect(ctx, rect);
  pos.y = rect.y + (rect.h - ctx.text_height(font)) / 2;
  if (opt & OPT_ALIGNCENTER) {
    pos.x = rect.x + (rect.w - tw) / 2;
  } else if (opt & OPT_ALIGNRIGHT) {
    pos.x = rect.x + rect.w - tw - ctx.style.padding;
  } else {
    pos.x = rect.x + ctx.style.padding;
  }
  draw_text(ctx, font, str, -1, pos, ctx.style.colors[colorid]);
  pop_clip_rect(ctx);
}


int mouse_over(Context *ctx, Rect rect) {
  return rect_overlaps_vec2(rect, ctx.mouse_pos) &&
    rect_overlaps_vec2(get_clip_rect(ctx), ctx.mouse_pos) &&
    in_hover_root(ctx);
}


void update_control(Context *ctx, Id id, Rect rect, int opt) {
  int mouseover = mouse_over(ctx, rect);

  if (ctx.focus == id) { ctx.updated_focus = 1; }
  if (opt & OPT_NOINTERACT) { return; }
  if (mouseover && !ctx.mouse_down) { ctx.hover = id; }

  if (ctx.focus == id) {
    if (ctx.mouse_pressed && !mouseover) { set_focus(ctx, 0); }
    if (!ctx.mouse_down && ~opt & OPT_HOLDFOCUS) { set_focus(ctx, 0); }
  }

  if (ctx.hover == id) {
    if (ctx.mouse_pressed) {
      set_focus(ctx, id);
    } else if (!mouseover) {
      ctx.hover = 0;
    }
  }
}


void text(Context *ctx, const char *text) {
  char *start = cast(char*) text;
  char *end = cast(char*) text;
  char *p = cast(char*) text;
  int width = -1;
  Font font = ctx.style.font;
  Color color = ctx.style.colors[COLOR_TEXT];
  layout_begin_column(ctx);
  layout_row(ctx, 1, &width, ctx.text_height(font));
  do {
    Rect r = layout_next(ctx);
    int w = 0;
    start = end = p;
    do {
      const char* word = p;
      while (*p && *p != ' ' && *p != '\n') { p++; }
      w += ctx.text_width(font, word, cast(int) (p - word));
      if (w > r.w && end != start) { break; }
      w += ctx.text_width(font, p, 1);
      end = p++;
    } while (*end && *end != '\n');
    draw_text(ctx, font, start, cast(int) (end - start), vec2(r.x, r.y), color);
    p = end + 1;
  } while (*end);
  layout_end_column(ctx);
}


void label(Context *ctx, const char *text) {
  draw_control_text(ctx, text, layout_next(ctx), COLOR_TEXT, 0);
}


int button_ex(Context *ctx, const char *label, int icon, int opt) {
  int res = 0;
  Id id = label ? get_id(ctx, label, cast(int)str_len(label))
                   : get_id(ctx, &icon, (icon).sizeof);
  Rect r = layout_next(ctx);
  update_control(ctx, id, r, opt);
  /* handle click */
  if (ctx.mouse_pressed == MOUSE_LEFT && ctx.focus == id) {
    res |= RES_SUBMIT;
  }
  /* draw */
  draw_control_frame(ctx, id, r, COLOR_BUTTON, opt);
  if (label) { draw_control_text(ctx, label, r, COLOR_TEXT, opt); }
  if (icon) { draw_icon(ctx, icon, r, ctx.style.colors[COLOR_TEXT]); }
  return res;
}


int checkbox(Context *ctx, const char *label, int *state) {
  int res = 0;
  Id id = get_id(ctx, &state, (state).sizeof);
  Rect r = layout_next(ctx);
  Rect box = rect(r.x, r.y, r.h, r.h);
  update_control(ctx, id, r, 0);
  /* handle click */
  if (ctx.mouse_pressed == MOUSE_LEFT && ctx.focus == id) {
    res |= RES_CHANGE;
    *state = !*state;
  }
  /* draw */
  draw_control_frame(ctx, id, box, COLOR_BASE, 0);
  if (*state) {
    draw_icon(ctx, ICON_CHECK, box, ctx.style.colors[COLOR_TEXT]);
  }
  r = rect(r.x + box.w, r.y, r.w - box.w, r.h);
  draw_control_text(ctx, label, r, COLOR_TEXT, 0);
  return res;
}


int textbox_raw(Context *ctx, char *buf, int bufsz, Id id, Rect r, int opt)
{
  int res = 0;
  update_control(ctx, id, r, opt | OPT_HOLDFOCUS);

  if (ctx.focus == id) {
    /* handle text input */
    int len = cast(int)str_len(buf);
    int n = min(bufsz - len - 1, cast(int) str_len(ctx.input_text.ptr));
    if (n > 0) {
      memcpy(buf + len, ctx.input_text.ptr, n);
      len += n;
      buf[len] = '\0';
      res |= RES_CHANGE;
    }
    /* handle backspace */
    if (ctx.key_pressed & KEY_BACKSPACE && len > 0) {
      /* skip utf-8 continuation bytes */
      while ((buf[--len] & 0xc0) == 0x80 && len > 0){}
      buf[len] = '\0';
      res |= RES_CHANGE;
    }
    /* handle return */
    if (ctx.key_pressed & KEY_RETURN) {
      set_focus(ctx, 0);
      res |= RES_SUBMIT;
    }

    if (ctx.key_pressed & KEY_LEFT) {
    }
  }

  /* draw */
  draw_control_frame(ctx, id, r, COLOR_BASE, opt);
  if (ctx.focus == id) {
    Color color = ctx.style.colors[COLOR_TEXT];
    Font font = ctx.style.font;
    int textw = ctx.text_width(font, buf, -1);
    int texth = ctx.text_height(font);
    int ofx = r.w - ctx.style.padding - textw - 1;
    int textx = r.x + min(ofx, ctx.style.padding);
    int texty = r.y + (r.h - texth) / 2;
    push_clip_rect(ctx, r);
    draw_text(ctx, font, buf, -1, vec2(textx, texty), color);
    draw_rect(ctx, rect(textx + textw, texty, 1, texth), color);
    pop_clip_rect(ctx);
  } else {
    draw_control_text(ctx, buf, r, COLOR_TEXT, opt);
  }

  return res;
}


static int number_textbox(Context *ctx, Real *value, Rect r, Id id) {
  if (ctx.mouse_pressed == MOUSE_LEFT && ctx.key_down & KEY_SHIFT &&
      ctx.hover == id
  ) {
    ctx.number_edit = id;

    sprintf(ctx.number_edit_buf.ptr, REAL_FMT, *value);

  }
  if (ctx.number_edit == id) {
    int res = textbox_raw(
      ctx, ctx.number_edit_buf.ptr, (ctx.number_edit_buf).sizeof, id, r, 0);
    if (res & RES_SUBMIT || ctx.focus != id) {
      *value = strtod(ctx.number_edit_buf.ptr, null);
      ctx.number_edit = 0;
    } else {
      return 1;
    }
  }
  return 0;
}


int textbox_ex(Context *ctx, char *buf, int bufsz, int opt) {
  Id id = get_id(ctx, &buf, (buf).sizeof);
  Rect r = layout_next(ctx);
  return textbox_raw(ctx, buf, bufsz, id, r, opt);
}

int textbox_ex(Context* ctx, char* buf, int bufsz, const char* placeholder, int opt = 0)
{
  Id id = get_id(ctx, &buf, (buf).sizeof);
  Rect r = layout_next(ctx);

  if (str_len(buf) == 0 && ctx.focus != id)
  {
    return textbox_raw(ctx, cast(char*) placeholder, cast(int) str_len(placeholder), id, r, opt);
  }

  return textbox_raw(ctx, buf, bufsz, id, r, opt);
}


int slider_ex(Context *ctx, Real *value, Real low, Real high,
  Real step, const char *fmt, int opt)
{
  char [MAX_FMT + 1] buf;
  Rect thumb;
  int x, w, res = 0;
  Real last = *value, v = last;
  Id id = get_id(ctx, &value, (value).sizeof);
  Rect base = layout_next(ctx);

  /* handle text input mode */
  if (number_textbox(ctx, &v, base, id)) { return res; }

  /* handle normal mode */
  update_control(ctx, id, base, opt);

  /* handle input */
  if (ctx.focus == id &&
      (ctx.mouse_down | ctx.mouse_pressed) == MOUSE_LEFT)
  {
    v = low + (ctx.mouse_pos.x - base.x) * (high - low) / base.w;
    if (step) { v = (((v + step / 2) / step)) * step; }
  }
  /* clamp and store value, update res */
  *value = v = clamp(v, low, high);
  if (last != v) { res |= RES_CHANGE; }

  /* draw base */
  draw_control_frame(ctx, id, base, COLOR_BASE, opt);
  /* draw thumb */
  w = ctx.style.thumb_size;
  x = cast(int) ( (v - low) * (base.w - w) / (high - low) );
  thumb = rect(base.x + x, base.y, w, base.h);
  draw_control_frame(ctx, id, thumb, COLOR_BUTTON, opt);
  /* draw text  */
  sprintf(buf.ptr, fmt, v);
  draw_control_text(ctx, buf.ptr, base, COLOR_TEXT, opt);

  return res;
}


int number_ex(Context *ctx, Real *value, Real step,
  const char *fmt, int opt)
{
  char [MAX_FMT + 1] buf;
  int res = 0;
  Id id = get_id(ctx, &value, (value).sizeof);
  Rect base = layout_next(ctx);
  Real last = *value;

  /* handle text input mode */
  if (number_textbox(ctx, value, base, id)) { return res; }

  /* handle normal mode */
  update_control(ctx, id, base, opt);

  /* handle input */
  if (ctx.focus == id && ctx.mouse_down == MOUSE_LEFT) {
    *value += ctx.mouse_delta.x * step;
  }
  /* set flag if value changed */
  if (*value != last) { res |= RES_CHANGE; }

  /* draw base */
  draw_control_frame(ctx, id, base, COLOR_BASE, opt);
  /* draw text  */
  sprintf(buf.ptr, fmt, *value);
  draw_control_text(ctx, buf.ptr, base, COLOR_TEXT, opt);

  return res;
}


static int header(Context *ctx, const char *label, int istreenode, int opt) {
  Rect r;
  int active, expanded;
  Id id = get_id(ctx, label, cast(int)str_len(label));
  int idx = pool_get(ctx, ctx.treenode_pool.ptr, TREENODEPOOL_SIZE, id);
  int width = -1;
  layout_row(ctx, 1, &width, 0);

  active = (idx >= 0);
  expanded = (opt & OPT_EXPANDED) ? !active : active;
  r = layout_next(ctx);
  update_control(ctx, id, r, 0);

  /* handle click */
  active ^= (ctx.mouse_pressed == MOUSE_LEFT && ctx.focus == id);

  /* update pool ref */
  if (idx >= 0) {
    if (active) { pool_update(ctx, ctx.treenode_pool.ptr, idx); }
           else { memset(&ctx.treenode_pool[idx], 0, (PoolItem).sizeof); }
  } else if (active) {
    pool_init(ctx, ctx.treenode_pool.ptr, TREENODEPOOL_SIZE, id);
  }

  /* draw */
  if (istreenode) {
    if (ctx.hover == id) { ctx.draw_frame(ctx, r, COLOR_BUTTONHOVER); }
  } else {
    draw_control_frame(ctx, id, r, COLOR_BUTTON, 0);
  }
  draw_icon(
    ctx, expanded ? ICON_EXPANDED : ICON_COLLAPSED,
    rect(r.x, r.y, r.h, r.h), ctx.style.colors[COLOR_TEXT]);
  r.x += r.h - ctx.style.padding;
  r.w -= r.h - ctx.style.padding;
  draw_control_text(ctx, label, r, COLOR_TEXT, 0);

  return expanded ? RES_ACTIVE : 0;
}


int header_ex(Context *ctx, const char *label, int opt) {
  return header(ctx, label, 0, opt);
}


int begin_treenode_ex(Context *ctx, const char *label, int opt) {
  int res = header(ctx, label, 1, opt);
  if (res & RES_ACTIVE) {
    get_layout(ctx).indent += ctx.style.indent;
    push(&ctx.id_stack, ctx.last_id);
  }
  return res;
}


void end_treenode(Context *ctx) {
  get_layout(ctx).indent -= ctx.style.indent;
  pop_id(ctx);
}

void scrollbar(Context* ctx, Container * cnt, Rect * b, Vec2  cs, string id_str, int i)
{
  int maxscroll = cs[i] - b.size[i];
  int contentsize = b.size[i];

  if(maxscroll > 0 && contentsize > 0)
  {
    auto id = get_id(ctx, id_str.ptr, 11);
    auto base = *b;
    base.pos[1 - i] = b.pos[1 - i] + b.size[1 - i];
    base.size[1 - i] = ctx.style.scrollbar_size;

    update_control(ctx, id, base, 0);
    if (ctx.focus == id && ctx.mouse_down == MOUSE_LEFT) {   
      cnt.scroll[i] += ctx.mouse_delta[i] * cs[i] / base.size[i];
    }

    cnt.scroll[i] = clamp(cnt.scroll[i], 0, maxscroll);

    ctx.draw_frame(ctx, base, COLOR_SCROLLBASE);
    auto thumb = base;
    thumb.size[i] = max(ctx.style.thumb_size, base.size[i] * b.size[i] / cs[i]);
    thumb.pos[i] += cnt.scroll[i] * (base.size[i] - thumb.size[i]) / maxscroll;
    ctx.draw_frame(ctx, thumb, COLOR_SCROLLTHUMB);

    if(mouse_over(ctx, *b)){
        ctx.scroll_target = cnt;
    }
  } else 
  {
      cnt.scroll[i] = 0;
  }
}



static void scrollbars(Context *ctx, Container *cnt, Rect *body) {
  int sz = ctx.style.scrollbar_size;
  Vec2 cs = cnt.content_size;
  cs.x += ctx.style.padding * 2;
  cs.y += ctx.style.padding * 2;
  push_clip_rect(ctx, *body);
  /* resize body to make room for scrollbars */
  if (cs.y > cnt.body.h) { body.w -= sz; }
  if (cs.x > cnt.body.w) { body.h -= sz; }
  /* to create a horizontal or vertical scrollbar almost-identical code is
  ** used; only the references to `x|y` `w|h` need to be switched */
  scrollbar(ctx, cnt, body, cs, "!scrollbarv", 1); // 1 = y,h
  scrollbar(ctx, cnt, body, cs, "!scrollbarh", 0); // 0 = x,w
  pop_clip_rect(ctx);
}


static void push_container_body(
  Context *ctx, Container *cnt, Rect body, int opt
) {
  if (~opt & OPT_NOSCROLL) { scrollbars(ctx, cnt, &body); }
  push_layout(ctx, expand_rect(body, -ctx.style.padding), cnt.scroll);
  cnt.body = body;
}


static void begin_root_container(Context *ctx, Container *cnt) {
  push(&ctx.container_stack, cnt);
  /* push container to roots list and push head command */
  push(&ctx.root_list, cnt);
  cnt.head = push_jump(ctx, null);
  /* set as hover root if the mouse is overlapping this container and it has a
  ** higher zindex than the current hover root */
  if (rect_overlaps_vec2(cnt.rect, ctx.mouse_pos) &&
      (!ctx.next_hover_root || cnt.zindex > ctx.next_hover_root.zindex)
  ) {
    ctx.next_hover_root = cnt;
  }
  /* clipping is reset here in case a root-container is made within
  ** another root-containers's begin/end block; this prevents the inner
  ** root-container being clipped to the outer */
  push(&ctx.clip_stack, unclipped_rect);
}


static void end_root_container(Context *ctx) {
  /* push tail 'goto' jump command and set head 'skip' command. the final steps
  ** on initing these are done in end() */
  Container *cnt = get_current_container(ctx);
  cnt.tail = push_jump(ctx, null);
  cnt.head.jump.dst = ctx.command_list.items.ptr + ctx.command_list.idx;
  /* pop base clip rect and container */
  pop_clip_rect(ctx);
  pop_container(ctx);
}


int begin_window_ex(Context *ctx, const char *title, Rect rect, int opt) {
  Rect body;
  Id id = get_id(ctx, title, cast(int) str_len(title));
  Container *cnt = get_container(ctx, id, opt);
  if (!cnt || !cnt.open) { return 0; }
  push(&ctx.id_stack, id);

  if (cnt.rect.w == 0) { cnt.rect = rect; }
  begin_root_container(ctx, cnt);
  rect = body = cnt.rect;

  /* draw frame */
  if (~opt & OPT_NOFRAME) {
    ctx.draw_frame(ctx, rect, COLOR_WINDOWBG);
  }

  /* do title bar */
  if (~opt & OPT_NOTITLE) {
    Rect tr = rect;
    tr.h = ctx.style.title_height;
    ctx.draw_frame(ctx, tr, COLOR_TITLEBG);

    /* do title text */
    if (~opt & OPT_NOTITLE) {
      id = get_id(ctx, cast(char*) "!title", 6);
      update_control(ctx, id, tr, opt);
      draw_control_text(ctx, title, tr, COLOR_TITLETEXT, opt);
      if (id == ctx.focus && ctx.mouse_down == MOUSE_LEFT) {
        cnt.rect.x += ctx.mouse_delta.x;
        cnt.rect.y += ctx.mouse_delta.y;
      }
      body.y += tr.h;
      body.h -= tr.h;
    }

    /* do `close` button */
    if (~opt & OPT_NOCLOSE) {
      id = get_id(ctx, cast(char*)"!close", 6);
      Rect r = Rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h);
      tr.w -= r.w;
      draw_icon(ctx, ICON_CLOSE, r, ctx.style.colors[COLOR_TITLETEXT]);
      update_control(ctx, id, r, opt);
      if (ctx.mouse_pressed == MOUSE_LEFT && id == ctx.focus) {
        cnt.open = 0;
      }
    }
  }

  push_container_body(ctx, cnt, body, opt);

  /* do `resize` handle */
  if (~opt & OPT_NORESIZE) {
    int sz = ctx.style.title_height;
    id = get_id(ctx, cast(char*) "!resize", 7);
    Rect r = Rect(rect.x + rect.w - sz, rect.y + rect.h - sz, sz, sz);
    update_control(ctx, id, r, opt);
    if (id == ctx.focus && ctx.mouse_down == MOUSE_LEFT) {
      cnt.rect.w = max(96, cnt.rect.w + ctx.mouse_delta.x);
      cnt.rect.h = max(64, cnt.rect.h + ctx.mouse_delta.y);
    }
  }

  /* resize to content size */
  if (opt & OPT_AUTOSIZE) {
    Rect r = get_layout(ctx).body;
    cnt.rect.w = cnt.content_size.x + (cnt.rect.w - r.w);
    cnt.rect.h = cnt.content_size.y + (cnt.rect.h - r.h);
  }

  /* close if this is a popup window and elsewhere was clicked */
  if (opt & OPT_POPUP && ctx.mouse_pressed && ctx.hover_root != cnt) {
    cnt.open = 0;
  }

  push_clip_rect(ctx, cnt.body);
  return RES_ACTIVE;
}


void end_window(Context *ctx) {
  pop_clip_rect(ctx);
  end_root_container(ctx);
}


void open_popup(Context *ctx, const char *name) {
  Container *cnt = get_container(ctx, name);
  /* set as hover root so popup isn't closed in begin_window_ex()  */
  ctx.hover_root = ctx.next_hover_root = cnt;
  /* position at mouse cursor, open and bring-to-front */
  cnt.rect = rect(ctx.mouse_pos.x, ctx.mouse_pos.y, 1, 1);
  cnt.open = 1;
  bring_to_front(ctx, cnt);
}


int begin_popup(Context *ctx, const char *name) {
  int opt = OPT_POPUP | OPT_AUTOSIZE | OPT_NORESIZE |
            OPT_NOSCROLL | OPT_NOTITLE | OPT_CLOSED;
  return begin_window_ex(ctx, name, rect(0, 0, 0, 0), opt);
}


void end_popup(Context *ctx) {
  end_window(ctx);
}


void begin_panel_ex(Context *ctx, const char *name, int opt) {
  Container *cnt;
  push_id(ctx, name, cast(int) str_len(name));
  cnt = get_container(ctx, ctx.last_id, opt);
  cnt.rect = layout_next(ctx);
  if (~opt & OPT_NOFRAME) {
    ctx.draw_frame(ctx, cnt.rect, COLOR_PANELBG);
  }
  push(&ctx.container_stack, cnt);
  push_container_body(ctx, cnt, cnt.rect, opt);
  push_clip_rect(ctx, cnt.body);
}


void end_panel(Context *ctx) {
  pop_clip_rect(ctx);
  pop_container(ctx);
}