# AI driving simulation in Zig

This project is a Zig reimplementation of `aidrivers.c`, as described in [You might not need machine learning](https://nullprogram.com/blog/2020/11/24/).

Some videos of the simulation in action (from the original blog post):
* https://nullprogram.com/video/?v=aidrivers
* https://nullprogram.com/video/?v=aidrivers2
* https://www.youtube.com/watch?v=-sg-GgoFCP0

-----

`aidrivers` produces interesting visual output and it's a self-contained C program, which made reimplementing it perfect for getting more familiar with Zig.
Some features (e.g. most things that would be controlled via cmdline args) are absent or use hardcoded values.

I'm also using this project as a personal testbed for different aspects of zig language/toolchain/libraries.
For example, `aidrivers.c` outputs raw PPM data to stdout. `zig-aidrivers` supports this too (`src/stdout-ui.zig`), but I've included another version that uses [zgt](https://github.com/zenith391/zgt) (`src/zgt-ui.zig`) for the UI.

In the future I'd like to experiment with targeting wasm/web browsers and different UI libraries (microui, Dear ImGui).


## Maps

Input image format: road is black (000000), barriers are white (ffffff), cars start on the green pixel (00ff00) aimed at the blue (0000ff) pixel.

## Building and running

Requires:

* `zig` compiler (developed using Zig `0.10.0-dev` but should build on the stable `0.9.0` too)
* `mogrify` (part of `imagemagick`, at least on Ubuntu).

### Converting included maps to PPM

    mogrify -format ppm map.png
    mogrify -format ppm loop.png

`zig-aidrivers` executables expect a PPM file with the map from stdin.

### `stdout` version

Requires `mpv` or another video player that supports reading PPM from stdin.

    $ zig build run-stdout <map.ppm |  mpv --no-correct-pts --fps=60 -

### `zgt` version

    $ zig build run-zgt <map.ppm
