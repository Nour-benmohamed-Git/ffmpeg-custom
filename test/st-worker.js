self.onmessage = async (e) => {
  const msg = e.data || {};
  if (msg.type !== "run") return;

  const logs = [];
  const errors = [];
  const t0 = Date.now();

  let module;
  let base = "../dist-st/";
  try {
    try {
      self.importScripts(base + "ffmpeg-core.st.js");
    } catch (e) {
      base = "../dist/";
      self.importScripts(base + "ffmpeg-core.st.js");
    }
    module = await Module({
      wasmBinaryFile: "ffmpeg-core.st.wasm",
      locateFile: (path) => {
        const p = String(path || "");
        if (p.endsWith(".wasm")) return new URL(base + "ffmpeg-core.st.wasm", self.location).href;
        return new URL(base + p, self.location).href;
      },
      print: (x) => logs.push(String(x)),
      printErr: (x) => errors.push(String(x))
    });
  } catch (err) {
    const t1 = Date.now();
    self.postMessage({ type: "result", ok: false, error: String(err), totalMs: t1 - t0, initLogs: logs, initErrs: errors });
    return;
  }

  function run(args) {
    const out = [];
    const err = [];
    const prevPrint = module.print;
    const prevErr = module.printErr;
    module.print = (x) => out.push(String(x));
    module.printErr = (x) => err.push(String(x));
    const start = performance.now();
    let exitCode = 0;
    try {
      if (typeof module.callMain === "function") {
        module.callMain(args);
      } else if (typeof module.run === "function") {
        module.arguments = args.slice();
        module.run();
      } else if (typeof module.cwrap === "function") {
        const mainFn = module.cwrap("main", "number", ["number", "number"]);
        const bufPtrs = [];
        const argvPtrs = [];
        const makeStr = (s) => {
          const len = module.lengthBytesUTF8(s) + 1;
          const ptr = module._malloc ? module._malloc(len) : 0;
          if (!ptr) throw new TypeError("malloc unavailable for argv");
          module.stringToUTF8(s, ptr, len);
          bufPtrs.push(ptr);
          return ptr;
        };
        const argvBuf = module._malloc ? module._malloc((args.length + 1) * 4) : 0;
        if (!argvBuf) throw new TypeError("malloc unavailable for argv array");
        const allArgs = ["ffmpeg"].concat(args);
        for (let i = 0; i < allArgs.length; i++) {
          const sp = makeStr(String(allArgs[i]));
          module.setValue(argvBuf + (i * 4), sp, "i32");
          argvPtrs.push(sp);
        }
        mainFn(allArgs.length, argvBuf);
        if (module._free) {
          module._free(argvBuf);
          for (const p of bufPtrs) module._free(p);
        }
      } else {
        throw new TypeError("No callMain/run available");
      }
    } catch (ex) {
      const s = String(ex || "");
      if (/ExitStatus/.test(s)) {
        exitCode = (ex.status | 0);
      } else {
        err.push(s);
        exitCode = -1;
      }
    }
    const end = performance.now();
    module.print = prevPrint;
    module.printErr = prevErr;
    return { out, err, exitCode, ms: end - start };
  }

  const results = [];

  const r1 = run([
    "-hide_banner",
    "-loglevel", "error",
    "-f", "lavfi",
    "-i", "sine=frequency=1000:sample_rate=44100",
    "-t", "1",
    "-f", "md5",
    "-"
  ]);
  const md5Audio = (r1.out.join("\n").match(/MD5=([0-9a-f]+)/i) || [])[1] || null;
  results.push({ name: "audio_md5", exitCode: r1.exitCode, ms: r1.ms, md5: md5Audio, err: r1.err });

  const r2 = run([
    "-hide_banner",
    "-loglevel", "error",
    "-f", "lavfi",
    "-i", "testsrc=size=64x64:rate=1",
    "-t", "1",
    "-f", "md5",
    "-"
  ]);
  const md5Video = (r2.out.join("\n").match(/MD5=([0-9a-f]+)/i) || [])[1] || null;
  results.push({ name: "video_md5", exitCode: r2.exitCode, ms: r2.ms, md5: md5Video, err: r2.err });

  const r3 = run([
    "-hide_banner",
    "-loglevel", "error",
    "-f", "lavfi",
    "-i", "color=c=red:size=64x64:rate=1",
    "-frames:v", "1",
    "-f", "image2",
    "-vcodec", "bmp",
    "/out.bmp"
  ]);
  let bmpSize = 0;
  try {
    const stat = module.FS.stat("/out.bmp");
    bmpSize = stat.size | 0;
  } catch {}
  results.push({ name: "image_bmp", exitCode: r3.exitCode, ms: r3.ms, size: bmpSize, err: r3.err });

  const t1 = Date.now();
  self.postMessage({ type: "result", ok: true, totalMs: t1 - t0, initLogs: logs, initErrs: errors, results });
};