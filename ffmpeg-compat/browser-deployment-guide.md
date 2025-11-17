# 🌐 Browser Deployment Guide for FFmpeg WebAssembly

## Overview

This guide covers deploying your browser-optimized FFmpeg build as a complete web application, including server configuration, performance optimization, and production deployment strategies.

## 📋 Prerequisites

### Server Requirements
- **HTTPS**: Required for SharedArrayBuffer and OPFS
- **COOP/COEP Headers**: Mandatory for threading
- **Modern Browser**: Chrome 92+, Firefox 90+, Safari 15.2+
- **CDN**: Recommended for faster loading

### Browser Compatibility Check
```javascript
// Built-in compatibility check
const compatibility = BrowserMediaUtils.checkCompatibility();
console.log('Browser Support:', compatibility);
```

## 🚀 Quick Deployment

### 1. Server Configuration

#### Apache (.htaccess)
```apache
# Security headers for threading
Header always set Cross-Origin-Opener-Policy "same-origin"
Header always set Cross-Origin-Embedder-Policy "require-corp"

# Compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE application/wasm
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE text/javascript
</IfModule>

# Cache control
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType application/wasm "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
</IfModule>
```

#### Nginx
```nginx
# Security headers for threading
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;

# Compression
gzip on;
gzip_types application/wasm application/javascript text/javascript;

# Cache control
location ~* \.(wasm|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

#### Node.js/Express
```javascript
const express = require('express');
const app = express();

// Security headers
app.use((req, res, next) => {
    res.header('Cross-Origin-Opener-Policy', 'same-origin');
    res.header('Cross-Origin-Embedder-Policy', 'require-corp');
    next();
});

// Compression
const compression = require('compression');
app.use(compression());

// Serve static files
app.use(express.static('public', {
    setHeaders: (res, path) => {
        if (path.endsWith('.wasm')) {
            res.setHeader('Content-Type', 'application/wasm');
            res.setHeader('Cache-Control', 'public, max-age=31536000');
        }
    }
}));
```

### 2. File Structure
```
public/
├── index.html                    # Main application
├── ffmpeg-browser.js            # JavaScript glue code (~200KB)
├── ffmpeg-browser.wasm          # WebAssembly module (~20MB)
├── browser-ffmpeg-integration.js # Integration library
└── assets/                      # Additional resources
```

### 3. Deployment Steps

#### Build Your Files
```bash
# Run the browser-optimized build script
chmod +x build-browser-ffmpeg.sh
./build-browser-ffmpeg.sh

# Files will be generated:
# - ffmpeg-browser.js
# - ffmpeg-browser.wasm
```

#### Upload to Server
```bash
# Copy files to your web server
scp ffmpeg-browser.* user@server:/var/www/html/
scp browser-ffmpeg-integration.js user@server:/var/www/html/
scp browser-media-processor.html user@server:/var/www/html/index.html
```

## 🎯 Performance Optimization

### 1. Loading Strategies

#### Progressive Loading
```javascript
// Load FFmpeg only when needed
async function loadFFmpeg() {
    if (!window.ffmpegLoaded) {
        const startTime = performance.now();
        
        // Show loading indicator
        showLoadingIndicator();
        
        // Load with streaming compilation
        const response = await fetch('ffmpeg-browser.wasm');
        const wasmModule = await WebAssembly.compileStreaming(response);
        
        // Initialize
        await initializeFFmpeg(wasmModule);
        
        console.log(`FFmpeg loaded in ${performance.now() - startTime}ms`);
        window.ffmpegLoaded = true;
    }
}
```

#### Service Worker Caching
```javascript
// service-worker.js
const CACHE_NAME = 'ffmpeg-v1';
const urlsToCache = [
    '/',
    '/ffmpeg-browser.js',
    '/ffmpeg-browser.wasm',
    '/browser-ffmpeg-integration.js'
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(urlsToCache))
    );
});

self.addEventListener('fetch', event => {
    event.respondWith(
        caches.match(event.request)
            .then(response => {
                if (response) {
                    return response;
                }
                return fetch(event.request);
            })
    );
});
```

### 2. Memory Management

#### Browser Memory Limits
```javascript
// Monitor memory usage
class MemoryMonitor {
    constructor() {
        this.thresholds = {
            warning: 1500, // MB
            critical: 1800   // MB
        };
    }

    checkMemoryUsage() {
        if (performance.memory) {
            const used = performance.memory.usedJSHeapSize / (1024 * 1024);
            const total = performance.memory.totalJSHeapSize / (1024 * 1024);
            
            if (used > this.thresholds.critical) {
                this.handleCriticalMemory();
            } else if (used > this.thresholds.warning) {
                this.handleWarningMemory();
            }
            
            return { used, total };
        }
        return null;
    }

    handleCriticalMemory() {
        console.warn('Critical memory usage - forcing garbage collection');
        if (window.gc) {
            window.gc();
        }
    }
}
```

### 3. Thread Pool Optimization

#### Dynamic Thread Count
```javascript
// Adjust based on device capabilities
function getOptimalThreadCount() {
    const cores = navigator.hardwareConcurrency || 4;
    const memory = navigator.deviceMemory || 4;
    
    // Conservative approach for mobile devices
    if (memory < 4) return Math.min(cores, 4);
    if (memory < 8) return Math.min(cores, 6);
    return Math.min(cores, 8); // Desktop maximum
}
```

## 📱 Mobile Optimization

### Responsive Loading
```javascript
// Mobile-specific optimizations
function isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

function getMobileOptimizedSettings() {
    return {
        threadCount: isMobile() ? 4 : 8,
        maxMemory: isMobile() ? 1024 : 2048, // MB
        chunkSize: isMobile() ? 1024 * 1024 : 10 * 1024 * 1024 // 1MB vs 10MB chunks
    };
}
```

### Battery Optimization
```javascript
// Monitor battery status
if ('getBattery' in navigator) {
    navigator.getBattery().then(battery => {
        if (battery.level < 0.2 || !battery.charging) {
            // Reduce processing intensity
            reduceProcessingPower();
        }
    });
}
```

## 🔒 Security Considerations

### Content Security Policy
```http
Content-Security-Policy: 
    default-src 'self';
    worker-src 'self' blob:;
    script-src 'self' 'unsafe-eval' 'unsafe-inline';
    style-src 'self' 'unsafe-inline';
    img-src 'self' blob: data:;
    media-src 'self' blob:;
    connect-src 'self';
    frame-ancestors 'none';
```

### Input Validation
```javascript
// Validate file types and sizes
function validateInputFile(file) {
    const MAX_SIZE = 500 * 1024 * 1024; // 500MB
    const ALLOWED_TYPES = [
        'video/mp4', 'video/webm', 'video/ogg',
        'audio/mp3', 'audio/wav', 'audio/ogg',
        'image/jpeg', 'image/png', 'image/webp'
    ];

    if (file.size > MAX_SIZE) {
        throw new Error(`File too large. Maximum size: ${MAX_SIZE / (1024 * 1024)}MB`);
    }

    if (!ALLOWED_TYPES.includes(file.type)) {
        throw new Error('Unsupported file type');
    }

    return true;
}
```

## 🚀 Production Deployment

### CDN Configuration (Cloudflare)
```javascript
// cloudflare-workers.js
addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
    const response = await fetch(request);
    
    // Add security headers
    const newResponse = new Response(response.body, response);
    newResponse.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
    newResponse.headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
    
    // Add compression headers
    newResponse.headers.set('Content-Encoding', 'gzip');
    
    return newResponse;
}
```

### Docker Deployment
```dockerfile
# Dockerfile
FROM nginx:alpine

# Copy application files
COPY public/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Enable gzip compression
RUN echo "gzip on;" >> /etc/nginx/conf.d/default.conf && \
    echo "gzip_types application/wasm application/javascript text/javascript;" >> /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Monitoring and Analytics
```javascript
// Performance monitoring
class PerformanceMonitor {
    trackMetrics() {
        const metrics = {
            loadTime: performance.timing.loadEventEnd - performance.timing.navigationStart,
            wasmSize: this.getWasmSize(),
            memoryUsage: this.getMemoryUsage(),
            processingTime: this.getProcessingTime()
        };

        // Send to analytics
        this.sendToAnalytics(metrics);
    }

    sendToAnalytics(metrics) {
        // Google Analytics, Mixpanel, etc.
        if (window.gtag) {
            gtag('event', 'ffmpeg_performance', metrics);
        }
    }
}
```

## 📊 Performance Benchmarks

### Expected Performance
| Device Type | Load Time | Processing Speed | Memory Usage |
|-------------|-----------|------------------|--------------|
| Desktop (8GB) | 3-5s | 1x real-time | 1-2GB |
| Laptop (4GB) | 4-6s | 0.8x real-time | 800MB-1.5GB |
| Mobile (4GB) | 5-8s | 0.5x real-time | 500MB-1GB |

### Optimization Checklist
- [ ] Enable compression on server
- [ ] Configure proper cache headers
- [ ] Implement service worker caching
- [ ] Monitor memory usage
- [ ] Test on mobile devices
- [ ] Verify COOP/COEP headers
- [ ] Implement error handling
- [ ] Add loading indicators
- [ ] Optimize for slow networks
- [ ] Test battery usage

## 🛠️ Troubleshooting

### Common Issues

#### SharedArrayBuffer Not Available
```javascript
// Check browser support
if (!window.crossOriginIsolated) {
    console.error('COOP/COEP headers not configured');
    showError('Please configure your server with proper headers');
}
```

#### Memory Issues
```javascript
// Handle memory errors
try {
    await processMedia(file, format);
} catch (error) {
    if (error.message.includes('memory')) {
        showError('File too large for browser processing');
        suggestAlternatives();
    }
}
```

#### Loading Performance
```javascript
// Implement loading progress
function showLoadingProgress(loaded, total) {
    const percent = (loaded / total) * 100;
    updateProgressBar(percent);
    updateStatusText(`Loading: ${percent.toFixed(1)}%`);
}
```

This deployment guide provides everything needed to successfully deploy your browser-optimized FFmpeg build in production environments.