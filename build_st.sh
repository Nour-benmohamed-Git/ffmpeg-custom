#!/usr/bin/env bash
set -euo pipefail

CFLAGS="-O3 -s WASM_BIGINT=1"
LDFLAGS="$CFLAGS -s INITIAL_MEMORY=536870912 -s MAXIMUM_MEMORY=2147483648 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 -s INVOKE_RUN=0 -s ENVIRONMENT=worker -s EXPORTED_FUNCTIONS=[_main] -s EXPORTED_RUNTIME_METHODS=[FS,cwrap,setValue,writeAsciiToMemory,stringToUTF8,UTF8ToString,lengthBytesUTF8] -s STACK_SIZE=5242880 -s FORCE_FILESYSTEM=1"

emcc -v

emconfigure ./configure \
  --target-os=none \
  --arch=x86_32 \
  --enable-cross-compile \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-stripping \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-doc \
  --disable-debug \
  --disable-network \
  --disable-autodetect \
  --disable-runtime-cpudetect \
  --disable-gpl \
  --disable-avdevice \
  --disable-pthreads \
  --enable-avcodec \
  --enable-avformat \
  --enable-avfilter \
  --enable-swresample \
  --enable-swscale \
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

emmake make clean
emmake make -j

mkdir -p dist
LINK_CMD=$(make -n V=1 ffmpeg_g | sed -n 's/^emcc .*$/&/p' | tail -n 1)
if [ -n "$LINK_CMD" ]; then
  LINK_CMD_JS=${LINK_CMD/-o ffmpeg_g/-o ffmpeg.st.js}
  bash -lc "$LINK_CMD_JS" || true
fi
for f in ffmpeg.st.js ffmpeg_g.js ffmpeg.js a.out.js; do
  if [ -f "$f" ]; then cp -f "$f" dist/ffmpeg-core.st.js; break; fi
done
for f in ffmpeg_g.wasm ffmpeg.wasm a.out.wasm; do
  if [ -f "$f" ]; then cp -f "$f" dist/ffmpeg-core.st.wasm; break; fi
done

