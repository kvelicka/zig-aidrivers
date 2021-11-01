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

pub fn main() anyerror!void {
    var allocator = std.testing.allocator;
    var reader = std.io.getStdIn().reader();

    const map = try Ppm.from_reader(reader, allocator);
    var i: u32 = 3;
    while (i < 7) : (i += 1) {
        _ = map.get_pixel(22, i);
        _ = map.get_pixel(23, i);
        _ = map.get_pixel(24, i);
        _ = map.get_pixel(25, i);
        _ = map.get_pixel(26, i);
    }
}

const Map = struct {
    width: u32,
    height: u32,
    start_x: u32,
    start_y: u32,
    sa: f32,
    data: []u8,

    fn ppm_to_map(ppm: *Ppm) !@This() {
        _ = ppm;
        return undefined;
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
    w: u32,
    h: u32,
    data: std.ArrayList(u8),

    fn from_reader(reader: std.fs.File.Reader, allocator: *std.mem.Allocator) !@This() {

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
        return Ppm{ .w = width, .h = height, .data = buf };
    }

    fn get_pixel(self: @This(), x: u32, y: u32) u64 {
        const loc = 3 * self.w * y + 3 * x;
        const red: u64 = @as(u64, self.data.items[loc + 0]) << 16;
        const green: u64 = @as(u64, self.data.items[loc + 1]) << 8;
        const blue: u64 = @as(u64, self.data.items[loc + 2]) << 0;

        const ret = red | green | blue;
        std.log.debug("px at {},{} = {}", .{ x, y, Col.colour(ret) });
        return ret;
    }
};
