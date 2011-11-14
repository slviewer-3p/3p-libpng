#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PNG_VERSION="1.5.1"
PNG_SOURCE_DIR="libpng-$PNG_VERSION"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$PNG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars
            
            build_sln "projects/vstudio/vstudio.sln" "Release Library|Win32" "pnglibconf"
            build_sln "projects/vstudio/vstudio.sln" "Debug Library|Win32" "libpng"
            build_sln "projects/vstudio/vstudio.sln" "Release Library|Win32" "libpng"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp projects/vstudio/Release\ Library/libpng15.lib "$stage/lib/release/libpng15.lib"
            cp projects/vstudio/libpng/Release\ Library/vc100*\.?db "$stage/lib/release/"
            cp projects/vstudio/Debug\ Library/libpng15.lib "$stage/lib/debug/libpng15.lib"
            cp projects/vstudio/libpng/Debug\ Library/vc100*\.?db "$stage/lib/debug/"
            mkdir -p "$stage/include/libpng15"
            cp {png.h,pngconf.h,pnglibconf.h} "$stage/include/libpng15"
        ;;
        "darwin")
            ./configure --prefix="$stage" --with-zlib-prefix="$stage/packages"
            make
            make install
	    mkdir -p "$stage/lib/release"
	    cp "$stage/lib/libpng15.a" "$stage/lib/release/"
        ;;
        "linux")
			# build the release version and link against the release zlib
			CFLAGS="-m32 -O2 -I$stage/packages/include -L$stage/packages/lib/release" CXXFLAGS="-m32 -O2 -I$stage/packages/include -L$stage/packages/lib/release" ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include"
            make
            make install

			# clean the build artifacts
			make distclean

			# build the debug version and link against the debug zlib
			CFLAGS="-m32 -O0 -gstabs+ -I$stage/packages/include -L$stage/packages/lib/debug" CXXFLAGS="-m32 -O0 -gstabs+ -I$stage/packages/include -L$stage/packages/lib/debug" ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include"
            make
            make install
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/libpng.txt"
popd

pass
