// AI race car drivers
//
// $ zig build run-zgt <map.ppm
//
// Input image format: road is black (000000), barriers are white (ffffff),
// cars start on the green pixel (00ff00) aimed at the blue (0000ff) pixel.

const std = @import("std");
const sim = @import("simulation.zig");

const zgt = @import("zgt");
pub usingnamespace zgt.cross_platform;

const Vehicle = sim.Vehicle;
const Ppm = sim.Ppm;
const Map = sim.Map;
const Simulation = sim.Simulation;

pub fn main() anyerror!void {
    var vehicles: [25]Vehicle = undefined;
    var allocator = std.testing.allocator;

    var beams = false;
    var scale: u32 = 12;

    const map_image: Ppm = try Ppm.from_stdin(allocator);
    var map: Map = try Map.from_ppm(&map_image, allocator);
    var simulation = try Simulation.new(&map, scale, &vehicles, allocator);
    var out_image = try Ppm.new(map.width * simulation.scale, map.height * simulation.scale, allocator);
    try simulation.run(1, &out_image, beams);

    try zgt.backend.init();
    var window = try zgt.Window.init();
    var imageData = try zgt.ImageData.fromBytes(out_image.width, out_image.height, out_image.width * 3, zgt.Colorspace.RGB, out_image.data.items);

    // var button = zgt.Button(.{ .label = "Test" });
    var image = zgt.Image(.{ .data = imageData });
    try window.set(zgt.Column(.{}, .{zgt.Row(.{}, .{ &image })}));

    window.resize(800, 450);
    window.show();
    var frame_start: i64 = 0;
    while (zgt.stepEventLoop(.Asynchronous)) {
        var dt = zgt.internal.milliTimestamp() - frame_start;
        if (dt > 16) {
            try simulation.run(1, &out_image, beams);
            if (image.peer) |*peer| {
                peer.setData(imageData.peer);
            }
            frame_start = zgt.internal.milliTimestamp();
            continue;
        }
        std.time.sleep(16);
    }
}
