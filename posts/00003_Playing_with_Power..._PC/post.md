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

I bought a cheap 2004 iBook G4 for like 35$ and wanted to see if I could bring some life to it for something like no-distraction Gameboy development or just writing stuff. For how old it is, OS X 10.4.11 (Tiger) runs pretty well... but not well enough for me to try building complex things on it (a Gameboy toolchain is about it). So, I figured my project for the week would be to see what the state of cross-compiling a modern toolchain for a >20 year old system would look like.

Below, you'll find whatever shenanigans I had to do to get things working. If I'm able to find a cleaner way to do it, I'll update this post, but for now I think this may only be feasible on a Mac (I guess, since the new M4 Mac Mini exists, it might actually be a neat little remote compilation machine).

All that being said, there's a few points that irk me still, and I bring them up below, but it really just boils down to the fact that there are a handful of key components that are locked to just being old binaries...

Notes:

* `as`, `ld`, and `dsymutil` aren't buildable for powerpc-apple-darwin8 as far as I can tell, so I had to rely on old ones
	* Due to this, I don't know exactly how this could work in another OS, but apparently the [OSX Cross](https://github.com/tpoechtrager/osxcross/blob/ppc-test/README.PPC-GCC-5.5.0-SDK-10.5.md) project had something working for GCC 5.5 so maybe it's possible? I'll try asking
	* Also reference [this comment](https://github.com/Homebrew/homebrew-core/issues/29177#issuecomment-399011481) in homebrew
* I'm pretty pedantic about specific revisions to make sure my stuff is as reproduceable as can be, so I happen to do shallow clones to a specific commit often
* I've tested the steps below are all just run within a new empty directory, so keep that in mind wherever it matters

## References

[Bluzt3's Blog]: https://maniacsvault.net/articles/powerpccross
[OSDev Wiki]: https://wiki.osdev.org/GCC_Cross-Compiler

* [Bluzt3's Blog][]
* [OSDev Wiki][]

## Pre-requisites

* Tested on macOS 15.2 on a M1 Mac with clang 16
* Install texinfo `brew install texinfo`
(It may be possible some other build tools are needed, need to check on a clean machine)

## Host Toolchain

    export ROOT_DIR="$(pwd)"
    export HOST_PREFIX="$ROOT_DIR/install/host"
    mkdir -p "$HOST_PREFIX"


### gcc

    mkdir -p gcc
    cd gcc
    git init
    git remote add origin git@github.com:iains/gcc-13-branch.git 
    git fetch --depth 1 origin 7808d253bf53c6c6ce63f04a66601b595e2bae08
    git checkout FETCH_HEAD
    ./contrib/download_prerequisites
    cd -


    mkdir -p build/host/gcc
    cd build/host/gcc
    $ROOT_DIR/gcc/configure --prefix="$HOST_PREFIX" --disable-nls --disable-multilib --enable-languages=c,c++,lto --with-dwarf2 --with-sysroot=$(xcrun --show-sdk-path) && \
    make all-gcc -j && \
    make all-target-libgcc -j && \
    make all-target-libstdc++-v3 -j && \
    make install-gcc -j && \
    make install-target-libgcc -j && \
    make install-target-libstdc++-v3 -j
    cd -


### binutils

(Realistically, it's probably OK to skip this, you'd just end up using the system-installed binutils anyway, and you can't build as/ld at any rate)


    mkdir -p binutils
    cd binutils
    git init
    git remote add origin git@github.com:iains/binutils-gdb.git
    git fetch --depth 1 origin 2c96d55e5816d2e85bd1b0a7a64595a51465f22b
    git checkout FETCH_HEAD
    ln -s $ROOT_DIR/gcc/gmp gmp
    ln -s $ROOT_DIR/gcc/mpfr mpfr
    ln -s $ROOT_DIR/gcc/mpc mpc
    ln -s $ROOT_DIR/gcc/isl isl
    cd -


    mkdir -p build/host/binutils
    cd build/host/binutils
    CC=$HOST_PREFIX/bin/gcc CXX=$HOST_PREFIX/bin/g++ $ROOT_DIR/binutils/configure --prefix="$HOST_PREFIX" --disable-nls --disable-gdb && \
    make -j && \
    make install -j
    cd -


## Target Toolchain

    export TARGET_PREFIX="$(pwd)/install/target"
    export TARGET=powerpc-apple-darwin8
    export MACOSX_PPC_DEPLOYMENT_TARGET=10.4
    export MAC_SDK_VERSION=MacOSX10.4u
    mkdir -p "$TARGET_PREFIX"


**NOTE**: `MACOSX_DEPLOYMENT_TARGET` will affect the host toolchain too, so we need to make sure it's only set in the PPC target, so we only set `MACOSX_PPC_DEPLOYMENT_TARGET` here

### Get MacOS 10.4u SDK

    wget https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/$MAC_SDK_VERSION.sdk.tar.xz
    tar xf ./$MAC_SDK_VERSION.sdk.tar.xz -C $TARGET_PREFIX


**NOTE**: We explicitly copy it into the prefix so it should benefit from the `--with-sysroot` option, at least according to the GCC docs:


`If the specified directory is a subdirectory of ${exec_prefix}, then it will be found relative to the GCC binaries if the installation tree is moved.`


### Binutils

(Not strictly necessary, see below)

    mkdir -p build/target/binutils
    cd build/target/binutils
    CC=$HOST_PREFIX/bin/gcc CXX=$HOST_PREFIX/bin/g++ $ROOT_DIR/binutils/configure --prefix="$TARGET_PREFIX" --disable-nls C{,XX}FLAGS_FOR_TARGET="-isysroot $TARGET_PREFIX/$MAC_SDK_VERSION.sdk -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" LDFLAGS_FOR_TARGET="-isysroot $TARGET_PREFIX/$MAC_SDK_VERSION.sdk -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" --disable-gdb --disable-sim --target=$TARGET && \
    make -j && \
    make install -j
    cd -


### Mac OS X specific tools

**NOTE**: This is, as far as I can tell, the only part that locks us into building on a Mac. Theoretically a simple linker and Mach-O-compatible assembler shouldn't be too crazy for powerpc/darwin8 at this stage...? We could probably get away without dsymutil as well.

Reference [Bluzt3's Blog][] for this, we'll need to use [XcodeLegacy](https://github.com/devernay/xcodelegacy) to extract some tools.

You'll need the following (which you can get off the Apple developer site, or maybe archive or something):
* Xcode 6.4.dmg
* xcode_3.2.6_and_ios_sdk_4.3.dmg
* xcode_4.6.3.dmg

#### dsymutil

From the Xcode 6.4 dmg, dsymutil can be found in the mounted DMG at `Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/dsymutil`, copy and **rename** it into `$TARGET_PREFIX/$TARGET/bin/dsymutil-ppc`

#### as and ld

    mkdir -p xcodelegacy
    cd xcodelegacy
    git init
    git remote add origin git@github.com:devernay/xcodelegacy.git
    git fetch --depth 1 origin 14053d06ad2e12615a165345763285661d8cc7ca
    git checkout FETCH_HEAD
    cd -


Copy `xcode_3.2.6_and_ios_sdk_4.3.dmg` and `xcode_4.6.3.dmg` into `$ROOT_DIR/xcodelegacy`

    cd xcodelegacy
    ./XcodeLegacy.sh -osx104 -compilers buildpackages
    cp usr/bin/ld $TARGET_PREFIX/$TARGET/bin/ld-ppc
    cp usr/libexec/gcc/darwin/ppc/as $TARGET_PREFIX/$TARGET/bin/as
    cd -

We need to specifically wrap ld to control its executing environment. We don't want `MACOSX_DEPLOYMENT_TARGET` to be set to 10.4 in the host-side compilation (I guess it's for legacy reasons at this point, but controlling build flags via the environment like this instead of explicitly is just asking for trouble in my opinion)

Then create a file `$TARGET_PREFIX/$TARGET/bin/ld`:

    #!/bin/bash

    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    if [[ $MACOSX_PPC_DEPLOYMENT_TARGET ]]; then
        export MACOSX_DEPLOYMENT_TARGET=$MACOSX_PPC_DEPLOYMENT_TARGET
        exec $SCRIPT_DIR/ld-ppc "$@"
    else
        exec ld "$@"
    fi


Give it execute permissions with `chmod +x $TARGET_PREFIX/$TARGET/bin/ld`.

As mentioned in [Bluzt3's Blog][], you'll need to do something similar for `strip` by renaming it to `strip-ppc` and creating a new script `$TARGET_PREFIX/$TARGET/bin/strip` with the following content:


    #!/bin/bash

    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    export MACOSX_DEPLOYMENT_TARGET=$MACOSX_PPC_DEPLOYMENT_TARGET
    exec $SCRIPT_DIR/strip-ppc "$@"

and `chmod +x $TARGET_PREFIX/$TARGET/bin/strip`

Coincidentally, this is also an indication that you'll need to set `MACOSX_PPC_DEPLOYMENT_TARGET` on builds.

#### Things that should not be necessary but are (FIXME)

Honestly I wish we could use the things built within binutils, but something about the generated mach-o format of ar/ranlib from GCC breaks the libgcc build (it complains about libef_ppc.a not being the right architecture even though the objects inside are clearly Mach-o PPC). I'll need to dig into this more, I don't quite like not understanding why the regular binutils won't work (lipo aside).

May need to investigate old projects like [binutils-apple](https://github.com/kwhat/binutils-apple/blob/master/README).

I needed to do the following to get things to build (nm isn't necessary if you use binutils, at least):

    cd $TARGET_PREFIX/$TARGET/bin
    rm ar ranlib nm
    ln -s /usr/bin/ar ar
    ln -s /usr/bin/ranlib ranlib
    ln -s /usr/bin/lipo lipo
    ln -s /usr/bin/nm nm
    cd -

**NOTE**: You'll need to re-link when moving the toolchain directory, `ar` doesn't like being executed outside of `/usr/bin`, so a copy won't suffice.

### gcc

    mkdir -p build/target/gcc
    cd build/target/gcc
    CC=$HOST_PREFIX/bin/gcc CXX=$HOST_PREFIX/bin/g++ DSYMUTIL_FOR_TARGET=$TARGET_PREFIX/$TARGET/bin/dsymutil-ppc AS_FOR_TARGET=$TARGET_PREFIX/$TARGET/bin/as LD_FOR_TARGET=$TARGET_PREFIX/$TARGET/bin/ld $ROOT_DIR/gcc/configure --disable-nls --disable-multilib --enable-languages=c,c++,lto --with-dwarf2 --prefix="$TARGET_PREFIX" --disable-nls --with-dsymutil="$TARGET_PREFIX/$TARGET/bin/dsymutil-ppc" C{,XX}FLAGS_FOR_TARGET="-mmacosx-version-min=$MACOSX_PPC_DEPLOYMENT_TARGET" LDFLAGS_FOR_TARGET="-mmacosx-version-min=$MACOSX_PPC_DEPLOYMENT_TARGET" --target=$TARGET --with-sysroot=$TARGET_PREFIX/$MAC_SDK_VERSION.sdk --disable-bootstrap && \
    make -j && \
    make install -j
    cd -


## Building rgbds for powerpc-apple-darwin8

`CFLAGS` and `CXXFLAGS` must include `-static-libstdc++` and `-staic-libgcc`, but other than that, it should be feasible to just reference `CC` and `CXX` to the powerpc toolchains. Note we're still operating in the same directory.

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
    LDFLAGS="-static-libstdc++ -static-libgcc" CXX=$TARGET_PREFIX/bin/$TARGET-g++ CC=$TARGET_PREFIX/bin/$TARGET-gcc MACOSX_PPC_DEPLOYMENT_TARGET=10.4 $ROOT_DIR/libpng/configure --prefix=$TARGET_PREFIX/$TARGET --host=$TARGET
    make -j
    make install -j
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
    PATH=$TARGET_PREFIX/$TARGET/bin:$PATH MACOSX_PPC_DEPLOYMENT_TARGET=10.4 make install -j LDFLAGS="-static-libstdc++ -static-libgcc" PNGCFLAGS="" PNGLDFLAGS="-lpng" PNGLDLIBS="" CXX=$TARGET_PREFIX/bin/$TARGET-g++ CC=$TARGET_PREFIX/bin/$TARGET-gcc CXXFLAGS="-D__STDC_FORMAT_MACROS" PREFIX=$TARGET_PREFIX/deploy

Note:
* We need to add `-D__STDC_FORMAT_MACROS` when using g++ in our case since `inttypes.h` will not enable certain macros otherwise (C99 locks it behind a macro, C++ doesn't seem to care)
* We specify the path to make sure `strip` is called such that the `install` utility can use it, instead of the system strip

Anyway, after all this, you can verify it with `file rgbasm`:


    % file rgbasm
    rgbasm: Mach-O executable ppc

Horray! We actually have to more thoroughly test it... but maybe that's a problem for another day.

