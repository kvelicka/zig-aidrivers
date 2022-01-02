// AI race car drivers
// $ cc -Ofast -march=native -fopenmp -o aidrivers aidrivers.c -lm
// $ ./aidrivers <map.ppm | mpv --no-correct-pts --fps=60 -
// $ ./aidrivers <map.ppm | x264 --fps=60 -o out.mp4 --frames 3600 /dev/stdin
//
// Input image format: road is black (000000), barriers are white (ffffff),
// cars start on the green pixel (00ff00) aimed at the blue (0000ff) pixel.
//
// Ref: https://nullprogram.com/video/?v=aidrivers
// Ref: https://nullprogram.com/video/?v=aidrivers2
// Ref: https://www.youtube.com/watch?v=-sg-GgoFCP0
//
const std = @import("std");
const zimg = @import("zigimg");
// const PPM = zimg.netpbm.PPM;

pub fn main() anyerror!void {
    var allocator = std.testing.allocator;
    const p: Ppm = try readMapStdin(allocator);
    // std.log.debug("ppm={}", .{p});
    const map: Map = try Map.ppmToMap(&p, allocator);
    std.log.debug("map={}", .{map.width});
    // ppm_read map
    // ppm_to_map
    // create overlay
    // draw map
    // ppm_create
    // randomise configs
    // init  cars
    // while true
    //   copy over overlay
    //   draw_vehicles
    //   ppm_write out
    //   for car in cars:
    //     drive
    //   eras dead cars
}

fn readMapStdin(allocator: std.mem.Allocator) !Ppm {
    var reader = std.io.getStdIn().reader();
    const ppm = try Ppm.from_reader(reader, allocator);
    // _ = map.get_pixel(24, 4);
    // _ = map.get_pixel(25, 4);
    return ppm;
}
fn getPixel(pixels: []zimg.color.Rgb24, info: zimg.image.ImageInfo, x: u32, y: u32) zimg.color.Color {
    const loc = info.width * y + x;
    const out =  pixels[loc];
    std.log.debug("px = {}", .{out});
    return out.toColor();
}

const Map = struct {
    width: u32,
    height: u32,
    start_x: u32,
    start_y: u32,
    sa: f32,
    data: []u64,

    fn ppmToMap(ppm: *const Ppm, allocator: std.mem.Allocator) !@This() {
        const item_size = 8 * @sizeOf(@TypeOf(ppm.data.items[0]));
        const data_sz = (ppm.width * ppm.height + item_size - 1) / item_size * @sizeOf(u8);
        var map_buf = try allocator.alloc(u64, data_sz);
        std.log.debug("data_sz={}", .{data_sz});
        // const item_size = 8@sizeOf(u64);
        var ret = Map{
            .width = ppm.width,
            .height = ppm.height,
            .start_x = ppm.width / 2,
            .start_y = ppm.height / 2,
            .sa = 0,
            .data = map_buf,
        };
        var x: u32 = 0;
        var y: u32 = 0;
        while (y < ppm.height) : ( y += 1 ) {
            x = 0;
            while (x < ppm.width) : ( x += 1 ) {
                const col = ppm.get_pixel(x, y);
                if (Col.colour(col) == Col.green) {
                    std.log.debug("new start! x,y={},{}", .{x, y});
                    ret.start_x = x;
                    ret.start_y = y;
                }
            }
        }
        y = 0;
        while (y < ppm.height) : ( y += 1 ) {
            x = 0;
            while (x < ppm.width) : ( x += 1 ) {
                const col = ppm.get_pixel(x, y);
                if (Col.colour(col) == Col.blue) {
                    const fy: f32 = @intToFloat(f32, (y - ret.start_y));
                    const fx: f32 = @intToFloat(f32, x - ret.start_x);
                    ret.sa = std.math.atan2(f32, fy, fx);
                }
            }
        }
        y = 0;
        while (y < ppm.height) : ( y += 1 ) {
            x = 0;
            while (x < ppm.width) : ( x += 1 ) {
                const col = ppm.get_pixel(x, y);
                const v = @as(u64, @boolToInt(col >> 16 > 0x7f));
                const pixel: usize = y * ppm.width + x;
                // ret.data[pixel/item_size] |= v << (pixel % item_size);
                ret.data[pixel/item_size] |= v << @intCast(u6, @mod(pixel, item_size));
            }
        }
        return ret;

    }
};

const RED: u64 = 0xff0000;
const GREEN: u64 = 0x00ff00;
const BLUE: u64 = 0x0000ff;

const Col = enum {
    red,
    green,
    blue,
    black,
    white,
    unexpected,

    fn colour(in: u64) @This() {
        switch (in) {
            RED => return .red,
            GREEN => return .green,
            BLUE => return .blue,
            0 => return .black,
            0xffffff => return .white,
            else => {
                std.log.debug("colour got unexpected {x}", .{in});
                return .unexpected;
            },
        }
    }
};

const Ppm = struct {
    width: u32,
    height: u32,
    data: std.ArrayList(u8),

    fn from_reader(reader: std.fs.File.Reader, allocator: std.mem.Allocator) !@This() {
        const ppm_ver = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        defer allocator.free(ppm_ver);

        const width_height = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        defer allocator.free(width_height);
        var it = std.mem.split(u8, width_height, " ");
        const width = try std.fmt.parseInt(u32, it.next() orelse unreachable, 10);
        const height = try std.fmt.parseInt(u32, it.next() orelse unreachable, 10);

        const max_col_value = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        std.log.info("ppm_ver={s} w={} h={} max_col_value={s}", .{ ppm_ver, width, height, max_col_value });

        // 3 bytes per colour
        const data_sz = @as(usize, width * height * 3);
        var buf = try std.ArrayList(u8).initCapacity(allocator, data_sz);
        try reader.readAllArrayList(&buf, data_sz);
        return Ppm{ .width = width, .height = height, .data = buf };
    }

    fn get_pixel(self: @This(), x: u32, y: u32) u64 {
        // todo bounds checks
        std.log.debug("fetch at {},{}", .{ x, y});
        const loc = 3 * self.width * y + 3 * x;
        const red: u64 = @as(u64, self.data.items[loc + 0]) << 16;
        const green: u64 = @as(u64, self.data.items[loc + 1]) << 8;
        const blue: u64 = @as(u64, self.data.items[loc + 2]) << 0;

        const ret = red | green | blue;
        // std.log.debug("px at {},{} = {}", .{ x, y, Col.colour(ret) });
        return ret;
    }
};

// fn zigimg() !void {
//     var allocator = std.testing.allocator;
//     var ss = std.io.StreamSource{ .file = std.io.getStdIn() };
//     var storage: ?zimg.color.ColorStorage = null;
//     const info = try PPM.readForImage(allocator, ss.reader(), undefined, &storage);
//     std.log.debug("image_info={}", .{info});

//         var it = zimg.color.ColorStorageIterator.init(&storage.?);
//         while (it.next()) |itm| {
//             _ = itm;
//             break;
//             // std.log.debug("itm={}", .{itm});
//         }
//         switch(storage.?) {
//             .Rgb24 => |data| _ = {
//                 _ = getPixel(data, info, 24, 4);
//                 _ = getPixel(data, info, 25, 4);
//                 // _ = getPixel(data, info, 100, 40);
//             },
//             else => unreachable,
//     }
// }
