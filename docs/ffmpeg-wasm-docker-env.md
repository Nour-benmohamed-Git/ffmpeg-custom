# FFmpeg WebAssembly — Docker Desktop Environment Requirements

## Goal

Define a reliable Docker‑based build environment (with a mounted volume) to compile FFmpeg and external libraries to WebAssembly using Emscripten, minimizing setup errors and ensuring reproducible builds.

## Quick Start

1) Start container with your folder mounted:

```powershell
docker run --rm -it -v "C:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/src" -w /src emscripten/emsdk:3.1.x bash
```

2) Install tools in the container:

```sh
apt-get update && apt-get install -y build-essential python3 pkg-config cmake ninja-build autoconf automake libtool git curl wget meson nasm
```

From here, follow the build doc’s minimal FFmpeg configure + link steps. Outputs written under `/src/dist` persist to your host.

## Host Prerequisites

- Docker Desktop with WSL 2 backend enabled.
- File sharing permission for the project directory (`ffmpeg-custom`).
- Allocate sufficient Docker resources (CPU threads and memory) for heavy builds (recommend 4+ CPUs, 8–16 GB RAM).
- Stable internet for fetching sources; corporate proxies should be configured in Docker.

## Recommended Base Image

- Use official Emscripten image: `emscripten/emsdk:<version>` (pin a recent version compatible with WasmFS and Pthreads, e.g., `3.1.x`).
- Advantages: preinstalled `emcc`, `em++`, `emconfigure`, `emmake`, `emar`, `emranlib` and correct sysroot.

## Project Volume Mapping (Docker Desktop on Windows)

- PowerShell example:

```powershell
docker run --rm -it -v "${PWD}:/src" -w /src emscripten/emsdk:3.1.x bash
```

- If using Git Bash/MSYS, path may need `//c/Users/...:/src` style.
- Ensure `OneDrive` paths are shared and not blocked.

## Essential Build Tools Inside Container

Install the following to support autotools, cmake/meson, and general builds of external libraries:

```sh
apt-get update && apt-get install -y \
  build-essential python3 python3-pip \
  pkg-config cmake ninja-build \
  autoconf automake libtool \
  git curl wget \
  meson nasm
```

Notes:

- Some libraries require `autoreconf` (`autoconf/automake/libtool`).
- `meson` + `ninja` used by projects like `libdav1d`.
- `nasm` present even if you disable asm usage; certain configure steps check for it.

## Emscripten Environment

- Verify toolchain:

```sh
emcc -v
echo $EMSDK
```

- Use `emconfigure` and `emmake` for external libraries and FFmpeg.
- Use `emar`/`emranlib` for static libraries.

## Staging Prefixes and Paths

- Create a staging prefix to install headers and static libs:

```sh
export PREFIX=/opt/ffmpeg
mkdir -p $PREFIX/{lib,include}
```

- When building libraries, pass `--prefix="$PREFIX"` and `--enable-static --disable-shared`.
- At FFmpeg link time, use `--extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib"`.
- `PKG_CONFIG_PATH` often unused in Emscripten builds; prefer explicit include/lib flags.

## External Libraries: Common Configure Patterns

General rules for wasm builds:

- Disable assembler optimizations and CLI tools.
- Enable static library outputs.
- Use `emconfigure ./configure` or project‑specific build systems.

Examples (adapt flags per project):

### libvpx (VP8/VP9, BSD)

```sh
./configure \
  --prefix="$PREFIX" \
  --target=wasm32-emscripten \
  --disable-examples --disable-tools --disable-docs \
  --enable-static --disable-shared \
  --disable-runtime-cpu-detect --disable-asm
make -j$(nproc) && make install
```

### libaom (AV1, BSD)

```sh
cmake -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release -DENABLE_TESTS=0 -DENABLE_TOOLS=0 \
  -DCMAKE_INSTALL_PREFIX=$PREFIX -DBUILD_SHARED_LIBS=OFF
ninja -C build && ninja -C build install
```

### libdav1d (AV1 decoder, BSD)

```sh
meson setup build --cross-file $EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  --buildtype=release --default-library=static --prefix=$PREFIX
ninja -C build && ninja -C build install
```

### libopus (BSD)

```sh
emconfigure ./configure \
  --prefix="$PREFIX" --enable-static --disable-shared \
  --disable-asm --disable-doc --disable-examples
emmake make -j$(nproc) && emmake make install
```

### libvorbis + libogg (BSD)

```sh
emconfigure ./configure --prefix="$PREFIX" --enable-static --disable-shared
emmake make -j$(nproc) && emmake make install

cd ../libvorbis
emconfigure ./configure --prefix="$PREFIX" --enable-static --disable-shared
emmake make -j$(nproc) && emmake make install
```

### libmp3lame (LGPL)

```sh
emconfigure ./configure \
  --prefix="$PREFIX" --enable-static --disable-shared \
  --disable-frontend --disable-asm
emmake make -j$(nproc) && emmake make install
```

### libsoxr (LGPL)

```sh
cmake -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DBUILD_SHARED_LIBS=OFF
ninja -C build && ninja -C build install
```

### libass (ISC) + freetype (FreeType) + libpng/libjpeg-turbo

```sh
# freetype
emconfigure ./configure --prefix="$PREFIX" --enable-static --disable-shared
emmake make -j$(nproc) && emmake make install

# libass
emconfigure ./configure --prefix="$PREFIX" --enable-static --disable-shared
emmake make -j$(nproc) && emmake make install

# libpng
emconfigure ./configure --prefix="$PREFIX" --enable-static --disable-shared
emmake make -j$(nproc) && emmake make install

# libjpeg-turbo
cmake -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX -DBUILD_SHARED_LIBS=OFF
ninja -C build && ninja -C build install
```

## FFmpeg Build Prerequisites and Configure

Export flags and configure FFmpeg to find staged libraries:

```sh
export CFLAGS="-O3 -msimd128 -s USE_PTHREADS=1"
export LDFLAGS="$CFLAGS -s INITIAL_MEMORY=268435456"

emconfigure ./configure \
  --target-os=none --arch=x86_32 --enable-cross-compile \
  --disable-x86asm --disable-inline-asm --disable-stripping \
  --disable-doc --disable-programs --disable-network --disable-debug \
  --disable-autodetect \
  --extra-cflags="-I$PREFIX/include $CFLAGS" \
  --extra-ldflags="-L$PREFIX/lib $LDFLAGS" \
  --nm=llvm-nm --ar=emar --ranlib=emranlib \
  --cc=emcc --cxx=em++ --objcc=emcc --dep-cc=emcc \
  --enable-libvpx --enable-libopus --enable-libvorbis --enable-libmp3lame \
  --enable-libsoxr --enable-libass --enable-libfreetype \
  --enable-libdav1d

emmake make -j$(nproc)
```

Link CLI to Wasm as described in the build plan.

## Common Failure Modes and Fixes

- Duplicate symbols from runtime libs: avoid linking `-lhtml5` twice; keep link flags minimal.
- Pthreads errors: ensure `-pthread` is passed on both compile and link steps; use `-s USE_PTHREADS=1` and `-s PROXY_TO_PTHREAD=1`.
- Initial memory too small: increase `-s INITIAL_MEMORY` (e.g., 256–512 MB).
- ASM/CPU detection breaks build: pass `--disable-asm` and `--disable-runtime-cpu-detect` to external libs.
- Shared libs not supported: build static (`--enable-static --disable-shared`).
- `pkg-config` mismatches: prefer explicit `-I$PREFIX/include` and `-L$PREFIX/lib`.
- Meson cross issues: use Emscripten toolchain or cross files; build static.

## Runtime Server Headers (for testing in Docker)

To run the MT build in a browser, serve with COOP/COEP headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Example Node.js (Express) snippet:

```js
app.use((req, res, next) => {
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
  res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
  next();
});
```

## Validation Checklist

- Emscripten version prints correctly; `emcc` available.
- Tooling installed: `autoconf/automake/libtool`, `cmake/ninja`, `meson`, `pkg-config`, `nasm`.
- External libs installed to `$PREFIX` (headers and `.a` files).
- FFmpeg `configure` finds libs via `--extra-cflags/--extra-ldflags`.
- Multithreaded link artifacts generated with expected exports.

## References

- FFmpeg legal/licensing: https://www.ffmpeg.org/legal.html
- FFmpeg external libs/licensing: https://www.ffmpeg.org/general.html
- Emscripten Pthreads & COOP/COEP: https://emscripten.org/docs/porting/pthreads.html
- Emscripten Filesystem/WasmFS: https://emscripten.org/docs/api_reference/Filesystem-API.html

## Direct Docker Desktop Usage (No Dockerfile/Compose)

### Option A: Bind‑mount the host folder

Use your local `ffmpeg-custom` folder directly via bind mount.

```powershell
docker run --rm -it -v "C:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/src" -w /src emscripten/emsdk:3.1.x bash
```

Inside the container:

```sh
apt-get update && apt-get install -y build-essential python3 python3-pip pkg-config cmake ninja-build autoconf automake libtool git curl wget meson nasm
export PREFIX=/opt/ffmpeg
mkdir -p $PREFIX/{lib,include}
# build external libs here
# configure and build FFmpeg here
# link wasm artifacts to /src/dist so they persist on host
```

Notes:

- Ensure Docker Desktop file sharing allows access to the OneDrive path.
- Use double quotes around Windows paths; escape backslashes when needed.
- All generated files under `/src` are visible on the host.

### Option B: Named volume `ffmpeg-custom`

Create and use a Docker named volume for persistent workspace.

```powershell
docker volume create ffmpeg-custom
docker run --rm -it -v ffmpeg-custom:/src -w /src emscripten/emsdk:3.1.x bash
```

Populate the volume from your host folder (one‑time copy):

```powershell
docker run --rm -v ffmpeg-custom:/dst -v "C:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/src" alpine sh -c "cp -r /src/* /dst/"
```

Build inside the Emscripten container as above. Artifacts under `/src` remain in the named volume and can be reattached in future sessions.

### Quick Session Commands

- Start container: bind mount or named volume as above.
- Install tools: `apt-get` command shown earlier.
- Build libraries: follow per‑library sections.
- Build FFmpeg: use `emconfigure`/`emmake` and link commands.
- Exit: `exit` (container stops; data persists in bind mount or named volume).
