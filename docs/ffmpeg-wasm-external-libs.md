# FFmpeg WebAssembly — External Libraries and Browser Requirements

## Purpose

Curated list of external libraries to enable top audio/video services in a commercial‑safe (LGPL) FFmpeg WebAssembly build, plus browser/runtime requirements for reliable operation.

## Start Simple (Avoid Complications)

- Phase 1: build FFmpeg without external libraries; validate basic transcode/remux and filters.
- Phase 2: add select libraries one by one (`libmp3lame`, `libvorbis`, `libopus`) only if required by your services.
- Keep flags consistent: static libs, asm disabled, install to a single `PREFIX`, and pass `--extra-cflags/-ldflags` to FFmpeg.

## External Libraries (Licenses and Feasibility)

### Video Codecs

- `libvpx` (VP8/VP9, BSD): encode/decode; feasible in wasm; good for WebM workflows.
- `libaom` (AV1, BSD): encode/decode; very heavy in wasm; prefer decode‑only or `libdav1d`.
- `libdav1d` (AV1 decoder, BSD): fast decoder; recommended for AV1 decode.
- `libtheora` (Ogg Theora, BSD): legacy; optional.
- OpenH264 (BSD): H.264 encode; consider patent landscape; prefer WebCodecs for encode in browser.

### Audio Codecs

- `libopus` (BSD): Opus encode/decode; assembly‑heavy—build without asm; practical in wasm.
- `libvorbis` + `libogg` (BSD): Vorbis encode/decode; safe and practical.
- `libmp3lame` (LGPL): MP3 encoder; acceptable under LGPL; patents expired globally.
- `TwoLAME` (LGPL): MP2 encoder; optional.
- Avoid `libfdk-aac` (non‑free): disallowed in commercial‑safe builds.

### Processing / Subtitles / Images

- `libsoxr` (LGPL): high‑quality resampler (optional enhancement over `swresample`).
- `libass` (ISC): subtitle rendering (ASS/SSA); optional.
- `freetype` (FreeType License): font rendering for subtitles; optional.
- `libpng` (zlib), `libjpeg-turbo` (BSD): image I/O for overlays/thumbnails; optional.

### Containers / Muxers

- FFmpeg core covers `mp4`, `matroska/webm`, `ogg`, `wav`, `mp3`; no external libs required for these.

## Recommended Feature Set for Top Services (Browser)

- Transcode/remux: MP4 (H.264/AAC), WebM (VP8/VP9/Opus), OGG (Vorbis), WAV/MP3.
- Filters: `scale`, `fps`, `trim/concat`, `overlay`, `volume`, `aresample`.
- Thumbnails/sprites: decode + image output via `libpng`/`libjpeg-turbo` or browser canvas.
- Subtitles burn‑in: `libass` + `freetype` (optional).
- High‑quality resampling: `libsoxr` (optional).
- Performance hybrid: Use WebCodecs for encode/decode when available; use FFmpeg for mux/demux/filters.

## Browser/Runtime Requirements

- Cross‑origin isolation (for `SharedArrayBuffer` and threads):
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`
- HTTPS hosting; correct MIME types for `.wasm` and JS.
- OPFS availability:
  - Chrome/Edge: OPFS with SyncAccessHandle in Workers; high performance.
  - Safari: OPFS supported in recent versions; verify version and limitations.
  - Firefox: OPFS support improving; provide IDBFS fallback.
- Pthreads build flags: `-pthread`, `-s USE_PTHREADS=1`, `-s PROXY_TO_PTHREAD=1`, `-s PTHREAD_POOL_SIZE=navigator.hardwareConcurrency`.
- WasmFS with OPFS: `-s WASMFS=1`; mount OPFS at `/opfs`.
- Memory tuning: `-s INITIAL_MEMORY=256mb` (or larger per workload), `-s ALLOW_MEMORY_GROWTH=1` (especially for ST builds).
- SIMD: compile with `-msimd128` for faster filters/resampling.
- Fallback strategy: detect `crossOriginIsolated` and OPFS support; fall back to ST build and `IDBFS/MEMFS` as needed.

## Inclusion Flags (Examples)

- `--enable-libvpx` (BSD)
- `--enable-libaom` (BSD) [decode preferred]
- `--enable-libdav1d` (BSD)
- `--enable-libopus` (BSD)
- `--enable-libvorbis` (BSD) and `--enable-libogg`
- `--enable-libmp3lame` (LGPL)
- `--enable-libsoxr` (LGPL)
- `--enable-libass` (ISC) and `--enable-libfreetype`
- Avoid `--enable-gpl`, `--enable-nonfree`

## Licensing and Patents Notes

- Build under LGPL; avoid GPL/non‑free components.
- Patents: open‑source licenses differ from patent rights.
  - MP3: patents expired; OK for commercial use.
  - H.264/H.265: patents apply; prefer decode‑only via FFmpeg and encode via WebCodecs/hardware paths.

## References

- FFmpeg legal/licensing: https://www.ffmpeg.org/legal.html
- FFmpeg external libs/licensing: https://www.ffmpeg.org/general.html
- Emscripten Pthreads & COOP/COEP: https://emscripten.org/docs/porting/pthreads.html
- Emscripten Filesystem/WasmFS: https://emscripten.org/docs/api_reference/Filesystem-API.html
- OPFS/AccessHandle intent: https://groups.google.com/a/chromium.org/g/blink-dev/c/OR0poFdzEpo