#!/bin/sh

project_root = "$PWD"

cd subtree/tcl/win/

if test \! -e build; then
    mkdir build
fi

cd build

if test \! -e Makefile; then
    ../configure --enable-64bit
fi

make

ln -sf tcl86.dll tcl8.6.dll

cd "$project_root"

RUSTFLAGS='-L vendor/tcl/win/build'\
    PKG_CONFIG_ALLOW_CROSS=1\
    BINDGEN_EXTRA_CLANG_ARGS='-D__int64="long long" -Dssize_t=int64_t'\
    cargo build --target=x86_64-pc-windows-gnu --release
