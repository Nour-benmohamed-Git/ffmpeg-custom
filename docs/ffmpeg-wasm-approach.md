# FFmpeg WebAssembly — Baseline‑First, Incremental Capability Strategy

## Principles

- Keep the setup simple: build a working FFmpeg wasm core without external libraries, validate common tasks, then expand.
- Add external libraries only when a specific service demands them, preserving commercial‑safe licensing (LGPL/BSD/Apache).
- Maintain two build artifacts: multithreaded performance (requires COOP/COEP) and single‑thread fallback (JSPI for OPFS when needed).

## Baseline (Phase 1)

- Environment: use Docker Desktop with a named volume or bind mount, start `emscripten/emsdk:3.1.x`.
- Install minimal tools (`build-essential`, `pkg-config`, `cmake`, `ninja`, `autoconf`, `automake`, `libtool`, `meson`, `nasm`).
- Configure FFmpeg for wasm (disable docs/programs/network, enable Pthreads flags and SIMD).
- Link wasm artifacts:
  - Performance (MT): `-s USE_PTHREADS=1 -s PROXY_TO_PTHREAD=1 -msimd128 -s WASMFS=1 -s MALLOC=emmalloc -s INITIAL_MEMORY=268435456 -s STACK_SIZE=8388608`.
  - Fallback (ST+JSPI): `-s ASYNCIFY=2 -s WASMFS=1 -msimd128 -s INITIAL_MEMORY=268435456 -s ALLOW_MEMORY_GROWTH=1`.
- Storage: mount OPFS when available; fallback to IDBFS/MEMFS; use WORKERFS for user inputs.
- Validate with simple `callMain` commands (`-version`, `-hide_banner`, small transcode/remux).

## Incremental Add‑Ons (Phase 2)

- Use a single staging prefix: `export PREFIX=/opt/ffmpeg`.
- Build each external library statically into `$PREFIX` (headers and `.a` files), with asm disabled when necessary.
- Reconfigure FFmpeg with `--extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib"` and `--enable-<libname>` flags; rebuild and re‑link.

### Decision Tree: When to Add Which Library

- MP3 encode needed → `libmp3lame` (LGPL).
- Vorbis encode needed → `libvorbis` + `libogg` (BSD).
- Opus encode/decode needed → `libopus` (BSD).
- VP8/VP9 encode needed → `libvpx` (BSD).
- AV1 decode speed needed → `libdav1d` (BSD).
- Subtitles burn‑in needed → `libass` (ISC) + `freetype`.
- High‑quality resampling → `libsoxr` (LGPL).
- Avoid GPL/non‑free (`x264`, `x265`, `libfdk_aac`).

## Runtime Selection

- Detect isolation and select build:

```js
const isIsolated = self.crossOriginIsolated === true;
const factory = isIsolated ? createFFmpeg : createFFmpegSTJSPI;
const Module = await factory();
```

- Mount preferred storage:

```js
try { FS.mkdir('/opfs'); FS.mount(OPFS, {}, '/opfs'); }
catch { FS.mkdir('/idb'); FS.mount(IDBFS, {}, '/idb'); await new Promise(r => FS.syncfs(true, r)); }
```

## Verification

- Confirm enabled components: `-codecs`, `-encoders`, `-decoders`, and `-h encoder=<name>`.
- Run small conversions using newly added encoders/decoders.

## Licensing & Safety

- Build under LGPL; do not enable `--enable-gpl` or `--enable-nonfree`.
- Favor BSD/LGPL libraries; note patent considerations (e.g., H.264/H.265 encode).

## Maintenance Tips

- Cache builds in the Docker volume; reattach across sessions.
- Keep configure/link flags consistent; avoid `pkg-config` where unreliable; prefer explicit `-I/-L`.
- Size memory based on workloads; keep SIMD enabled.