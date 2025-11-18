# FFmpeg WebAssembly (LGPL) — Build and Runtime Plan

## Overview

Commercial‑safe FFmpeg WebAssembly build focused on audio/video processing in the browser. Enables multithreading, SIMD, and high‑performance storage via OPFS, with fallbacks to MEMFS/IDBFS/WORKERFS. Ships two builds: multithreaded (MT) requiring cross‑origin isolation, and single‑thread (ST) fallback.

## Quick Start (Simplest Path)

- Start container (bind mount your folder):

```powershell
docker run --rm -it -v "C:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/src" -w /src emscripten/emsdk:3.1.x bash
```

- Install tools:

```sh
apt-get update && apt-get install -y build-essential python3 pkg-config cmake ninja-build autoconf automake libtool git curl wget nasm
```

- Configure and build FFmpeg (no external libs):

```sh
CFLAGS="-O3 -msimd128 -s USE_PTHREADS=1"
LDFLAGS="$CFLAGS -s INITIAL_MEMORY=268435456"
emconfigure ./configure \
  --target-os=none --arch=x86_32 --enable-cross-compile \
  --disable-x86asm --disable-inline-asm --disable-doc --disable-programs --disable-network \
  --nm=llvm-nm --ar=emar --ranlib=emranlib \
  --cc=emcc --cxx=em++ --objcc=emcc --dep-cc=emcc \
  --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
emmake make -j$(nproc)
```

- Link to wasm (MT build):

```sh
emcc -O3 -msimd128 -pthread \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s USE_PTHREADS=1 -s PROXY_TO_PTHREAD=1 -s PTHREAD_POOL_SIZE=navigator.hardwareConcurrency \
  -s FORCE_FILESYSTEM=1 \
  -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" -s EXPORTED_RUNTIME_METHODS="[FS,callMain]" \
  -s INITIAL_MEMORY=268435456 -s ALLOW_MEMORY_GROWTH=1 \
  -o dist/ffmpeg-core.js
```

- Optional: ST fallback (no threads):

```sh
emcc -O3 -msimd128 \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s FORCE_FILESYSTEM=1 -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" -s EXPORTED_RUNTIME_METHODS="[FS,callMain]" \
  -s INITIAL_MEMORY=268435456 -s ALLOW_MEMORY_GROWTH=1 \
  -o dist/ffmpeg-core-st.js
```

- Browser usage:

```js
const Module = await createFFmpeg();
Module.FS.mkdir("/input");
Module.FS.writeFile("/input/in.mp4", data);
Module.callMain([
  "-i",
  "/input/in.mp4",
  "-vf",
  "scale=1280:-1",
  "/input/out.mp4",
]);
const out = Module.FS.readFile("/input/out.mp4");
```

## Recommended Build Variants (Add‑On Flags)

### Performance Build (Multithreaded)

```sh
emcc -O3 -msimd128 -pthread \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s USE_PTHREADS=1 -s PROXY_TO_PTHREAD=1 \
  -s PTHREAD_POOL_SIZE=navigator.hardwareConcurrency \
  -s WASMFS=1 -s FORCE_FILESYSTEM=1 \
  -s MALLOC=emmalloc \
  -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" \
  -s EXPORTED_RUNTIME_METHODS="[FS,callMain,WORKERFS]" \
  -s INITIAL_MEMORY=268435456 \
  -s STACK_SIZE=8388608 \
  -o dist/ffmpeg-core.js
```

### Fallback Build (Single‑Thread + JSPI)

```sh
emcc -O3 -msimd128 \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s WASMFS=1 -s FORCE_FILESYSTEM=1 \
  -s ASYNCIFY=2 \
  -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" \
  -s EXPORTED_RUNTIME_METHODS="[FS,callMain,WORKERFS]" \
  -s INITIAL_MEMORY=268435456 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -o dist/ffmpeg-core-st-jspi.js
```

### Mount OPFS (WasmFS)

```js
FS.mkdir("/opfs");
FS.mount(OPFS, {}, "/opfs");
```

### Mount Alternatives (Fallbacks)

IDBFS (persistent across reloads):

```js
FS.mkdir("/idb");
FS.mount(IDBFS, {}, "/idb");
await new Promise((r) => FS.syncfs(true, r));
```

WORKERFS (user file inputs):

```js
FS.mkdir("/input");
FS.mount(WORKERFS, { files }, "/input");
```

Use MEMFS for temp (`/tmp`). Choose `/opfs` when available, otherwise `/idb` or `/tmp`.

## Runtime Build Selection

Auto‑select artifact based on isolation:

```js
const isIsolated = self.crossOriginIsolated === true;
const factory = isIsolated
  ? createFFmpeg /* MT */
  : createFFmpegSTJSPI; /* ST+JSPI */
const Module = await factory();
```

Then mount storage:

```js
try {
  FS.mkdir("/opfs");
  FS.mount(OPFS, {}, "/opfs");
} catch (e) {
  FS.mkdir("/idb");
  FS.mount(IDBFS, {}, "/idb");
  await new Promise((r) => FS.syncfs(true, r));
}
```

## Required Headers (MT Build)

Serve with:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## Sanity Test

Run a minimal command:

```js
Module.callMain(["-hide_banner"]);
// or
Module.callMain(["-version"]);
```

## Licensing & Compliance

- Compile under LGPL: do not pass `--enable-gpl` or `--enable-nonfree`.
- Avoid GPL/non‑free components (e.g., `x264`, `x265`, `libfdk_aac`).
- If you later include LGPL external libraries (e.g., `libmp3lame`), follow FFmpeg LGPL checklist.
- References: FFmpeg legal/licensing — https://www.ffmpeg.org/legal.html ; External libs notes — https://www.ffmpeg.org/general.html

## Build Environment

- Emscripten ≥ 3.1.x with Pthreads and WasmFS available.
- HTTPS hosting; correct MIME types for `.wasm` and JS.
- Cross‑origin isolation headers (for `SharedArrayBuffer`):
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`
- Prefer running in a Worker; main runs on a pthread (`PROXY_TO_PTHREAD`).

## Configure FFmpeg for WebAssembly

Use `emconfigure` to cross‑compile FFmpeg for wasm, disabling OS‑specific features, programs, docs, and network.

```sh
CFLAGS="-O3 -msimd128 -s USE_PTHREADS=1"
LDFLAGS="$CFLAGS -s INITIAL_MEMORY=268435456"

emconfigure ./configure \
  --target-os=none \
  --arch=x86_32 \
  --enable-cross-compile \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-stripping \
  --disable-doc \
  --disable-programs \
  --disable-network \
  --disable-debug \
  --disable-autodetect \
  --nm=llvm-nm --ar=emar --ranlib=emranlib \
  --cc=emcc --cxx=em++ --objcc=emcc --dep-cc=emcc \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS"
```

Then build libraries:

```sh
emmake make -j$(nproc)
```

## Link FFmpeg CLI to Wasm

Link `fftools` sources with required libs into a modularized wasm artifact. Export main and runtime FS helpers.

```sh
emcc -O3 -msimd128 -pthread \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s USE_PTHREADS=1 -s PROXY_TO_PTHREAD=1 -s PTHREAD_POOL_SIZE=navigator.hardwareConcurrency \
  -s WASMFS=1 -s FORCE_FILESYSTEM=1 \
  -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" \
  -s EXPORTED_RUNTIME_METHODS="[FS,callMain,WORKERFS]" \
  -s INITIAL_MEMORY=268435456 -s ALLOW_MEMORY_GROWTH=1 \
  -o dist/ffmpeg-core.js
```

Single‑thread fallback (for non‑isolated origins):

```sh
emcc -O3 -msimd128 \
  -I. -I./fftools \
  -Llibavcodec -Llibavformat -Llibavfilter -Llibswresample -Llibswscale -Llibavutil \
  fftools/cmdutils.c fftools/ffmpeg.c fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -s FORCE_FILESYSTEM=1 \
  -s MODULARIZE=1 -s EXPORT_NAME="createFFmpeg" \
  -s EXPORTED_FUNCTIONS="[_main]" \
  -s EXPORTED_RUNTIME_METHODS="[FS,callMain,WORKERFS]" \
  -s INITIAL_MEMORY=268435456 -s ALLOW_MEMORY_GROWTH=1 \
  -o dist/ffmpeg-core-st.js
```

## Storage Backends and Mounts

### OPFS (Origin Private File System)

- Preferred persistent storage for high throughput in Workers.
- Requires threads (`-pthread`, `-s USE_PTHREADS=1`, `-s PROXY_TO_PTHREAD=1`) or JSPI.
- With WasmFS enabled (`-s WASMFS=1`), mount OPFS:

```js
FS.mkdir("/opfs");
FS.mount(OPFS, {}, "/opfs");
// Read/write under '/opfs' for persistent files.
```

### IDBFS (IndexedDB)

- Persistent fallback available broadly.

```js
FS.mkdir("/idb");
FS.mount(IDBFS, {}, "/idb");
await new Promise((r) => FS.syncfs(true, r));
```

### WORKERFS

- Mount user `File`/`Blob` inputs from JS.

```js
FS.mkdir("/input");
FS.mount(WORKERFS, { files }, "/input");
```

### MEMFS

- Default in‑memory; best for temporary scratch paths (`/tmp`).

## Runtime Wrapper API

Expose a thin JS/TS wrapper around the modularized module:

- `initFFmpeg({ storage: 'opfs'|'idbfs'|'workerfs'|'memfs' })`: instantiate, mount storage.
- `run(args: string[])`: invoke `Module.callMain(args)`.
- `writeFile(path, Uint8Array)`, `readFile(path)`: helper I/O.
- Detect `crossOriginIsolated` to select MT vs ST artifact.

## Compatibility Strategy

- MT build for best performance on cross‑origin‑isolated pages.
- ST build fallback when isolation/threads are unavailable.
- Feature‑detect OPFS; fall back to IDBFS/MEMFS.

## Performance Tuning

- Wasm SIMD: compile with `-msimd128`.
- `-O3`, `-s MALLOC=emmalloc`.
- Size `INITIAL_MEMORY` to workload (typ. 256–512 MB).
- Use `PTHREAD_POOL_SIZE` to pre‑spawn workers (`navigator.hardwareConcurrency`).

## Notes

- Consider hybrid with WebCodecs: use hardware encode/decode where available; use FFmpeg for mux/demux/filters.
- OPFS SyncAccessHandle is Worker‑only; ensure operations run off UI thread.

## References

- FFmpeg legal/licensing: https://www.ffmpeg.org/legal.html
- FFmpeg external libs: https://www.ffmpeg.org/general.html
- Emscripten Pthreads & COOP/COEP: https://emscripten.org/docs/porting/pthreads.html
- Emscripten Filesystem/WasmFS: https://emscripten.org/docs/api_reference/Filesystem-API.html
- OPFS/AccessHandle intent: https://groups.google.com/a/chromium.org/g/blink-dev/c/OR0poFdzEpo
- FFmpeg wasm build walkthrough: https://jeromewu.github.io/build-ffmpeg-webassembly-version-part-3-v0.1/
