# Pectin

*Make your jams gel*

Checks Quake maps for defects to ease the map jam submission and release
process.

# Linux Installation

* Requires that Tcl/Tk and Cargo are installed
* Optionally requires cargo-about (`cargo install cargo-about`)
    * Required if distributing binaries
* run `cargo install pectin`

# Cross-compile from Linux to Windows

* Requires that Cargo be installed
* Requires that the `x86_64-pc-windows-gnu` toolchain be installed
(`rustup toolchain install x86_64-pc-windows-gnu`)
* Requires that Tcl headers are installed (`tcl-dev` on Ubuntu)
* Requires that MinGW w64 be installed (`gcc-mingw-w64-x86-64` on Ubuntu)
* Optionally requires cargo-about (`cargo install cargo-about`)
    * Required if distributing binaries
* run `./cross_windows.sh` from project root

Built package will be located at `<project root>/scratch/package/pectin.zip`

# Usage

Launch `pectin` (Linux) or run `pectin/bin/pectin.exe` from extracted zip
archive (Windows) to run.

Use `File > Open Map(s)` to load 1 or more maps (.bsp files) at a time

Use `File > Open Folder` to load all maps in a directory

Defects are highlighted in red, organized by map filename

# Bug Reports

Report bugs and feature requests to https://github.com/4LT/pectin

Reports should provide system and build information (`Help > About`)

# License

Source code is under one of `CC0-1.0` OR `MIT` OR `Apache-2.0`, your choice

Binary distributions should contain all licenses of dependencies that require
attribution under `Help > About`
