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
            
            pushd contrib/masmx86
                ./bld_ml32.bat
            popd
            
            build_sln "contrib/vstudio/vc10/zlibvc.sln" "Debug|Win32" "zlibstat"
            build_sln "contrib/vstudio/vc10/zlibvc.sln" "Release|Win32" "zlibstat"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp "contrib/vstudio/vc10/x86/ZlibStatDebug/zlibstat.lib" \
                "$stage/lib/debug/zlibd.lib"
            cp "contrib/vstudio/vc10/x86/ZlibStatRelease/zlibstat.lib" \
                "$stage/lib/release/zlib.lib"
            mkdir -p "$stage/include/zlib"
            cp {zlib.h,zconf.h} "$stage/include/zlib"
        ;;
        "darwin")
            ./configure --prefix="$stage" --with-zlib-prefix="$stage/packages"
            make
            make install
	    mkdir -p "$stage/lib/release"
	    cp "$stage/lib/libpng15.a" "$stage/lib/release/"
        ;;
        "linux")
            CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage/packages" --with-zlib-prefix="$stage/packages"
            make
            make install
	    mkdir -p "$stage/lib/release"
	    cp "$stage/lib/libpng15.a" "$stage/lib/release/"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/libpng.txt"
popd

pass

