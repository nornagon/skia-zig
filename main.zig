const std = @import("std");

const glfw = @cImport({
  @cInclude("GLFW/glfw3.h");
});

const gl = @cImport({
  @cInclude("OpenGL/gl.h");
});

const skia = @cImport({
  @cInclude("skia/include/c/gr_context.h");
  @cInclude("skia/include/c/sk_canvas.h");
  @cInclude("skia/include/c/sk_colorspace.h");
  @cInclude("skia/include/c/sk_data.h");
  @cInclude("skia/include/c/sk_image.h");
  @cInclude("skia/include/c/sk_paint.h");
  @cInclude("skia/include/c/sk_path.h");
  @cInclude("skia/include/c/sk_surface.h");
});

extern fn errorCallback(code: c_int, err: ?[*]const u8) void {
  std.debug.warn("GLFW error 0x{x}: {s}\n", code, err);
}

fn ptr(p: var) t: {
    const info = @typeInfo(@typeOf(p)).Pointer;
    break :t if (info.is_const) ?[*]const info.child else ?[*]info.child;
} {
    const ReturnType = t: {
        const info = @typeInfo(@typeOf(p)).Pointer;
        break :t if (info.is_const) ?[*]const info.child else ?[*]info.child;
    };
    return @ptrCast(ReturnType, p);
}

extern fn keyEvent(window: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
  std.debug.warn("Key event: key={} scancode={} action={} mods={}\n", key, scancode, action, mods);
}

pub fn main() !void {
  if (glfw.glfwInit() == 0) return error.GlfwInitFailed;
  defer glfw.glfwTerminate();

  _ = glfw.glfwSetErrorCallback(errorCallback);

  glfw.glfwWindowHint(glfw.GLFW_DOUBLEBUFFER, 1);
  const window = glfw.glfwCreateWindow(640, 480, c"Hello World", null, null)
      orelse return error.GlfwCreateWindowFailed;
  glfw.glfwMakeContextCurrent(window);
  glfw.glfwSwapInterval(1);

  _ = glfw.glfwSetKeyCallback(window, keyEvent);

  var width: c_int = 0;
  var height: c_int = 0;
  glfw.glfwGetFramebufferSize(window, ptr(&width), ptr(&height));

  const gr_glinterface = skia.gr_glinterface_create_native_interface();
  defer skia.gr_glinterface_unref(gr_glinterface);
  const gr_context = skia.gr_context_make_gl(gr_glinterface)
      orelse return error.SkiaCreateContextFailed;
  defer skia.gr_context_unref(gr_context);

  var fbo: i32 = 0;
  gl.glGetIntegerv(gl.GL_FRAMEBUFFER_BINDING, ptr(&fbo));
  var samples: i32 = 0;
  var stencil_bits: i32 = 0;
  gl.glGetIntegerv(gl.GL_SAMPLES, ptr(&samples));
  gl.glGetIntegerv(gl.GL_STENCIL_BITS, ptr(&stencil_bits));

  const gl_info = skia.gr_gl_framebufferinfo_t {
    .fFBOID = @intCast(c_uint, fbo),
    .fFormat = 0x8058,
  };
  const rendertarget = skia.gr_backendrendertarget_new_gl(
    width,
    height,
    samples,
    stencil_bits,
    ptr(&gl_info),
  );

  const color_type = skia.sk_colortype_get_default_8888();
  const colorspace = null;
  const props = null;
  const surface = skia.sk_surface_new_backend_render_target(
    gr_context,
    rendertarget,
    @intToEnum(skia.gr_surfaceorigin_t, skia.BOTTOM_LEFT_GR_SURFACE_ORIGIN),
    color_type,
    colorspace,
    props,
  ) orelse return error.SkiaCreateSurfaceFailed;
  defer skia.sk_surface_unref(surface);

  const canvas = skia.sk_surface_get_canvas(surface) orelse unreachable;

  while (glfw.glfwWindowShouldClose(window) == 0) {
    skia.sk_canvas_clear(canvas, 0xffffffff);
    try draw(canvas);

    skia.sk_canvas_flush(canvas);
    glfw.glfwSwapBuffers(window);

    glfw.glfwWaitEvents();
  }
}

fn draw(canvas: *skia.sk_canvas_t) !void {
  const fill = skia.sk_paint_new() orelse return error.SkiaCreatePaintFailed;
  defer skia.sk_paint_delete(fill);
  skia.sk_paint_set_color(fill, 0xff0000ff);
  skia.sk_canvas_draw_paint(canvas, fill);

  skia.sk_paint_set_color(fill, 0xff00ffff);
  const rect = skia.sk_rect_t {
    .left = 100,
    .top = 100,
    .right = 540,
    .bottom = 380,
  };
  skia.sk_canvas_draw_rect(canvas, ptr(&rect), fill);

  const stroke = skia.sk_paint_new() orelse return error.SkiaCreatePaintFailed;
  defer skia.sk_paint_delete(stroke);
  skia.sk_paint_set_color(stroke, 0xffff0000);
  skia.sk_paint_set_antialias(stroke, true);
  skia.sk_paint_set_style(stroke, @intToEnum(skia.sk_paint_style_t, skia.STROKE_SK_PAINT_STYLE));
  skia.sk_paint_set_stroke_width(stroke, 5.0);

  const path = skia.sk_path_new() orelse return error.SkiaCreatePathFailed;
  defer skia.sk_path_delete(path);
  skia.sk_path_move_to(path, 50.0, 50.0);
  skia.sk_path_line_to(path, 590.0, 50.0);
  skia.sk_path_cubic_to(path, -490.0, 50.0, 1130.0, 430.0, 50.0, 430.0);
  skia.sk_path_line_to(path, 590.0, 430.0);
  skia.sk_canvas_draw_path(canvas, path, stroke);

  skia.sk_paint_set_color(fill, 0x8000ff00);
  const rect2 = skia.sk_rect_t {
    .left = 120,
    .top = 120,
    .right = 520,
    .bottom = 360,
  };
  skia.sk_canvas_draw_oval(canvas, ptr(&rect2), fill);
}

fn writePng(path: []const u8, surface: *skia.sk_surface_t) !void {
  const image = skia.sk_surface_new_image_snapshot(surface)
      orelse return error.SkiaSnapshotSurfaceFailed;
  defer skia.sk_image_unref(image);
  const data = skia.sk_image_encode(image)
      orelse return error.SkiaImageEncodeFailed;
  defer skia.sk_data_unref(data);

  const bytes = @ptrCast([*]const u8, skia.sk_data_get_data(data));
  const size = skia.sk_data_get_size(data);
  try std.io.writeFile(path, bytes[0..size]);
}
