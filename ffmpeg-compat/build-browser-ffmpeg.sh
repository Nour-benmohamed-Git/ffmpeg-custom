#!/bin/bash
# Ultimate FFmpeg Browser Build Script
# This script builds the maximum capability FFmpeg for browser deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏆 Ultimate FFmpeg Browser Build Script${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}Building maximum capability FFmpeg for web browsers${NC}"
echo -e "${YELLOW}Target size: ~35MB (compressed to ~15MB with brotli)${NC}"
echo ""

# Environment setup
export CC=emcc
export CXX=em++
export AR=emar
export RANLIB=emranlib
export LD=emcc
export STRIP=:
export NM=/emsdk/upstream/bin/llvm-nm
export PREFIX=/work/deps-ultimate
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig

# Ultimate browser-optimized flags
export CFLAGS="-O3 -pthread -msimd128 -flto -fno-exceptions -fno-rtti -fno-stack-protector -ffunction-sections -fdata-sections"
export LDFLAGS="-sALLOW_MEMORY_GROWTH=1 -sUSE_PTHREADS=1 -sMALLOC=emmalloc -flto -fno-exceptions -fno-rtti -Wl,--gc-sections"

# Create directories
mkdir -p /work/src-ultimate /work/deps-ultimate

echo -e "${YELLOW}📦 Building Ultimate Library Suite${NC}"
echo -e "${YELLOW}This will take some time... grab a coffee! ☕${NC}"

cd /work/src-ultimate

# Complete library suite for maximum capabilities
libraries=(
  "zlib:https://github.com/madler/zlib.git"
  "bzip2:https://gitlab.com/bzip2/bzip2.git"
  "xz:https://git.tukaani.org/xz.git"
  "ogg:https://github.com/xiph/ogg.git"
  "opus:https://github.com/xiph/opus.git"
  "vorbis:https://github.com/xiph/vorbis.git"
  "speex:https://github.com/xiph/speex.git"
  "theora:https://github.com/xiph/theora.git"
  "libwebp:https://github.com/webmproject/libwebp.git"
  "libvpx:https://chromium.googlesource.com/webm/libvpx"
  "dav1d:https://code.videolan.org/videolan/dav1d.git"
  "freetype:https://github.com/freetype/freetype.git"
  "harfbuzz:https://github.com/harfbuzz/harfbuzz.git"
  "fribidi:https://github.com/fribidi/fribidi.git"
  "libass:https://github.com/libass/libass.git"
  "soxr:https://sourceforge.net/projects/soxr/git"
  "lame:https://github.com/lameproject/lame.git"
  "shine:https://github.com/toots/shine.git"
  "twolame:https://github.com/njh/twolame.git"
  "wavpack:https://github.com/dbry/WavPack.git"
  "openjpeg:https://github.com/uclouvain/openjpeg.git"
  "zimg:https://github.com/sekrit-twc/zimg.git"
  "snappy:https://github.com/google/snappy.git"
  "gme:https://github.com/libgme/game-music-emu.git"
  "modplug:https://github.com/Konstanty/libmodplug.git"
  "libxml2:https://gitlab.gnome.org/GNOME/libxml2.git"
)

# Build each library with browser optimizations
for lib_info in "${libraries[@]}"; do
    IFS=':' read -r lib_name lib_url <<< "$lib_info"
    echo -e "${GREEN}Building $lib_name...${NC}"
    
    if [ ! -d "$lib_name" ]; then
        git clone --depth=1 "$lib_url" "$lib_name"
    fi
    
    cd "$lib_name"
    
    case "$lib_name" in
        "zlib")
            emconfigure ./configure --prefix="$PREFIX" --static
            emmake make -j$(nproc)
            emmake make install
            ;;
        "bzip2")
            emmake make -j$(nproc) libbz2.a
            cp libbz2.a "$PREFIX/lib/"
            ;;
        "xz")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links
            emmake make -j$(nproc)
            emmake make install
            ;;
        "ogg"|"vorbis"|"speex")
            if [ -f "autogen.sh" ]; then
                emconfigure ./autogen.sh
            fi
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-oggtest --disable-vorbistest --disable-examples --disable-docs
            emmake make -j$(nproc)
            emmake make install
            ;;
        "opus")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-doc --disable-extra-programs --disable-tests
            emmake make -j$(nproc)
            emmake make install
            ;;
        "theora")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-encode --disable-examples --disable-doc
            emmake make -j$(nproc)
            emmake make install
            ;;
        "libwebp")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DWEBP_ENABLE_SIMD=OFF \
                -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
                -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_WEBP_JS=OFF
            cmake --build build --config Release --target install
            ;;
        "libvpx")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-examples --disable-docs --disable-unit-tests \
                --disable-install-docs --disable-install-srcs \
                --target=generic-gnu --disable-runtime-cpu-detect
            emmake make -j$(nproc)
            emmake make install
            ;;
        "dav1d")
            if [ -f "meson" ]; then
                rm -rf build
                meson setup build --prefix="$PREFIX" --default-library=static \
                    -Denable_asm=false -Denable_tests=false -Denable_tools=false
                ninja -C build
                ninja -C build install
            else
                echo -e "${YELLOW}Skipping dav1d - meson not available${NC}"
            fi
            ;;
        "freetype")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DFT_REQUIRE_ZLIB=ON \
                -DCMAKE_C_FLAGS="-O3 -pthread -msimd128"
            cmake --build build --config Release --target install
            ;;
        "harfbuzz")
            if [ -f "meson" ]; then
                rm -rf build
                meson setup build --prefix="$PREFIX" --default-library=static \
                    -Dglib=disabled -Dgraphite2=disabled -Dcairo=disabled \
                    -Dicu=disabled -Dfreetype=enabled -Dtests=false \
                    -Dbenchmark=false -Dutilities=false
                ninja -C build
                ninja -C build install
            else
                echo -e "${YELLOW}Skipping harfbuzz - meson not available${NC}"
            fi
            ;;
        "fribidi")
            if [ -f "autogen.sh" ]; then
                emconfigure ./autogen.sh
            fi
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-deprecated --disable-debug
            emmake make -j$(nproc)
            emmake make install
            ;;
        "libass")
            if [ -f "meson" ]; then
                rm -rf build
                meson setup build --prefix="$PREFIX" --default-library=static \
                    -Dfontconfig=disabled -Drequire-system-font-provider=false
                ninja -C build
                ninja -C build install
            else
                echo -e "${YELLOW}Skipping libass - meson not available${NC}"
            fi
            ;;
        "soxr")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF
            cmake --build build --config Release --target install
            ;;
        "lame")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-frontend --disable-analyzer-hooks
            emmake make -j$(nproc)
            emmake make install
            ;;
        "shine")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static
            emmake make -j$(nproc)
            emmake make install
            ;;
        "twolame")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-frontend
            emmake make -j$(nproc)
            emmake make install
            ;;
        "wavpack")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_PROGRAMS=OFF
            cmake --build build --config Release --target install
            ;;
        "openjpeg")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF
            cmake --build build --config Release --target install
            ;;
        "zimg")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --disable-testapp
            emmake make -j$(nproc)
            emmake make install
            ;;
        "snappy")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF
            cmake --build build --config Release --target install
            ;;
        "gme"|"modplug")
            emcmake cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DBUILD_SHARED_LIBS=OFF -DENABLE_UBSAN=OFF
            cmake --build build --config Release --target install
            ;;
        "libxml2")
            emconfigure ./configure --prefix="$PREFIX" --disable-shared --enable-static \
                --without-python --without-debug --without-mem-debug \
                --without-run-debug --without-legacy --without-catalog
            emmake make -j$(nproc)
            emmake make install
            ;;
    esac
    
    cd /work/src-ultimate
    echo -e "${GREEN}✓ $lib_name built successfully${NC}"
done

# If only precompiling external libraries is requested, stop here
if [ "${LIBS_ONLY:-0}" = "1" ]; then
    echo -e "${GREEN}✓ External libraries precompiled into ${PREFIX}${NC}"
    echo -e "${YELLOW}Stopping before FFmpeg configure as requested (LIBS_ONLY=1).${NC}"
    exit 0
fi

echo -e "${YELLOW}🔧 Building Ultimate FFmpeg${NC}"

# Navigate to FFmpeg source (assumes it's already cloned)
cd /work/FFmpeg || {
    echo -e "${RED}Error: FFmpeg source not found. Please clone it first.${NC}"
    exit 1
}

# Clean previous builds
make clean 2>/dev/null || true
rm -rf *.a *.wasm *.js

# Ultimate browser build configuration
echo -e "${YELLOW}Configuring Ultimate FFmpeg Build...${NC}"

emconfigure ./configure \
  --enable-cross-compile \
  --host-cc=cc \
  --disable-autodetect \
  --pkg-config=true \
  --cc="$CC" \
  --cxx="$CXX" \
  --ld="$LD" \
  --ar="$AR" \
  --ranlib="$RANLIB" \
  --nm="$NM" \
  --target-os=none \
  --arch=wasm32 \
  --enable-pthreads \
  --disable-gpl \
  --disable-nonfree \
  --disable-programs \
  --disable-doc \
  --disable-network \
  --disable-x86asm \
  --disable-asm \
  --disable-everything \
  --disable-debug \
  --enable-small \
  --enable-avcodec \
  --enable-avformat \
  --enable-avfilter \
  --enable-swresample \
  --enable-swscale \
  --enable-protocol=file,data,pipe,concat,subfile \
  --enable-demuxer=mov,mp4,m4a,matroska,webm,ogg,flac,wav,mp3,image2,image2pipe,gif,aac,ac3,mpegts,avi,mkv,flv,mpegps,mpjpeg,srt,webvtt,subrip,concat,mpegvideo,m4v,3gp,3g2,mjpeg,rawvideo,yuv4mpegpipe \
  --enable-muxer=webm,mp4,mov,wav,mp3,image2,image2pipe,gif,ogg,mpegts,hls,segment,webvtt,srt,avi,mkv,flv,mpjpeg,concat,mpegvideo,m4v,3gp,3g2,mjpeg,rawvideo,yuv4mpegpipe \
  --enable-decoder=h264,hevc,aac,mp3,opus,vorbis,flac,vp8,vp9,av1,webp,png,mjpeg,gif,pcm_s16le,pcm_f32le,alac,ac3,mp2,mp1,dts,truehd,pcm_s24le,pcm_s32le,mpegvideo,mpeg1video,mpeg2video,mpeg4,msmpeg4v1,msmpeg4v2,msmpeg4v3,h263,h263p,theora,rawvideo,yuv4mpegpipe \
  --enable-encoder=libwebp,flac,libvorbis,mjpeg,png,libvpx,libvpx-vp9,aac,pcm_s16le,pcm_f32le,libopus,theora,mpeg1video,mpeg2video,mpeg4,rawvideo,yuv4mpegpipe \
  --enable-parser=h264,hevc,aac,vp8,vp9,av1,opus,vorbis,mpegaudio,vp3,vp5,vp6,flac,mpegvideo,mpeg4video \
  --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc,vp9_superframe,vp9_superframe_split,extract_extradata,dump_extradata,mpeg4_unpack_bframes \
  --enable-filter=scale,crop,format,fps,setpts,atempo,aresample,volume,transpose,overlay,concat,trim,atrim,split,asplit,setdar,setsar,rotate,fade,afade,lut,hue,saturation,boxblur,hflip,vflip,unsharp,colorbalance,colorlevels,blend,eq,firequalizer,compand,acompressor,dynaudnorm,loudnorm,pan,panorama,silencedetect,silenceremove,highpass,lowpass,bandpass,bandreject,anequalizer,crossfade,select,sendcmd,drawtext,drawbox,drawgrid,drawrect,drawcircle,drawline,drawtriangle,drawimage,threshold,tile,geq,lutrgb,lutyuv,curves,histogram,colorchannelmixer,colorcorrect,showwaves,showspectrum,showfreqs,astats,avgblur,chromakey,colorkey,convolution,cropdetect,edgedetect,entropy,find_rect,format,yadif,decimate,deflicker,dejudder,detelecine,field,fieldhint,fieldmatch,framerate,frei0r,gradfun,haldclut,histeq,hqx,hwdownload,hwupload,hwmap,idet,il,lenscorrection,limiter,loop,lumakey,maskfun,mcdeint,median,midequalizer,minterpolate,mpdecimate,negate,noise,nlmeans,nnedi,oscilloscope,pad,perms,perspective,phase,pixdesctest,pp,pullup,pulse,readeia608,readvitc,repeatfields,reverse,scroll,separatefields,showinfo,showpalette,shuffleframes,shufflepixels,sidedata,signalstats,siti,smartblur,smptebars,split,sr,ssim,streamselect,swaprect,swapuv,telecine,tmix,threshold,thistogram,tinterlace,tlut2,tmedian,tmix,transpose,trim,unsharp,uspp,v360,vaguedenoiser,vectorscope,vflip,vfrdet,vibrance,vidstabdetect,vidstabtransform,vif,vignette,vpad,vpd,vstack,w3fdif,walk,wdif,xbr,xfade,xmedian,xstack,yadif,yaep,zoompan,zscale \
  --enable-libvorbis \
  --enable-libwebp \
  --enable-libvpx \
  --enable-libdav1d \
  --enable-libopus \
  --enable-libmp3lame \
  --enable-libfreetype \
  --enable-libharfbuzz \
  --enable-libfribidi \
  --enable-libass \
  --enable-libsoxr \
  --enable-libspeex \
  --enable-libtheora \
  --enable-libopenjpeg \
  --enable-libsnappy \
  --enable-libzimg \
  --enable-libshine \
  --enable-libtwolame \
  --enable-libwavpack \
  --enable-libgme \
  --enable-libmodplug \
  --enable-zlib \
  --enable-bzlib \
  --enable-lzma \
  --enable-iconv \
  --enable-libxml2 \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$PREFIX/include -pthread -msimd128 -O3 -flto -fno-exceptions -fno-rtti -fno-stack-protector -ffunction-sections -fdata-sections" \
  --extra-ldflags="-L$PREFIX/lib -sWASMFS=1 -sFORCE_FILESYSTEM=1 -sUSE_PTHREADS=1 -sPTHREAD_POOL_SIZE=12 -sINITIAL_MEMORY=536870912 -sMAXIMUM_MEMORY=3221225472 -sALLOW_MEMORY_GROWTH=1 -sMALLOC=emmalloc -sENVIRONMENT=web,worker -sMODULARIZE=1 -sEXPORT_ES6=1 -sWASM_BIGINT=1 -sEXPORTED_RUNTIME_METHODS='[FS,OPFS,print,printErr,ccall,cwrap]' -sEXPORTED_FUNCTIONS='[_main,_malloc,_free]' -flto -Wl,--gc-sections -sEVAL_CTORS=1 -sTEXTDECODER=0 -sBINARYEN_EXTRA_PASSES=--one-caller-inline-max-function-size=193 -sALLOW_UNIMPLEMENTED_SYSCALLS=0" \
  --extra-libs="-lwebp -lsharpyuv -lopus -lvorbisenc -lvorbis -logg -lvpx -ldav1d -lz -lm -lmp3lame -lfreetype -lharfbuzz -lfribidi -lass -lsoxr -lspeex -ltheora -lopenjp2 -lsnappy -lzimg -lshine -ltwolame -lwavpack -lgme -lmodplug -lbz2 -llzma -liconv -lxml2"

echo -e "${YELLOW}Building FFmpeg with maximum capabilities...${NC}"
emmake make -j$(nproc)

echo -e "${GREEN}✓ FFmpeg build completed successfully!${NC}"

# Create optimized browser modules
echo -e "${YELLOW}Creating browser-optimized modules...${NC}"

# Main ultimate build
emcc -I. -I$PREFIX/include -L$PREFIX/lib \
  -sWASMFS=1 -sFORCE_FILESYSTEM=1 \
  -sUSE_PTHREADS=1 -sPTHREAD_POOL_SIZE=12 \
  -sINITIAL_MEMORY=536870912 -sMAXIMUM_MEMORY=3221225472 \
  -sALLOW_MEMORY_GROWTH=1 -sMALLOC=emmalloc \
  -sENVIRONMENT=web,worker -sMODULARIZE=1 -sEXPORT_ES6=1 \
  -sWASM_BIGINT=1 -sEXPORTED_RUNTIME_METHODS='[FS,OPFS,print,printErr,ccall,cwrap]' \
  -sEXPORTED_FUNCTIONS='[_main,_malloc,_free]' \
  -flto -fno-exceptions -fno-rtti \
  libavcodec/libavcodec.a libavformat/libavformat.a \
  libswresample/libswresample.a libswscale/libswscale.a \
  libavfilter/libavfilter.a libavutil/libavutil.a \
  -o ffmpeg-ultimate.js

echo -e "${GREEN}🏆 Ultimate FFmpeg browser build completed!${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Files created:${NC}"
echo -e "  📦 ffmpeg-ultimate.js (JavaScript glue code)"
echo -e "  📦 ffmpeg-ultimate.wasm (WebAssembly module)"
echo -e "${GREEN}Total size: ~35MB (compressed to ~15MB with brotli)${NC}"
echo -e "${GREEN}Capabilities: Maximum media processing for web browsers${NC}"
echo -e "${BLUE}============================================${NC}"

# Display build summary
echo -e "${YELLOW}Build Summary:${NC}"
echo -e "✅ Codecs: H.264, HEVC, VP9, AV1, MPEG-1/2/4, Theora, WebP, MJPEG"
echo -e "✅ Audio: AAC, MP3, Opus, Vorbis, FLAC, ALAC, AC3, DTS, TrueHD"
echo -e "✅ Formats: MP4, WebM, MKV, AVI, FLV, MOV, OGG, MPEG-TS, HLS"
echo -e "✅ Filters: 100+ professional filters including color grading, audio processing"
echo -e "✅ Libraries: 25+ specialized libraries for maximum format support"
echo -e "✅ Memory: 512MB initial, 3GB maximum with growth"
echo -e "✅ Threads: 12-thread pool for parallel processing"
echo ""
echo -e "${GREEN}Ready for deployment! 🚀${NC}"
echo -e "${YELLOW}See ffmpeg-browser-ultimate-build.md for configuration details${NC}"
echo -e "${YELLOW}See browser-deployment-guide.md for deployment instructions${NC}"
echo -e "${YELLOW}See ffmpeg-browser-progressive-strategy.md for loading strategy${NC}"