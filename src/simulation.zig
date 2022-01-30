const std = @import("std");

const PI = 3.14;


pub const Vehicle = struct {
    x: f32,
    y: f32,
    angle: f32,
    colour: u64,
    c0: f32,
    c1: f32,

    pub fn new(x: u32, y: u32, angle: f32, random: std.rand.Random) Vehicle {
        const exp: f32 = -32.0;
        return Vehicle{
            .x = @intToFloat(f32, x),
            .y = @intToFloat(f32, y),
            .angle = angle,
            .colour = random.int(u32) >> 8 | 0x404040,
            .c0 = 1.0 * @intToFloat(f32, random.int(u32)) * @exp2(exp),
            .c1 = 0.1 * @intToFloat(f32, random.int(u32)) * @exp2(exp),
        };
    }
};

const Config = struct {
    speedmin: f32 = 0.1,
    speedmax: f32 = 0.5,
    // Maximum turn per step
    control: f32 = PI / 128.0,
};

pub const Map = struct {
    width: u32,
    height: u32,
    start_x: u32,
    start_y: u32,
    start_angle: f32,
    data: []bool,

    pub fn from_ppm(ppm: *const Ppm, allocator: std.mem.Allocator) !@This() {
        var map_buf = try allocator.alloc(bool, ppm.width * ppm.height);
        for (map_buf) |*item| {
            item.* = false;
        }
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
        while (y < ppm.height) : (y += 1) {
            x = 0;
            while (x < ppm.width) : (x += 1) {
                const col = ppm.get_pixel(x, y);
                if (Col.colour(col) == Col.green) {
                    std.log.debug("new start loc! x,y={},{}", .{ x, y });
                    ret.start_x = x;
                    ret.start_y = y;
                }
            }
        }
        y = 0;
        while (y < ppm.height) : (y += 1) {
            x = 0;
            while (x < ppm.width) : (x += 1) {
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
        while (y < ppm.height) : (y += 1) {
            x = 0;
            while (x < ppm.width) : (x += 1) {
                const col = ppm.get_pixel(x, y);
                const v = col >> 16 > 0x7f;
                const pixel: usize = y * ppm.width + x;
                ret.data[pixel] = v;
            }
        }
        return ret;
    }

    fn get(self: *const @This(), x: u32, y: u32) bool {
        const pixel = y * self.width + x;
        return self.data[pixel];
    }
};

const Col = enum(u64) {
    red = 0xff_00_00,
    green = 0x00_ff_00,
    blue = 0x00_00_ff,
    black = 0x00_00_00,
    white = 0xff_ff_ff,
    unexpected,

    fn colour(in: u64) @This() {
        switch (in) {
            0xff_00_00 => return .red,
            0x00_ff_00 => return .green,
            0x00_00_ff => return .blue,
            0 => return .black,
            0xff_ff_ff => return .white,
            else => {
                std.log.debug("colour got unexpected {x}", .{in});
                return .unexpected;
            },
        }
    }
};

pub const Ppm = struct {
    width: u32,
    height: u32,
    data: std.ArrayList(u8),

    pub fn new(width: u32, height: u32, allocator: std.mem.Allocator) !Ppm {
        // 3 bytes per colour
        const data_sz = @as(usize, width * height * 3);
        var buf = try std.ArrayList(u8).initCapacity(allocator, data_sz);
        var ii: usize = 0;
        while (ii < data_sz) : (ii += 1) {
            buf.append(0) catch unreachable;
        }
        return Ppm{ .width = width, .height = height, .data = buf };
    }

    pub fn from_reader(reader: std.fs.File.Reader, allocator: std.mem.Allocator) !@This() {
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

    pub fn get_pixel(self: @This(), x: u32, y: u32) u64 {
        const loc = 3 * self.width * y + 3 * x;
        std.debug.assert(loc < self.data.items.len);
        const red: u64 = @as(u64, self.data.items[loc + 0]) << 16;
        const green: u64 = @as(u64, self.data.items[loc + 1]) << 8;
        const blue: u64 = @as(u64, self.data.items[loc + 2]) << 0;

        const ret = red | green | blue;
        return ret;
    }
    pub fn set_pixel(self: @This(), x: u32, y: u32, val: u64) void {
        const loc = 3 * self.width * y + 3 * x;
        std.debug.assert(loc < self.data.items.len);
        // red
        self.data.items[loc + 0] = @truncate(u8, val >> 16);
        // green
        self.data.items[loc + 1] = @truncate(u8, val >> 8);
        // blue
        self.data.items[loc + 2] = @truncate(u8, val >> 0);
    }

    pub fn copy_from(self: *@This(), src: *Ppm) void {
        std.debug.assert(self.width == src.width);
        std.debug.assert(self.height == src.height);
        const data_sz = @as(usize, self.width * self.height * 3);
        self.data.replaceRange(0, data_sz, src.data.items) catch unreachable;
    }

    pub fn write(self: *@This(), writer: std.fs.File.Writer) void {
        var buf: [100]u8 = undefined;
        const header = std.fmt.bufPrint(&buf, "P6\n{d} {d}\n255\n", .{ self.width, self.height }) catch unreachable;
        _ = writer.write(header) catch unreachable;
        _ = writer.write(self.data.items[0..self.data.items.len]) catch unreachable;
    }

    pub fn from_stdin(allocator: std.mem.Allocator) !Ppm {
        var reader = std.io.getStdIn().reader();
        const ppm = try Ppm.from_reader(reader, allocator);
        return ppm;
    }
};

pub const Simulation = struct {
    scale: u32,
    cfg: Config = Config{},
    t: u64 = 0,

    vehicles: []Vehicle,
    allocator: std.mem.Allocator,
    overlay: Ppm,
    map: *Map,

    const Self = @This();

    pub fn new(map: *Map, scale: u32, vehicles: []Vehicle, allocator: anytype) !Simulation {
        var out = Simulation{
            .vehicles = vehicles,
            .allocator = allocator,
            .overlay = try Ppm.new(map.width * scale, map.height * scale, allocator),
            .map = map,
            .scale = scale,
        };

        var random = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.os.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        }).random();
        for (vehicles) |*vehicle| {
            vehicle.* = Vehicle.new(map.start_x, map.start_y, map.start_angle, random);
        }

        out.drawMap();
        return out;
    }

    pub fn run(self: *Self, gens: u32, out_image: *Ppm, beams: bool) !void {
        if (self.vehicles.len == 0) {
            return;
        }
        var gens_done: u32 = 0;
        while (gens_done < gens) : (gens_done += 1) {
            out_image.copy_from(&self.overlay);
            self.drawVehicles(out_image, self.vehicles);
            if (beams) {
                for (self.vehicles) |*vehicle| {
                    _ = self.sense(vehicle.x, vehicle.y, vehicle.angle - PI / 4.0, out_image);
                    _ = self.sense(vehicle.x, vehicle.y, vehicle.angle, out_image);
                    _ = self.sense(vehicle.x, vehicle.y, vehicle.angle + PI / 4.0, out_image);
                }
            }
            for (self.vehicles) |*vehicle| {
                _ = self.drive(vehicle);
            }
            for (self.vehicles) |*vehicle, ix| {
                if (!self.alive(vehicle)) {
                    self.drawVehicles(&self.overlay, self.vehicles[ix..ix]);
                }
            }
            if (self.vehicles.len == 0) {
                return;
            }
            self.t += 1;
        }
    }

    fn drawMap(self: *Self) void {
        var y: u32 = 0;
        while (y < self.overlay.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.overlay.width) : (x += 1) {
                const colour: u64 = @enumToInt(if (self.map.get(x / self.scale, y / self.scale)) Col.white else Col.black);
                self.overlay.set_pixel(x, y, colour);
            }
        }
    }

    fn drawVehicles(self: *Self, ppm: *Ppm, vehicles: []Vehicle) void {
        const scale: i32 = @intCast(i32, self.scale);
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

    fn drive(self: *Self, vehicle: *Vehicle) bool {
        if (!self.alive(vehicle)) {
            return false;
        }

        var senses = [_]f32{0.0} ** 3;
        var angles = [_]f32{ PI / -4.0, 0, PI / 4.0 };
        for (senses) |_, ix| {
            senses[ix] = self.sense(vehicle.x, vehicle.y, vehicle.angle + angles[ix], null);
        }

        var steering: f32 = senses[2] * vehicle.c0 - senses[0] * vehicle.c0;
        var throttle: f32 = senses[1] * vehicle.c1;
        if (throttle < self.cfg.speedmin) {
            throttle = self.cfg.speedmin;
        }
        if (throttle > self.cfg.speedmax) {
            throttle = self.cfg.speedmax;
        }
        vehicle.angle += if (@fabs(steering) > self.cfg.control) std.math.copysign(f32, self.cfg.control, steering) else steering;
        vehicle.x += throttle * @cos(vehicle.angle);
        vehicle.y += throttle * @sin(vehicle.angle);
        return true;
    }

    fn sense(self: *Self, x: f32, y: f32, a: f32, maybe_ppm: ?*Ppm) f32 {
        var dx: f32 = @cos(a);
        var dy = @sin(a);
        var d: i32 = 0;
        while (true) : (d += 1) {
            var bx: f32 = x + dx * @intToFloat(f32, d);
            var by = y + dy * @intToFloat(f32, d);
            var ix: i32 = @floatToInt(i32, bx);
            var iy: i32 = @floatToInt(i32, by);
            if (ix < 0 or (ix >= self.map.width) or (iy < 0) or (iy >= self.map.height)) {
                break;
            }
            if (self.map.get(@intCast(u32, ix), @intCast(u32, iy))) {
                break;
            }
            if (maybe_ppm) |ppm| {
                var scale: u32 = ppm.width / self.map.width;
                var py: u32 = 0;
                while (py < scale) : (py += 1) {
                    var px: u32 = 0;
                    while (px < scale) : (px += 1) {
                        ppm.set_pixel(@intCast(u32, ix) * scale + px, @intCast(u32, iy) * scale + py, @enumToInt(Col.red));
                    }
                }
            }
        }
        const fd = @intToFloat(f32, d);
        return @sqrt(fd * dx * fd * dx + fd * dy * fd * dy);
    }

    fn alive(self: *Self, vehicle: *const Vehicle) bool {
        return !self.map.get(@floatToInt(u32, vehicle.x), @floatToInt(u32, vehicle.y));
    }

};
