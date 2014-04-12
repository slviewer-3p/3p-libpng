#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PNG_VERSION="1.6.8"
PNG_SOURCE_DIR="libpng"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild-provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
[ -f "$stage"/packages/include/zlib/zlib.h ] || fail "You haven't installed packages yet."

# Restore all .sos
restore_sos ()
{
    for solib in "${stage}"/packages/lib/{debug,release}/lib*.so*.disable; do 
        if [ -f "$solib" ]; then
            mv -f "$solib" "${solib%.disable}"
        fi
    done
}


# Restore all .dylibs
restore_dylibs ()
{
    for dylib in "$stage/packages/lib"/{debug,release}/*.dylib.disable; do
        if [ -f "$dylib" ]; then
            mv "$dylib" "${dylib%.disable}"
        fi
    done
}

pushd "$PNG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars
            
            build_sln "projects/vstudio/vstudio.sln" "Release Library|Win32" "pnglibconf"
            build_sln "projects/vstudio/vstudio.sln" "Debug Library|Win32" "libpng"
            build_sln "projects/vstudio/vstudio.sln" "Release Library|Win32" "libpng"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a projects/vstudio/Release\ Library/libpng16.lib "$stage/lib/release/libpng16.lib"
            cp -a projects/vstudio/Release\ Library/libpng16.?db "$stage/lib/release/"
            cp -a projects/vstudio/Debug\ Library/libpng16.lib "$stage/lib/debug/libpng16.lib"
            cp -a projects/vstudio/Debug\ Library/libpng16.?db "$stage/lib/debug/"
            mkdir -p "$stage/include/libpng16"
            cp -a {png.h,pngconf.h,pnglibconf.h} "$stage/include/libpng16"
        ;;

        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/

            opts="${TARGET_OPTS:--arch i386 -iwithsysroot $sdk -mmacosx-version-min=10.6}"

            # Install name for dylibs (if we wanted to build them).
            # The outline of a dylib build is here disabled by '#dylib#' 
            # comments.  The basics:  'configure' won't tolerate an
            # '-install_name' option in LDFLAGS so we have to use the
            # 'install_name_tool' to modify the dylibs after-the-fact.
            # This means that executables and test programs are built
            # with a non-relative path which isn't ideal.
            #
            # Dylib builds should also have "-Wl,-headerpad_max_install_names"
            # options to give the 'install_name_tool' space to work.
            #
            target_name="libpng16.16.dylib"
            install_name="@executable_path/../Resources/${target_name}"

            # Force libz static linkage by moving .dylibs out of the way
            # (Libz is currently packaging only statics but keep this alive...)
            trap restore_dylibs EXIT
            for dylib in "$stage"/packages/lib/{debug,release}/libz*.dylib; do
                if [ -f "$dylib" ]; then
                    mv "$dylib" "$dylib".disable
                fi
            done

            # See "linux" section for goals/challenges here...

            CFLAGS="$opts -O0 -gdwarf-2 -fPIC" \
                CXXFLAGS="$opts -O0 -gdwarf-2 -fPIC" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="-L$stage/packages/lib/debug" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --with-zlib-prefix="$stage/packages" --enable-shared=no --with-pic
            make
            make install
            #dylib# install_name_tool -id "${install_name}" "${stage}/lib/debug/${target_name}"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                #dylib# mkdir -p ./Resources/
                #dylib# ln -sf "${stage}"/lib/debug/*.dylib ./Resources/

                make test
                #dylib# Modify the unit test binaries after-the-fact to point
                #dylib# to the expected path then run the tests again.
                #dylib# 
                #dylib# install_name_tool -change "${stage}/lib/debug/${target_name}" "${install_name}" .libs/pngtest
                #dylib# install_name_tool -change "${stage}/lib/debug/${target_name}" "${install_name}" .libs/pngstest
                #dylib# install_name_tool -change "${stage}/lib/debug/${target_name}" "${install_name}" .libs/pngunknown
                #dylib# install_name_tool -change "${stage}/lib/debug/${target_name}" "${install_name}" .libs/pngvalid
                #dylib# make test

                #dylib# rm -rf ./Resources/
            fi

            # clean the build artifacts
            make distclean

            CFLAGS="$opts -O3 -gdwarf-2 -fPIC" \
                CXXFLAGS="$opts -O3 -gdwarf-2 -fPIC" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="-L$stage/packages/lib/release" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --with-zlib-prefix="$stage/packages" --enable-shared=no --with-pic
            make
            make install
            #dylib# install_name_tool -id "${install_name}" "${stage}/lib/release/${target_name}"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                #dylib# mkdir -p ./Resources/
                #dylib# ln -sf "${stage}"/lib/release/*.dylib ./Resources/

                make test
                #dylib# install_name_tool -change "${stage}/lib/release/${target_name}" "${install_name}" .libs/pngtest
                #dylib# install_name_tool -change "${stage}/lib/release/${target_name}" "${install_name}" .libs/pngstest
                #dylib# install_name_tool -change "${stage}/lib/release/${target_name}" "${install_name}" .libs/pngunknown
                #dylib# install_name_tool -change "${stage}/lib/release/${target_name}" "${install_name}" .libs/pngvalid
                #dylib# make test

                #dylib# rm -rf ./Resources/
            fi

            # clean the build artifacts
            make distclean
        ;;

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.6 if available.
            if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Force static linkage to libz by moving .sos out of the way
            # (Libz is only packaging statics right now but keep this working.)
            trap restore_sos EXIT
            for solib in "${stage}"/packages/lib/{debug,release}/libz.so*; do
                if [ -f "$solib" ]; then
                    mv -f "$solib" "$solib".disable
                fi
            done

            # 1.16 INSTALL claims ZLIBINC and ZLIBLIB env vars are active but this is not so.
            # If you fail to pick up the correct version of zlib (from packages), the build
            # will find the system's version and generate the wrong PNG_ZLIB_VERNUM definition
            # in the build.  Mostly you won't notice until certain things try to run.  So
            # check the generated pnglibconf.h when doing development and confirm it's correct.
            #
            # The two-pass session below has the effect of:
            # * Producing only static libraries.
            # * Builds all bin/* targets with static libraries.
            # * Stages the release version of bin/* and include/* over debug.

            # build the debug version and link against the debug zlib
            CFLAGS="$opts -O0 -g" \
                CXXFLAGS="$opts -O0 -g" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="-L$stage/packages/lib/debug" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" --enable-shared=no --with-pic
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make test
            fi

            # clean the build artifacts
            make distclean

            # build the release version and link against the release zlib
            CFLAGS="$opts -O3" \
                CXXFLAGS="$opts -O3" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="-L$stage/packages/lib/release" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" --enable-shared=no --with-pic
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make test
            fi

            # clean the build artifacts
            make distclean
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp -a LICENSE "$stage/LICENSES/libpng.txt"
popd

pass
