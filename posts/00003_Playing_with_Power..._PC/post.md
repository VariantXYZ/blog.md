I bought a cheap 2004 iBook G4 for like 35$ and wanted to see if I could bring some life to it for something like no-distraction Gameboy development or just writing stuff. For how old it is, OS X 10.4.11 (Tiger) runs pretty well... but not well enough for me to try building complex things on it (a Gameboy toolchain is about it). So, I figured my project for the week would be to see what the state of cross-compiling a modern toolchain for a >20 year old system would look like.

The original verison of this post from yesterday actually relied on some ancient binaries from old versions of XCode, but thanks to the dedicated efforts of several people in the last decade, we have a fairly recent ld we can build on anything with Clang 10 or higher and some useful information.

For reference, you can see the original markdown for that post [here](https://github.com/VariantXYZ/blog.md/blob/5a1277e651acd204fd1e182680be3a698fea241a/posts/00003_Playing_with_Power..._PC/post.md).

It's pretty cool how many people still seem to want to keep these old things alive.

Anyway, here's what I've accumulated to build the rgbds toolchain for powerpc-apple-darwin8.

My updated Dockerfile for different versions of GCC and SDKs can be found [here](https://github.com/VariantXYZ/gcc-powerpc-apple-darwin8).

<style>
pre {
    display: block;
    white-space: pre-wrap;
    word-wrap: break-word; 
    overflow-wrap: break-word; 
    font-family: monospace;
    background: lightgray;
}
</style>

## References

[Bluzt3's Blog]: https://maniacsvault.net/articles/powerpccross
[OSDev Wiki]: https://wiki.osdev.org/GCC_Cross-Compiler
[OSXCross/cctools-port]: https://github.com/tpoechtrager/cctools-port

* [Bluzt3's Blog][]
* [OSDev Wiki][]
* [OSXCross/cctools-port][]

## Pre-requisites

* clang > 10
* CMake > 3.4.3
* Make > 4
* Whatever GCC might need (I needed to do `brew install texinfo`)
* `llvm-devel` if you want LTO support (recommend it)

The following instructions all operate based on the environment variables below and from a root directory.

Here's the set of installed binaries on Ubuntu 24.04

    apt-get update -q && \
        apt-get install -y \
        cmake \
        ninja-build \
        build-essential \
        clang \
        llvm-dev \
        git \
        python3 \
        wget \
        flex \
        texinfo \
        file \
        autoconf \
        libssl-dev \
        libz-dev \
        libtool-bin \
        && apt-get autoremove -y --purge \
        && apt-get clean -y \
        && rm -rf /var/lib/apt/lists/*

## Environment

    export ROOT_DIR="$(pwd)"
    export TARGET_PREFIX="$(pwd)/install/target"
    export TARGET=powerpc-apple-darwin8
    export MAC_SDK_VERSION=MacOSX10.4u
    export MACOSX_PPC_DEPLOYMENT_TARGET=10.4
    mkdir -p "$TARGET_PREFIX"

**NOTE**: We are using the 10.4 SDK but will need to rebuild crt1.o. This is due to the [issue with 10.4's crt1.o](https://github.com/tpoechtrager/osxcross/issues/50#issuecomment-149013354). 10.5 should theoretically work too.

## cctools

Reference this long discussion [here](https://github.com/tpoechtrager/cctools-port/issues/119) where a lot of people chime in on how to get this all working. Or don't, and just note the final results below, that's cool too.

### dsymutil

Not included as part of the rest of cctools, so we'll quickly build llvm 7.1.1, which is the last version with powerpc-apple-darwin8 target support with dsymutil.

This is easily the longest part of the whole process because apparently we need to build a ton of LLVM before we can build dsymutil...

    mkdir -p $ROOT_DIR/llvm-project && \
        cd $ROOT_DIR/llvm-project && \
        git init && \
        git remote add origin https://github.com/llvm/llvm-project.git && \
        git fetch --depth 1 origin 4856a9330ee01d30e9e11b6c2f991662b4c04b07 && \
        git checkout FETCH_HEAD

    mkdir -p $ROOT_DIR/build/target/llvm-project && \
    cd $ROOT_DIR/build/target/llvm-project && \
    CC=clang CXX=clang++ cmake -G Ninja $ROOT_DIR/llvm-project/llvm \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_TARGETS_TO_BUILD="PowerPC" \
      -DLLVM_ENABLE_ASSERTIONS=OFF && \
    ninja dsymutil && \
    mkdir -p $TARGET_PREFIX/bin && \
    cp bin/dsymutil $TARGET_PREFIX/bin/$TARGET-dsymutil && \
    cd $ROOT_DIR && \
    rm -rf $ROOT_DIR/build/target/llvm-project && \
    rm -rf $ROOT_DIR/llvm-project

### ld, as, ar, lipo, nm, ranlib

    mkdir -p $ROOT_DIR/cctools-port && \
    cd $ROOT_DIR/cctools-port && \
    git init && \
    git remote add origin https://github.com/tpoechtrager/cctools-port.git && \
    git fetch --depth 1 origin 6694f27d56923e64e6190c8d3eb149413768e9b7 && \
    git checkout FETCH_HEAD && \
    cd cctools && \
    ./autogen.sh

    mkdir -p $ROOT_DIR/build/target/cctools-port && \
    cd $ROOT_DIR/build/target/cctools-port && \
    $ROOT_DIR/cctools-port/cctools/configure CC=clang CXX=clang++ --prefix="$TARGET_PREFIX" --target=$TARGET && \
    make -j2 && \
    make install -j && \
    mkdir -p $TARGET_PREFIX/$TARGET/bin && \
    for i in ld ar as lipo nm ranlib strip dsymutil; do \
      ln -s "$TARGET_PREFIX/bin/$TARGET-$i" "$TARGET_PREFIX/$TARGET/bin/$i"; \
    done && \
    cd $ROOT_DIR && \
    rm -rf $ROOT_DIR/build/target/cctools-port && \
    rm -rf $ROOT_DIR/cctools-port

(Note we also symlink for convenience here)

## MacOSX SDK

    wget https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/$MAC_SDK_VERSION.sdk.tar.xz
    tar xf ./$MAC_SDK_VERSION.sdk.tar.xz -C $TARGET_PREFIX

We explicitly copy it into the prefix so it should benefit from the `--with-sysroot` option, at least according to the GCC docs:
`If the specified directory is a subdirectory of ${exec_prefix}, then it will be found relative to the GCC binaries if the installation tree is moved.`

We then also need to extract the ppc binaries out of the universal binaries, allowing us to actually link against them without worrying about universal binary support. Note that we don't want to hit the `ppc7400` binaries, since those are for 10.5 and the goal here is just for a Tiger focused SDK.

    cd $TARGET_PREFIX/$MAC_SDK_VERSION.sdk/usr/lib
    for i in **/*.dylib **/*.a **/*.o; do
      if file "$i" | grep -q "for architecture ppc)"; then
        mv $i $i.universal
        $TARGET_PREFIX/bin/$TARGET-lipo -thin ppc $i.universal -output $i
      elif file "$i" | grep -q "for architecture ppc7400)"; then
        mv $i $i.universal
        $TARGET_PREFIX/bin/$TARGET-lipo -thin ppc7400 $i.universal -output $i
      fi
    done
    cd -

## Building gcc

Some minor modifications to libgcc's dynamic library generation. Since it calls `lipo` to generate universal binaries, which our cctools-built linker doesn't support, I've created a simple patch to skip calling it when there's only one architecture.

    mkdir -p gcc
    cd gcc
    git init
    git remote add origin git@github.com:VariantXYZ/gcc-13-branch.git
    git fetch --depth 1 origin 908dbc96f1271f995759c87fc9d32879d6f49756
    git checkout FETCH_HEAD
    ./contrib/download_prerequisites
    cd -

### Just the compiler

Note we make some hard-coded configuration settings to avoid gcc making assumptions about as and ld features we don't have. This is also in that GitHub issue discussion linked above.

    mkdir -p $ROOT_DIR/build/target/gcc && \
    cd $ROOT_DIR/build/target/gcc && \
    echo "" > config.site-$TARGET && \
    echo "gcc_cv_as_mmacosx_version_min=no" >> config.site-$TARGET && \
    echo "gcc_cv_as_darwin_build_version=no" >> config.site-$TARGET && \
    echo "gcc_cv_ld64_demangle=0" >> config.site-$TARGET && \
    echo "gcc_cv_ld64_platform_version=0" >> config.site-$TARGET && \
    CONFIG_SITE=$ROOT_DIR/build/target/gcc/config.site-$TARGET $ROOT_DIR/gcc/configure CC=clang CXX=clang++ --disable-nls --disable-multilib --enable-languages=c,c++,lto --with-dwarf2 --prefix="$TARGET_PREFIX" --target=$TARGET --with-sysroot="$TARGET_PREFIX/$MAC_SDK_VERSION.sdk" CXXFLAGS_FOR_TARGET="-O2 -g -mmacosx-version-min=$MACOSX_PPC_DEPLOYMENT_TARGET" CFLAGS_FOR_TARGET="-O2 -g -mmacosx-version-min=$MACOSX_PPC_DEPLOYMENT_TARGET" LDFLAGS_FOR_TARGET="-O2 -g -mmacosx-version-min=$MACOSX_PPC_DEPLOYMENT_TARGET" --disable-bootstrap && \
    make all-gcc -j2 && \
    make install-gcc -j

Before we get back to gcc, we need to go rebuild crt1.o as mentioned above.

### Rebuilding Apple crt1.o

This one is a bit hacky compared to the rest, but we only need to rebuild one part of Apple's runtime libraries (crt1.o). This is only necessary if we're using the 10.4u SDK, at any rate.

    mkdir -p csu
    cd csu
    git init
    git remote add origin git@github.com:VariantXYZ/Csu.git
    git fetch --depth 1 origin 06967ab403a7a04e30e2f32479285d68152cedd2
    git checkout FETCH_HEAD
    cd -

(For the record, I just renamed files to let GCC handle assembly preprocessing, otherwise the cctools assembler has trouble)

    cd csu
    make CC=$TARGET_PREFIX/bin/powerpc-apple-darwin8-gcc ARCH_CFLAGS="-arch ppc -D__private_extern__= -isysroot $TARGET_PREFIX/$MAC_SDK_VERSION.sdk" ./crt1.v1.o
    mv ./crt1.v1.o $TARGET_PREFIX/$MAC_SDK_VERSION.sdk/usr/lib/crt1.o
    cd -

### The rest of the GCC runtime/libraries

    cd build/target/gcc
    make -j && \
    make install -j
    cd -

...and that's it, that's the toolchain. Well, the target toolchain anyway, we still need the GBDev one :^).

## Building rgbds for powerpc-apple-darwin8

`CFLAGS` and `CXXFLAGS` must include `-static-libstdc++` and `-static-libgcc` since we won't have dynamic libraries on the target, but other than that, it should be feasible to just reference `CC` and `CXX` to the powerpc toolchains. Note we're still operating in the same directory.

### libpng

We need libpng for rgbgfx, so we'll build it first and install it into our prefix.

    mkdir -p libpng
    cd libpng
    git init
    git remote add origin git@github.com:pnggroup/libpng.git
    git fetch --depth 1 origin f753baae52e1f0fd5451c25de8f8361ec5aea95f
    git checkout FETCH_HEAD
    cd -

    mkdir -p build/target/libpng
    cd build/target/libpng
    PATH=$TARGET_PREFIX/bin:$PATH LDFLAGS="-static-libstdc++ -static-libgcc" CXX=$TARGET_PREFIX/bin/$TARGET-g++ CC=$TARGET_PREFIX/bin/$TARGET-gcc $ROOT_DIR/libpng/configure --prefix=$TARGET_PREFIX/$TARGET --host=$TARGET
    PATH=$TARGET_PREFIX/bin:$PATH make -j
    PATH=$TARGET_PREFIX/bin:$PATH make install -j
    cd -

### rgbds

Working on tag v0.9.0 (a good way to test that C++20 works). PNG should be in our search path automatically, but we need to make sure it doesn't use the host-installed libpng.

    mkdir -p rgbds
    cd rgbds
    git init
    git remote add origin git@github.com:gbdev/rgbds.git
    git fetch --depth 1 origin d63955eccd7aa69794960a626144ea247d638957
    git checkout FETCH_HEAD
    
    mkdir -p $TARGET_PREFIX/$TARGET/deploy
    PATH=$TARGET_PREFIX/$TARGET/bin:$PATH make install -j LDFLAGS="-static-libstdc++ -static-libgcc" PNGCFLAGS="" PNGLDFLAGS="-lpng" PNGLDLIBS="" CXX=$TARGET_PREFIX/bin/$TARGET-g++ CC=$TARGET_PREFIX/bin/$TARGET-gcc CXXFLAGS="-D__STDC_FORMAT_MACROS" PREFIX=$TARGET_PREFIX/deploy

Note:
* We need to add `-D__STDC_FORMAT_MACROS` when using g++ in our case since `inttypes.h` will not enable certain macros otherwise (C99 locks it behind a macro, C++ doesn't seem to care)
* We specify the path to make sure `strip` is called such that the `install` utility can use it, instead of the system strip

Anyway, after all this, you can verify it with `file rgbasm`:

    % file rgbasm
    rgbasm: Mach-O executable ppc

Horray! We actually have to more thoroughly test it... but maybe that's a problem for another day.

