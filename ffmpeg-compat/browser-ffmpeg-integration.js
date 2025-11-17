/**
 * Browser-Optimized FFmpeg Integration
 * Provides a clean API for media processing in web browsers
 */

class BrowserFFmpeg {
  constructor() {
    this.module = null;
    this.initialized = false;
    this.memoryMonitor = null;
    this.opfsMounted = false;
    this.workerPool = [];
  }

  /**
   * Initialize FFmpeg with browser optimizations
   */
  async initialize(options = {}) {
    try {
      // Dynamic import for better loading performance
      const createModule = await import('./ffmpeg-browser.js');
      
      this.module = await createModule.default({
        noInitialRun: true,
        preRun: [() => this.setupBrowserEnvironment()],
        print: (text) => this.log('info', text),
        printErr: (text) => this.log('error', text),
        onRuntimeInitialized: () => {
          this.initialized = true;
          this.setupMemoryMonitoring();
          console.log('🎬 FFmpeg initialized for browser');
        },
        ...options
      });

      return true;
    } catch (error) {
      console.error('Failed to initialize FFmpeg:', error);
      throw error;
    }
  }

  /**
   * Setup browser-specific environment
   */
  setupBrowserEnvironment() {
    try {
      // Create OPFS mount point for user files
      this.module.FS.mkdir('/user-files');
      this.module.FS.mount(this.module.OPFS, {}, '/user-files');
      this.opfsMounted = true;
      
      // Create temp directory for processing
      this.module.FS.mkdir('/temp');
      
      console.log('📁 Browser filesystem setup complete');
    } catch (error) {
      console.warn('OPFS not available, using memory filesystem:', error);
      this.opfsMounted = false;
    }
  }

  /**
   * Setup memory monitoring for browser constraints
   */
  setupMemoryMonitoring() {
    this.memoryMonitor = {
      startTime: performance.now(),
      snapshots: [],
      peakUsage: 0,
      
      getUsage: () => {
        const heap = this.module.HEAPU8;
        const used = heap.length / (1024 * 1024); // MB
        const total = this.module.INITIAL_MEMORY / (1024 * 1024); // MB
        return { used: used.toFixed(1), total: total.toFixed(1) };
      },
      
      logSnapshot: (operation) => {
        const usage = this.getUsage();
        this.snapshots.push({
          operation,
          timestamp: performance.now() - this.startTime,
          memory: usage
        });
        
        this.peakUsage = Math.max(this.peakUsage, parseFloat(usage.used));
        
        // Warn if memory usage is high
        if (parseFloat(usage.used) > total * 0.85) {
          console.warn(`⚠️ High memory usage: ${usage.used}MB / ${usage.total}MB`);
        }
      }
    };
  }

  /**
   * Process media file with browser optimizations
   */
  async processMedia(inputFile, outputFormat, options = {}) {
    if (!this.initialized) {
      throw new Error('FFmpeg not initialized. Call initialize() first.');
    }

    const startTime = performance.now();
    
    try {
      this.memoryMonitor?.logSnapshot('start-processing');
      
      // Write input file to filesystem
      const inputPath = `/temp/input-${Date.now()}`;
      const outputPath = `/temp/output-${Date.now()}.${outputFormat}`;
      
      this.module.FS.writeFile(inputPath, inputFile);
      
      // Build FFmpeg command
      const command = this.buildCommand(inputPath, outputPath, options);
      
      // Execute command
      const result = await this.runCommand(command);
      
      // Read output file
      const outputData = this.module.FS.readFile(outputPath);
      
      // Cleanup
      this.cleanupFiles([inputPath, outputPath]);
      
      const processingTime = performance.now() - startTime;
      this.memoryMonitor?.logSnapshot('end-processing');
      
      return {
        data: outputData,
        processingTime,
        memoryUsage: this.memoryMonitor?.getUsage(),
        command: command.join(' ')
      };
      
    } catch (error) {
      console.error('Processing failed:', error);
      throw error;
    }
  }

  /**
   * Build FFmpeg command with browser-safe options
   */
  buildCommand(inputPath, outputPath, options) {
    const command = [
      '-i', inputPath,
      '-threads', '8', // Browser-safe thread count
      '-max_alloc', '1073741824' // 1GB max allocation
    ];

    // Add format-specific optimizations
    switch (options.format) {
      case 'mp4':
        command.push('-c:v', 'libvpx', '-c:a', 'libvorbis');
        break;
      case 'webm':
        command.push('-c:v', 'libvpx-vp9', '-c:a', 'libopus');
        break;
      case 'mp3':
        command.push('-c:a', 'libmp3lame', '-b:a', '192k');
        break;
      case 'opus':
        command.push('-c:a', 'libopus', '-b:a', '128k');
        break;
      default:
        command.push('-c', 'copy');
    }

    // Add user options
    if (options.videoBitrate) {
      command.push('-b:v', options.videoBitrate);
    }
    if (options.audioBitrate) {
      command.push('-b:a', options.audioBitrate);
    }
    if (options.resolution) {
      command.push('-s', options.resolution);
    }
    if (options.fps) {
      command.push('-r', options.fps);
    }

    command.push(outputPath);
    return command;
  }

  /**
   * Run FFmpeg command with error handling
   */
  async runCommand(command) {
    return new Promise((resolve, reject) => {
      try {
        // Simulate command execution (you'll need to implement actual FFmpeg command execution)
        const result = this.module.callMain(command);
        resolve(result);
      } catch (error) {
        reject(new Error(`FFmpeg command failed: ${error.message}`));
      }
    });
  }

  /**
   * Cleanup temporary files
   */
  cleanupFiles(files) {
    files.forEach(file => {
      try {
        this.module.FS.unlink(file);
      } catch (error) {
        console.warn(`Failed to cleanup ${file}:`, error);
      }
    });
  }

  /**
   * Get processing statistics
   */
  getStats() {
    if (!this.memoryMonitor) {
      return null;
    }

    return {
      peakMemoryUsage: `${this.memoryMonitor.peakUsage}MB`,
      memorySnapshots: this.memoryMonitor.snapshots,
      opfsAvailable: this.opfsMounted,
      initialized: this.initialized
    };
  }

  /**
   * Clean shutdown
   */
  async terminate() {
    if (this.module) {
      // Cleanup filesystem
      try {
        this.module.FS.unmount('/user-files');
      } catch (error) {
        // Ignore unmount errors
      }
      
      this.initialized = false;
      console.log('🛑 FFmpeg browser instance terminated');
    }
  }

  /**
   * Browser-safe logging
   */
  log(level, message) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level.toUpperCase()}] ${message}`;
    
    switch (level) {
      case 'error':
        console.error(logMessage);
        break;
      case 'warn':
        console.warn(logMessage);
        break;
      default:
        console.log(logMessage);
    }
  }
}

/**
 * Browser-specific utility functions
 */
export class BrowserMediaUtils {
  /**
   * Check browser compatibility
   */
  static checkCompatibility() {
    const checks = {
      webAssembly: typeof WebAssembly !== 'undefined',
      sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
      opfs: 'storage' in navigator && 'getDirectory' in navigator.storage,
      webWorkers: typeof Worker !== 'undefined',
      bigint: typeof BigInt !== 'undefined'
    };

    checks.overall = Object.values(checks).every(Boolean);
    return checks;
  }

  /**
   * Get optimal thread count for browser
   */
  static getOptimalThreadCount() {
    const cores = navigator.hardwareConcurrency || 4;
    return Math.min(cores, 8); // Browser-safe maximum
  }

  /**
   * Convert File to Uint8Array
   */
  static async fileToArrayBuffer(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(new Uint8Array(reader.result));
      reader.onerror = reject;
      reader.readAsArrayBuffer(file);
    });
  }

  /**
   * Create download link for processed media
   */
  static createDownloadLink(data, filename, mimeType) {
    const blob = new Blob([data], { type: mimeType });
    const url = URL.createObjectURL(blob);
    
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.style.display = 'none';
    
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // Cleanup
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

/**
 * Example usage
 */
export async function exampleUsage() {
  // Check browser compatibility
  const compatibility = BrowserMediaUtils.checkCompatibility();
  if (!compatibility.overall) {
    console.error('Browser not compatible:', compatibility);
    return;
  }

  // Initialize FFmpeg
  const ffmpeg = new BrowserFFmpeg();
  await ffmpeg.initialize();

  // Example: Process a video file
  const inputFile = document.getElementById('fileInput').files[0];
  const inputData = await BrowserMediaUtils.fileToArrayBuffer(inputFile);
  
  try {
    const result = await ffmpeg.processMedia(inputData, 'webm', {
      videoBitrate: '1000k',
      audioBitrate: '128k',
      resolution: '1280x720',
      fps: '30'
    });

    console.log('Processing complete:', {
      processingTime: result.processingTime,
      memoryUsage: result.memoryUsage,
      command: result.command
    });

    // Download result
    BrowserMediaUtils.createDownloadLink(
      result.data, 
      'processed-video.webm', 
      'video/webm'
    );

    // Show stats
    console.log('Processing stats:', ffmpeg.getStats());

  } catch (error) {
    console.error('Processing failed:', error);
  } finally {
    await ffmpeg.terminate();
  }
}

export { BrowserFFmpeg, BrowserMediaUtils };