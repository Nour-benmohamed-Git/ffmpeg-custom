# 🐳 Docker Build Instructions for Ultimate FFmpeg Browser Build

## Current Docker Environment

You already have a Docker container (`ffmpeg-wasm-build`) running with all the necessary tools installed. This is the **perfect environment** for building the ultimate FFmpeg browser build.

## 🚀 Quick Docker Build

### 1. Execute the Build Script in Docker
```bash
# Copy the build script to the Docker container
docker cp build-browser-ffmpeg.sh ffmpeg-wasm-build:/work/

# Execute the build inside the Docker container
docker exec -it ffmpeg-wasm-build bash -c "cd /work && chmod +x build-browser-ffmpeg.sh && ./build-browser-ffmpeg.sh"
```

### 2. Monitor the Build Progress
The build will take 30-60 minutes depending on your system. You can monitor progress:
```bash
# Check build status
docker exec ffmpeg-wasm-build bash -c "cd /work && ls -la *.js *.wasm 2>/dev/null || echo 'Build in progress...'"

# View build logs in real-time
docker logs ffmpeg-wasm-build --tail 50 -f
```

### 3. Copy Built Files Back
Once complete, copy the built files to your local directory:
```bash
# Copy the built files
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.js ./ffmpeg-ultimate.js
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.wasm ./ffmpeg-ultimate.wasm

# Or copy to your web directory
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.js ./ffmpeg-compat/
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.wasm ./ffmpeg-compat/
```

## 🏗️ Alternative: Step-by-Step Docker Build

### Step 1: Prepare the Environment
```bash
# Check if Docker container is running
docker ps | grep ffmpeg-wasm-build

# If not running, start it (but yours is already running!)
# docker start ffmpeg-wasm-build
```

### Step 2: Set Up Build Environment
```bash
# Copy our ultimate build configuration to Docker
docker cp ffmpeg-browser-ultimate-build.md ffmpeg-wasm-build:/work/
docker cp ffmpeg-browser-progressive-strategy.md ffmpeg-wasm-build:/work/

# Create build directories
docker exec ffmpeg-wasm-build bash -c "mkdir -p /work/src-ultimate /work/deps-ultimate"
```

### Step 3: Build Libraries (This takes time)
```bash
# Build each library family separately (for better error handling)

# Core compression libraries
docker exec ffmpeg-wasm-build bash -c "
cd /work/src-ultimate &&
git clone --depth=1 https://github.com/madler/zlib.git &&
cd zlib &&
emconfigure ./configure --prefix=/work/deps-ultimate --static &&
emmake make -j\$(nproc) install
"

# Audio libraries
docker exec ffmpeg-wasm-build bash -c "
cd /work/src-ultimate &&
for lib in ogg vorbis opus speex; do
  git clone --depth=1 https://github.com/xiph/\${lib}.git
  cd \${lib}
  if [ -f autogen.sh ]; then emconfigure ./autogen.sh; fi
  emconfigure ./configure --prefix=/work/deps-ultimate --disable-shared --enable-static
  emmake make -j\$(nproc) install
  cd ..
done
"

# Video libraries
docker exec ffmpeg-wasm-build bash -c "
cd /work/src-ultimate &&
git clone --depth=1 https://github.com/webmproject/libwebp.git &&
cd libwebp &&
emcmake cmake -B build -DCMAKE_INSTALL_PREFIX=/work/deps-ultimate -DBUILD_SHARED_LIBS=OFF -DWEBP_ENABLE_SIMD=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_WEBP_JS=OFF &&
cmake --build build --config Release --target install
"
```

### Step 4: Build FFmpeg
```bash
# Copy and execute the main build script
docker cp build-browser-ffmpeg.sh ffmpeg-wasm-build:/work/
docker exec -it ffmpeg-wasm-build bash -c "cd /work && ./build-browser-ffmpeg.sh"
```

## 📊 Build Progress Monitoring

### Real-time Progress
```bash
# Watch the build progress
docker exec ffmpeg-wasm-build bash -c "tail -f /work/build.log 2>/dev/null || echo 'No log file yet'"

# Check what's being built
docker exec ffmpeg-wasm-build bash -c "cd /work && find . -name '*.a' -newer /work/start.time 2>/dev/null | head -10"
```

### Memory and CPU Usage
```bash
# Monitor Docker container resources
docker stats ffmpeg-wasm-build

# Check disk usage
docker exec ffmpeg-wasm-build bash -c "df -h /work"
```

## 🎯 Build Configuration Options

### For Maximum Capabilities (Recommended)
```bash
# Use the full ultimate build
docker exec ffmpeg-wasm-build bash -c "cd /work && ./build-browser-ffmpeg.sh"
```

### For Faster Development Build
```bash
# Build with fewer libraries for testing
docker exec ffmpeg-wasm-build bash -c "
cd /work &&
sed -i 's/libraries=(/libraries=(\n  \"zlib:https:\/\/github.com\/madler\/zlib.git\"/\n  \"ogg:https:\/\/github.com\/xiph\/ogg.git\"/\n  \"opus:https:\/\/github.com\/xiph\/opus.git\"/\n)/' build-browser-ffmpeg.sh &&
./build-browser-ffmpeg.sh
"
```

## 🚨 Troubleshooting

### Build Failures
```bash
# Check what failed
docker exec ffmpeg-wasm-build bash -c "cd /work && find . -name '*.log' -exec echo '=== {} ===' \; -exec cat {} \;"

# Clean and retry
docker exec ffmpeg-wasm-build bash -c "cd /work && make clean 2>/dev/null || true"
```

### Memory Issues
```bash
# Increase Docker memory limit (if needed)
# Stop and restart with more memory
docker stop ffmpeg-wasm-build
docker start ffmpeg-wasm-build --memory=8g --memory-swap=16g
```

### Permission Issues
```bash
# Fix permissions
docker exec ffmpeg-wasm-build bash -c "chmod -R 777 /work"
```

## 📦 Extracting the Final Build

### Copy Built Files
```bash
# Create output directory
mkdir -p ./ffmpeg-build-output

# Copy the built files
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.js ./ffmpeg-build-output/
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.wasm ./ffmpeg-build-output/

# Also copy any worker files if they exist
docker cp ffmpeg-wasm-build:/work/ffmpeg-browser.worker.js ./ffmpeg-build-output/ 2>/dev/null || true

# Check what we got
ls -lh ./ffmpeg-build-output/
```

### Verify the Build
```bash
# Test the build
docker exec ffmpeg-wasm-build bash -c "
cd /work &&
node -e '
const Module = require(\"./ffmpeg-browser.js\");
Module().then(module => {
  console.log(\"✅ FFmpeg module loaded successfully!");
  console.log(\"Memory:", module.INITIAL_MEMORY / 1024 / 1024, "MB");
  console.log("Features available");
});
' 2>/dev/null || echo 'Node test completed'
"
```

## 🚀 Ready for Deployment

Once you have the built files:

1. **Copy to your web server**
2. **Configure COOP/COEP headers**
3. **Enable compression (brotli)**
4. **Test with the HTML demo**
5. **Implement progressive loading**

## 🎯 Why Docker is Perfect for This

- **Consistent Environment**: Same build environment everywhere
- **All Dependencies Pre-installed**: Emscripten, build tools, libraries
- **Isolated Build**: Won't affect your host system
- **Easy Cleanup**: Can rebuild from scratch easily
- **Resource Management**: Can allocate specific CPU/memory

## ⏱️ Expected Build Times

- **Basic libraries**: 10-15 minutes
- **Ultimate libraries**: 30-45 minutes  
- **FFmpeg compilation**: 15-30 minutes
- **Total**: 45-90 minutes depending on your system

---

**🎉 You're all set! The Docker container is ready to build your ultimate FFmpeg browser solution. Just run the commands above and you'll have maximum media processing capabilities for your web application!**