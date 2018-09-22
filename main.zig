const std = @import("std");

const glfw = @cImport({
  @cInclude("GLFW/glfw3.h");
});

const skia = @cImport({
  @cInclude("skia/include/c/sk_surface.h");
  @cInclude("skia/include/c/sk_canvas.h");
  @cInclude("skia/include/c/sk_paint.h");
  @cInclude("skia/include/c/sk_image.h");
  @cInclude("skia/include/c/sk_data.h");
});

pub fn main() !void {
//  if (glfw.glfwInit() == 0) return error.GlfwInitFailed;
//  defer glfw.glfwTerminate();

//  const window = glfw.glfwCreateWindow(640, 480, c"Hello World", null, null)
//      orelse return error.GlfwCreateWindowFailed;

  const allocator = std.heap.c_allocator;

  const imageinfo = skia.sk_imageinfo_t {
    .width = 640,
    .height = 480,
    .colorType = skia.sk_colortype_get_default_8888(),
    .alphaType = @intToEnum(skia.sk_alphatype_t, skia.PREMUL_SK_ALPHATYPE),
    .colorspace = null,
  };
  const surface = skia.sk_surface_new_raster(@ptrCast([*] const
  skia.sk_imageinfo_t, &imageinfo), 0, null) orelse return
  error.SkiaCreateSurfaceFailed;
  defer skia.sk_surface_unref(surface);
  const canvas = skia.sk_surface_get_canvas(surface) orelse return error.SkiaSurfaceFailed;
  draw(canvas);

  try writePng("out.png", surface);
}

fn draw(canvas: *skia.sk_canvas_t) void {
  const fill = skia.sk_paint_new() orelse return error.SkiaNewPaintFailed;
  defer skia.sk_paint_delete(fill);
  skia.sk_paint_set_color(fill, 0xff0000ff);
  skia.sk_canvas_draw_paint(canvas, fill);
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
