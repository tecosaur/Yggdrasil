using BinaryBuilder

name = "LibGit2"
version = v"1.3.0"

# Collection of sources required to build libgit2
sources = [
    GitSource("https://github.com/libgit2/libgit2.git",
              "b7bad55e4bb0a285b073ba5e02b01d3f522fc95d"),
    DirectorySource("./bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/libgit2*/

atomic_patch -p1 $WORKSPACE/srcdir/patches/libgit2-agent-nonfatal.patch
atomic_patch -p1 $WORKSPACE/srcdir/patches/libgit2-hostkey.patch

BUILD_FLAGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DTHREADSAFE=ON
    -DUSE_BUNDLED_ZLIB=ON
    "-DCMAKE_INSTALL_PREFIX=${prefix}"
    "-DCMAKE_TOOLCHAIN_FILE="${CMAKE_TARGET_TOOLCHAIN}""
)

# Special windows flags
if [[ ${target} == *-mingw* ]]; then
    BUILD_FLAGS+=(-DWIN32=ON -DMINGW=ON -DBUILD_CLAR=OFF)
    if [[ ${target} == i686-* ]]; then
        BUILD_FLAGS+=(-DCMAKE_C_FLAGS="-mincoming-stack-boundary=2")
    fi

    # For some reason, CMake fails to find libssh2 using pkg-config.
    BUILD_FLAGS+=(-Dssh2_RESOLVED=${bindir}/libssh2.dll)
elif [[ ${target} == *linux* ]] || [[ ${target} == *freebsd* ]]; then
    # If we're on Linux or FreeBSD, explicitly ask for mbedTLS instead of OpenSSL
    BUILD_FLAGS+=(-DUSE_HTTPS=mbedTLS -DSHA1_BACKEND=CollisionDetection -DCMAKE_INSTALL_RPATH="\$ORIGIN")
fi
export CFLAGS="-I${prefix}/include"

mkdir build && cd build

cmake .. "${BUILD_FLAGS[@]}"
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libgit2", :libgit2),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("MbedTLS_jll"; compat="~2.28.0"),
    Dependency("LibSSH2_jll"; compat="1.10.1"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.8")

