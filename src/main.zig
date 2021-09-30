const std = @import("std");

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
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
    // std.log.debug("data sz {}", .{map.data.items.len});
    // std.log.debug("capacity {}", .{map.data.capacity});
}

const Map = struct {
    width, height: u32,
    start_x, start_y: u32,
    sa: f32,
    data: []u8,

    fn ppm_to_map(ppm: *Ppm) !@This() {
        return undefined;
    }
};

const GREEN: u64 = 0x00ff00;
const BLUE: u64 = 0x0000ff;

const Ppm = struct {
    w: u32,
    h: u32,
    data: std.ArrayList(u8),
    // data: []u8,

    fn new(width: u32, height: u32) @This() {
        return Ppm {
            width,
            height,
            std.ArrayList(u8).initCapacity(a, w * h * 3)
        };
    }

    fn from_reader(reader: std.fs.File.Reader, allocator: *std.mem.Allocator) !@This() {
        const ppm_ver = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        defer allocator.free(ppm_ver);
        const width_height = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        var it = std.mem.split(width_height, " ");
        const width = try std.fmt.parseInt(u32, it.next() orelse unreachable, 10);
        const height = try std.fmt.parseInt(u32, it.next() orelse unreachable, 10);
        while (it.next()) |part| {
            std.log.debug("part is {s}", .{part});
        }
        const max_col_value = try reader.readUntilDelimiterAlloc(allocator, '\n', 100);
        // 3 bytes per colour
        const data_sz = @as(usize, width * height * 3);
        var data = try std.ArrayList(u8).initCapacity(allocator, data_sz);
        try reader.readAllArrayList(&data, data_sz);
        return Ppm { .w = width, .h = height, .data = data };
    }

    fn get_pixel(self: @This(), x: u32, y: u32) u64 {
        const loc = 3 * self.w * y + 3 * x;
        const r: u64 = @as(u64, self.data.items[loc + 0]) << 16;
        const g: u64 = @as(u64, self.data.items[loc + 1]) << 8;
        const b: u64 = @as(u64, self.data.items[loc + 2]) << 0;

        const ret = red | green | blue;
        std.log.debug("px at {},{} = {x}", .{x, y, ret});
        return ret;
    }
};
