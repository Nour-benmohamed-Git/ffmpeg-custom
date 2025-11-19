```bash
#!/usr/bin/env bash
set -euo pipefail

CFLAGS="-O3 -s WASM_BIGINT=1"
LDFLAGS="$CFLAGS -s INITIAL_MEMORY=134217728 -s ALLOW_MEMORY_GROWTH=1"

emcc -v

emconfigure ./configure \
  --target-os=none \
  --arch=x86_32 \
  --enable-cross-compile \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-stripping \
  --disable-programs \
  --disable-doc \
  --disable-debug \
  --disable-network \
  --disable-autodetect \
  --disable-runtime-cpudetect \
  --disable-gpl \
  --disable-avdevice \
  --disable-pthreads \
  --nm="llvm-nm -g" \
  --ar=emar \
  --ranlib=emranlib \
  --cc=emcc \
  --cxx=em++ \
  --objcc=emcc \
  --dep-cc=emcc \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS"

emmake make -j

mkdir -p dist

emcc \
  -I. -I./fftools \
  -Llibavcodec -Llibavfilter -Llibavformat -Llibavutil -Llibswscale -Llibswresample \
  -o dist/ffmpeg-core.st.js \
  fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c \
  -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm \
  -O3 \
  -s MODULARIZE=1 \
  -s ENVIRONMENT=worker \
  -s INVOKE_RUN=0 \
  -s EXPORTED_FUNCTIONS="[_main]" \
  -s EXPORTED_RUNTIME_METHODS="[FS, cwrap, setValue, writeAsciiToMemory]" \
  -s INITIAL_MEMORY=134217728 \
  -s STACK_SIZE=5242880 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s FORCE_FILESYSTEM=1 \
  -s WASM_BIGINT=1
```