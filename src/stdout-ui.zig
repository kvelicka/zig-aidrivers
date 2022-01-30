// AI race car drivers
// $ zig build run-stdout <map.ppm |  mpv --no-correct-pts --fps=60 -
//
// Input image format: road is black (000000), barriers are white (ffffff),
// cars start on the green pixel (00ff00) aimed at the blue (0000ff) pixel.

const std = @import("std");
const sim = @import("simulation.zig");

const Vehicle = sim.Vehicle;
const Ppm = sim.Ppm;
const Map = sim.Map;
const Simulation = sim.Simulation;

pub fn main() anyerror!void {
    var vehicles: [25]Vehicle = undefined;
    var allocator = std.testing.allocator;

    var beams = false;
    const width = 800;

    const map_image: Ppm = try Ppm.from_stdin(allocator);
    var map: Map = try Map.from_ppm(&map_image, allocator);
    const scale = std.math.max(width / map.width, 2);
    std.log.info("scale={}", .{scale});
    var simulation = try Simulation.new(&map, scale, &vehicles, allocator);
    var out_image = try Ppm.new(map.width * simulation.scale, map.height * simulation.scale, allocator);
    try simulation.run(1, &out_image, beams);

    const stdout_writer = std.io.getStdOut().writer();
    while (true) {
        try simulation.run(1, &out_image, beams);
        out_image.write(stdout_writer);
    }
}
