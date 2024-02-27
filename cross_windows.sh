#!/bin/sh

script=`readlink -fn "$0"`
project_root=`dirname "$script"`
tcl_tag=core-8-6-13
cd "$project_root"

mkdir -p scratch/package/pectin/bin
mkdir -p scratch/package/pectin/lib

# -- Download & build Tcl --
cd scratch

if test \! -e tcl-${tcl_tag}.tar.gz; then
    curl --location -o tcl-${tcl_tag}.tar.gz\
        https://github.com/tcltk/tcl/archive/refs/tags/${tcl_tag}.tar.gz
fi

tar -xf tcl-${tcl_tag}.tar.gz
cd tcl-${tcl_tag}/win
mkdir -p build
cd build

if test \! -e Makefile; then
    ../configure --enable-64bit --prefix="$PWD"
fi

make
make install-libraries TCL_EXE=tclsh
ln -sf tcl86.dll tcl8.6.dll

# -- Download & build Tk --
cd "$project_root"/scratch

if test \! -e tk-${tcl_tag}.tar.gz; then
    curl --location -o tk-${tcl_tag}.tar.gz\
        https://github.com/tcltk/tk/archive/refs/tags/${tcl_tag}.tar.gz
fi

tar -xf tk-${tcl_tag}.tar.gz
cd tk-${tcl_tag}/win
mkdir -p build
cd build

if test \! -e Makefile; then
    ../configure --enable-64bit --with-tcl=../../../tcl-${tcl_tag}/win/build\
        --prefix="$PWD"
fi

make
make install TCL_EXE=tclsh

# -- Build exe --
cd "$project_root"

RUSTFLAGS="-L scratch/tcl-${tcl_tag}/win/build"\
    PKG_CONFIG_ALLOW_CROSS=1\
    BINDGEN_EXTRA_CLANG_ARGS='-D__int64="long long" -Dssize_t=int64_t'\
    cargo build --target=x86_64-pc-windows-gnu --release || exit 1

#  -- Build package --
cd scratch/package/pectin
cp "${project_root}/target/x86_64-pc-windows-gnu/release/pectin.exe" bin/
cp "${project_root}/scratch/tcl-${tcl_tag}/win/build/tcl86.dll" bin/
cp "${project_root}/scratch/tcl-${tcl_tag}/win/build/zlib1.dll" bin/
cp "${project_root}/scratch/tk-${tcl_tag}/win/build/tk86.dll" bin/
rm -rf lib/tcl8.6
cp -r "${project_root}/scratch/tcl-${tcl_tag}/win/build/lib/tcl8.6" lib/
rm -rf lib/tk8.6
cp -r "${project_root}/scratch/tk-${tcl_tag}/win/build/lib/tk8.6" lib/tk8.6
cd "${project_root}/scratch/package"
rm -f pectin.zip
zip -r pectin.zip pectin || exit 1
