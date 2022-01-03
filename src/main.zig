// AI race car drivers
// $ cc -Ofast -march=native -fopenmp -o aidrivers aidrivers.c -lm
// $ ./aidrivers <map.ppm | mpv --no-correct-pts --fps=60 -
// $ ./aidrivers <map.ppm | x264 --fps=60 -o out.mp4 --frames 3600 /dev/stdin
// $ zig build && zig-out/bin/aidrivers <map.ppm | mpv --no-correct-pts --fps=60 -./aidrivers <map.ppm | mpv --no-correct-pts --fps=60 -
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
    const scale = 12;
    const nvehicle = 2;
    var vehicles: [nvehicle]Vehicle = .{
        Vehicle{.x = 10, .y = 10, .angle = 3.0, .colour = @enumToInt(Col.red)},
        Vehicle{.x = 10, .y = 10, .angle = 3.0, .colour = @enumToInt(Col.red)}
    };
    var configs: [nvehicle]Config = .{
        Config{.c0 = 0.1, .c1 = 0.1},
        Config{.c0 = 0.5, .c1 = 0.5},
    };
    const cfg = Sysconf{};

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    var allocator = std.testing.allocator;
    // ppm_read map
    const p: Ppm = try readMapStdin(allocator);
    // ppm_to_map
    var map: Map = try Map.ppmToMap(&p, allocator);

    // Format a map or ppm in shell
    // // for (p.data.items) |col, ix| {
    // var i: u32 = 0;
    // while (i < p.width * p.height) : (i += 1) {
    //     if (@rem(i, p.width) == 0) {
    //         try std.fmt.format(std.io.getStdOut().writer(), "\n", .{});
    //     }
    //     // try std.fmt.format(std.io.getStdOut().writer(), "{d:03} ", .{col});
    //     // _ = col;
    //     try std.fmt.format(std.io.getStdOut().writer(), "{} ", .{map.get(@divFloor(i, p.width), @rem(i, p.height))});
    // }

    // create overlay
    var overlay: Ppm = try Ppm.new(p.width * scale, p.height * scale, allocator);
    // draw map
    drawMap(&overlay, &map);
    // ppm_create
    var out = try Ppm.new(p.width * scale, p.height * scale, allocator);
    // randomise configs
    for (configs) |*config| {
        randomise(config, &prng);
    }
    // init  cars
    for (vehicles) |*vehicle| {
        vehicle.x = @intToFloat(f32, map.start_x);
        vehicle.y = @intToFloat(f32, map.start_y);
        vehicle.angle = map.start_angle;
    }
    var t: u64 = 0;
    while (true) : (t += 1) {
        //   copy over overlay
        out.copy_from(&overlay);
        // vehicles[0].angle += 0.1;
        //   draw_vehicles
        drawVehicles(&out, &map, &vehicles);
        //   ppm_write out
        var writer = std.io.getStdOut().writer();
        out.write(writer);
        //   for car in cars:
        for (vehicles) |*vehicle, ix| {
        //     drive
            _ = drive(vehicle, &configs[ix], &map, &cfg);
        }
        //   erase dead cars
    }
}

fn randomise(config: *Config, prng: *std.rand.Xoshiro256) void {
    var random = prng.random();
    const exp: f32 = -32.0;
    config.c0 = 1.0 * random.floatNorm(f32) * @exp2(exp);
    config.c1 = 0.1 * random.floatNorm(f32) * @exp2(exp);
}

fn readMapStdin(allocator: std.mem.Allocator) !Ppm {
    var reader = std.io.getStdIn().reader();
    const ppm = try Ppm.from_reader(reader, allocator);
    return ppm;
}
fn getPixel(pixels: []zimg.color.Rgb24, info: zimg.image.ImageInfo, x: u32, y: u32) zimg.color.Color {
    const loc = info.width * y + x;
    const out =  pixels[loc];
    std.log.debug("px = {}", .{out});
    return out.toColor();
}

fn drive(vehicle: *Vehicle, config: *Config, map: *Map, sysconf: *const Sysconf) bool {
    _ = sysconf;
    _ = config;
    if (!alive(vehicle, map)) {
        return false;
    }

    var senses = [_]f32{0.0} ** 3;
    var angles = [_]f32 {PI/-4.0, 0, PI/4.0};
    for (senses) |_, ix| {
        senses[ix] = sense(vehicle.x, vehicle.y, vehicle.angle + angles[ix], map, null);
    }

    var steering: f32 = senses[2] * config.c0 - senses[0] * config.c0;
    var throttle: f32 = senses[1] * config.c1;
    if (throttle < sysconf.speedmin) {
        throttle = sysconf.speedmin;
    }
    if (throttle > sysconf.speedmax) {
        throttle = sysconf.speedmax;
    }
    vehicle.angle += if (@fabs(steering) > sysconf.control) std.math.copysign(f32, sysconf.control, steering) else steering;
    vehicle.x += throttle * @cos(vehicle.angle);
    vehicle.y += throttle * @sin(vehicle.angle);
    return true;
}

fn sense(x: f32, y: f32, a: f32, map: *Map, maybe_ppm: ?*Ppm) f32 {
    var dx: f32 = @cos(a);
    var dy = @sin(a);
    var d: i32 = 0;
    while (true) : (d += 1) {
        var bx: f32 = x + dx * @intToFloat(f32, d);
        var by = y * dy * @intToFloat(f32, d);
        var ix: i32 = @floatToInt(i32, bx);
        var iy: i32 = @floatToInt(i32, by);
        if (ix < 0 or (ix >= map.width) or (iy < 0) or (iy >= map.height)) {
            break;
        }
        if (map.get(@intCast(u32, ix), @intCast(u32, iy)) > 0) {
            break;
        }
        if(maybe_ppm) |ppm| {
            var scale: u32 = ppm.width / map.width;
            var py: u32 = 0;
            while (py < scale) : (py += 1) {
                var px: u32 = 0;
                while (px < scale) : (px += 1) {
                    ppm.set_pixel(@intCast(u32, ix) * scale + px, @intCast(u3, iy) * scale + py, @enumToInt(Col.red));
                }
            }
        }
    }
    const fd = @intToFloat(f32, d);
    return @sqrt(fd * dx * fd * dx + fd * dy * fd * dy);
}

fn alive(vehicle: *const Vehicle, map: *const Map) bool {
    return map.get(@floatToInt(u32, vehicle.x), @floatToInt(u32, vehicle.y)) > 0;
}

const Vehicle = struct {
    x: f32,
    y: f32,
    angle: f32,
    colour: u64,
};

const Config = struct {
    c0: f32,
    c1: f32,
};

const Sysconf = struct {
    speedmin: f32 = 0.1,
    speedmax: f32 = 0.5,
    // Maximum turn per step
    control: f32 = PI/128.0,
};

const Map = struct {
    width: u32,
    height: u32,
    start_x: u32,
    start_y: u32,
    start_angle: f32,
    data: []u64,

    fn ppmToMap(ppm: *const Ppm, allocator: std.mem.Allocator) !@This() {
        const item_size = 8 * @sizeOf(u64);
        const data_sz = (ppm.width * ppm.height + item_size - 1) / item_size * @sizeOf(u64);
        var map_buf = try allocator.alloc(u64, data_sz);
        std.log.debug("data_sz={}", .{data_sz});
        var ret = Map{
            .width = ppm.width,
            .height = ppm.height,
            .start_x = ppm.width / 2,
            .start_y = ppm.height / 2,
            .start_angle = 0,
            .data = map_buf,
        };
        var x: u32 = 0;
        var y: u32 = 0;
        while (y < ppm.height) : ( y += 1 ) {
            x = 0;
            while (x < ppm.width) : ( x += 1 ) {
                const col = ppm.get_pixel(x, y);
                if (Col.colour(col) == Col.green) {
                    std.log.debug("new start loc! x,y={},{}", .{x, y});
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
                    ret.start_angle = std.math.atan2(f32, fy, fx);
                    std.log.debug("new start angle! a={}", .{ret.start_angle});
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
                ret.data[pixel/item_size] |= v << @intCast(u6, @mod(pixel, item_size));
            }
        }
        return ret;

    }

    fn get(self: *const @This(), x: u32, y: u32) u32 {
        const pixel = y * self.width + x;
        const item_size = 8 * @sizeOf(@TypeOf(self.data[0]));
        return @intCast(u32, self.data[pixel / item_size] >> @intCast(u6, @mod(pixel, item_size)) & 1);
    }
};

const RED: u64 = 0xff0000;
const GREEN: u64 = 0x00ff00;
const BLUE: u64 = 0x0000ff;

const Col = enum(u64) {
    red = 0xff_00_00,
    green = 0x00_ff_00,
    blue = 0x00_00_ff,
    black = 0x00_00_00,
    white = 0xff_ff_ff,
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

    fn new(width: u32, height: u32, allocator: std.mem.Allocator) !Ppm {
        // 3 bytes per colour
        const data_sz = @as(usize, width * height * 3);
        var buf = try std.ArrayList(u8).initCapacity(allocator, data_sz);
        var ii: usize = 0;
        while (ii < data_sz) : (ii += 1) {
            buf.append(0) catch unreachable;
        }
        return Ppm{ .width = width, .height = height, .data = buf };
    }


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

        var out = try new(width, height, allocator);
        try reader.readNoEof(out.data.items);
        return out;
    }

    fn get_pixel(self: @This(), x: u32, y: u32) u64 {
        // todo bounds checks
        // std.log.debug("fetch at {},{}", .{ x, y});
        const loc = 3 * self.width * y + 3 * x;
        const red: u64 = @as(u64, self.data.items[loc + 0]) << 16;
        const green: u64 = @as(u64, self.data.items[loc + 1]) << 8;
        const blue: u64 = @as(u64, self.data.items[loc + 2]) << 0;

        const ret = red | green | blue;
        // std.log.debug("px at {},{} = {}", .{ x, y, Col.colour(ret) });
        return ret;
    }
    fn set_pixel(self: @This(), x: u32, y: u32, val: u64) void {
        // todo bounds checks
        // std.log.debug("set px at {},{} = {}", .{ x, y, Col.colour(val) });
        const loc = 3 * self.width * y + 3 * x;
        // red
        self.data.items[loc + 0] = @truncate(u8, val >> 16);
        // green
        self.data.items[loc + 1] = @truncate(u8, val >> 8);
        // blue
        self.data.items[loc + 2] = @truncate(u8, val >> 0);
    }

    fn copy_from(self: *@This(), src: *Ppm) void {
        std.debug.assert(self.width == src.width);
        std.debug.assert(self.height == src.height);
        const data_sz = @as(usize, self.width * self.height * 3);
        self.data.replaceRange(0, data_sz, src.data.items) catch unreachable;
    }

    fn write(self: *@This(), writer: std.fs.File.Writer) void {
        var buf: [100]u8 = undefined;
        const header = std.fmt.bufPrint(&buf, "P6\n{d} {d}\n255\n", .{self.width, self.height}) catch unreachable;
        _ = writer.write(header) catch unreachable;
        _ = writer.write(self.data.items[0..self.data.items.len]) catch unreachable;
    }
};

fn drawMap(ppm: *Ppm, map: *Map) void {
    var scale: u32 = ppm.width / map.width;
    var y: u32 = 0;
    while (y < ppm.height) : (y += 1) {
        var x: u32 = 0;
        while (x < ppm.width) : (x += 1) {
            const colour: u64 = @enumToInt(if (map.get(x / scale, y / scale) > 0) Col.white else Col.black);
            ppm.set_pixel(x, y, colour);
        }
    }
}

const PI = 3.14;

fn drawVehicles(ppm: *Ppm, map: *Map, vehicles: []Vehicle) void {
    const scale: i32 = @intCast(i32, ppm.width / map.width);
    for (vehicles) |v, i| {
        _ = i;
        var d: i32 = -scale * 2;
        while (d < scale * 2) : (d += 1) {
            var j: i32 = -@divTrunc(scale, 2);
            while (j < @divTrunc(scale, 2)) : (j += 1) {
                const x: f32 = @intToFloat(f32, scale) * v.x + @intToFloat(f32, j) * @cos(v.angle - PI / 2.0) + @intToFloat(f32, d) * @cos(v.angle) / 2.0;
                const y: f32 = @intToFloat(f32, scale) * v.y + @intToFloat(f32, j) * @sin(v.angle - PI / 2.0) + @intToFloat(f32, d) * @sin(v.angle) / 2.0;
                ppm.set_pixel(@floatToInt(u32, x), @floatToInt(u32, y), v.colour);
            }
        }

    }
}
