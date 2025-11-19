**Host Prerequisites**
- Windows 10/11 with Docker Desktop (WSL 2 backend, Linux containers).

**Images**
- Pull toolchain: `docker pull emscripten/emsdk:latest`
- Pull helper: `docker pull busybox:latest`

**Named Volume Build (Docker Desktop)**
- Create volume: `docker volume create ffmpeg-custom`
- Choose script: use `build_mt.sh` (multithread) or `build_st.sh` (single-thread) from project root.
- Copy selected into volume as `build.sh`:
  - MT: `docker run --rm -v ffmpeg-custom:/src -v "c:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/host" busybox sh -lc "cp /host/build_mt.sh /src/build.sh"`
  - ST: `docker run --rm -v ffmpeg-custom:/src -v "c:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/host" busybox sh -lc "cp /host/build_st.sh /src/build.sh"`
- Build inside volume:
  - `docker run --rm -it -v ffmpeg-custom:/src -w /src emscripten/emsdk:latest bash -lc "git clone --depth 1 https://github.com/FFmpeg/FFmpeg.git ffmpeg && cd ffmpeg && chmod +x /src/build.sh && bash -x /src/build.sh"`
- Export artifacts to host:
  - `docker run --rm -v ffmpeg-custom:/src -v "c:\Users\nour-\OneDrive\Desktop\ffmpeg-custom:/host" busybox sh -lc "mkdir -p /host/dist && cp -r /src/ffmpeg/dist/* /host/dist/"`

**Toolchain Note**
- The `emscripten/emsdk:latest` image includes `python3`, Node.js, CMake, LLVM toolchain (`emcc`, `em++`, `wasm-ld`, `emar`, `llvm-nm`), `make`, and `bash`. For our current build (no external libraries enabled), those are sufficient.
- If you later enable external libraries, install build extras:
  - `apt-get update && apt-get install -y pkg-config autoconf automake libtool yasm ragel`
  - Build and link the desired libraries, then enable with FFmpeg flags (e.g., `--enable-libvpx`, `--enable-libaom`, `--enable-libopus`).