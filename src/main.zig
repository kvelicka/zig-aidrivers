// This version does not produce output - it can be used to benchmark the simulation code.

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
    var scale: u32 = 12;

    const map_image: Ppm = try Ppm.from_stdin(allocator);
    var map: Map = try Map.from_ppm(&map_image, allocator);
    var simulation = try Simulation.new(&map, scale, &vehicles, allocator);
    var out_image = try Ppm.new(map.width * simulation.scale, map.height * simulation.scale, allocator);
    try simulation.run(1, &out_image, beams);

    var ticks: usize = 0;
    var timer = try std.time.Timer.start();
    const lap_size = 500;
    while (true) {
        if (ticks % lap_size == 0) {
            const duration = timer.lap();
            // const secs: f64 =  duration / std.time.ns_per_s;
            std.log.info("{} ticks took {}ms", .{lap_size, duration / std.time.ns_per_ms});
        }
        try simulation.run(1, &out_image, beams);
        ticks += 1;
    }
}
