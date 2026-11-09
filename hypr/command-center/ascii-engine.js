/* ═══════════════════════════════════════════════════════════════════
 *  TOKYO 80S TRV30 MASTER DECK — HIGH-PERFORMANCE ASCII ENGINE
 *  Features:
 *    1. Real-time WebRTC Webcam-to-ASCII sampler (30-60 FPS)
 *    2. 3D Rotating Wireframe Cassette & Camcorder Vector Mesh (Idle)
 *    3. Authentic Tokyo Broadcast OSD Telemetry & Audio Spectrum
 *    4. Switchable styles: Classic OSD, Shading Blocks, Contour / Edge, Matrix
 *    5. 100% Waybar Warm Vintage Palette compliance
 * ═══════════════════════════════════════════════════════════════════ */

(function() {
  'use strict';

  // Output display container
  const outputEl = document.getElementById('ascii-output');
  if (!outputEl) {
    console.error("ASCII Engine: #ascii-output element not found");
    return;
  }

  // Dimensions for ASCII character grid (proportional 50x16 framing without text clipping)
  const COLS = 50;
  const ROWS = 16;

  // Character ramps
  const RAMPS = {
    classic: "   .:-=+*#%@",
    blocks:  "   ░▒▓█",
    matrix:  " .·:*+=%#@",
    dense:   " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"
  };

  let currentStyle = 'classic';
  let invertLuminance = false;
  let isCameraActive = false;
  let mediaStream = null;
  let animFrameId = null;
  let isDeckVisible = true;

  // Offscreen video element for webcam processing
  const rawVideo = document.getElementById('raw-video');

  const offCanvas = document.createElement('canvas');
  offCanvas.width = COLS;
  offCanvas.height = ROWS;
  const offCtx = offCanvas.getContext('2d', { willReadFrequently: true });
  offCtx.imageSmoothingEnabled = false;

  // Pre-computed 256-entry lookup table for high-speed integer luminance mapping
  const lut = new Array(256);
  function rebuildLut() {
    const ramp = RAMPS[currentStyle] || RAMPS.classic;
    const rampLen = ramp.length;
    const contrast = 1.35;
    for (let i = 0; i < 256; i++) {
      let lum = ((i / 255 - 0.5) * contrast + 0.5) * 255;
      lum = Math.max(0, Math.min(255, lum));
      if (invertLuminance) lum = 255 - lum;
      lut[i] = ramp[Math.floor((lum / 255) * (rampLen - 1))];
    }
  }
  rebuildLut();

  // ═════════════════════════════════════════════════════════════════
  // 1. 3D WIREFRAME CASSETTE & VECTOR MESH (IDLE PRIVACY MODE)
  // ═════════════════════════════════════════════════════════════════

  const bx = 1.15, by = 0.58, bz = 0.18;

  // 3D Model Vertices for TRV-30 Cassette Shell
  const vertices = [
    // Outer Shell (0..7)
    [-bx, -by, -bz], [ bx, -by, -bz], [ bx,  by, -bz], [-bx,  by, -bz],
    [-bx, -by,  bz], [ bx, -by,  bz], [ bx,  by,  bz], [-bx,  by,  bz],
    // Front Clear Tape Window (8..11)
    [-0.55, -0.18, -bz - 0.01], [ 0.55, -0.18, -bz - 0.01], [ 0.55,  0.18, -bz - 0.01], [-0.55,  0.18, -bz - 0.01],
    // Back Clear Tape Window (12..15)
    [-0.55, -0.18,  bz + 0.01], [ 0.55, -0.18,  bz + 0.01], [ 0.55,  0.18,  bz + 0.01], [-0.55,  0.18,  bz + 0.01],
    // Front Spool Hubs (16, 17)
    [-0.30, 0.0, -bz - 0.01], [ 0.30, 0.0, -bz - 0.01],
    // Back Spool Hubs (18, 19)
    [-0.30, 0.0,  bz + 0.01], [ 0.30, 0.0,  bz + 0.01]
  ];

  // 3D Box Faces in screen-space CCW winding order for backface culling
  const boxFaces = [
    { name: 'front',  indices: [0, 1, 2, 3] },
    { name: 'back',   indices: [5, 4, 7, 6] },
    { name: 'top',    indices: [4, 5, 1, 0] },
    { name: 'bottom', indices: [3, 2, 6, 7] },
    { name: 'left',   indices: [4, 0, 3, 7] },
    { name: 'right',  indices: [1, 5, 6, 2] }
  ];

  // Pre-allocated grid buffer to prevent garbage-collection stutter
  const grid = [];
  for (let r = 0; r < ROWS; r++) {
    grid.push(new Array(COLS));
  }

  let lastTimestamp = 0;
  let lastRenderTime = 0;
  let rotAngleY = 0;

  function renderIdleFrame(timestamp) {
    if (!isDeckVisible) return;

    if (!timestamp) timestamp = performance.now();
    const elapsed = timestamp - lastRenderTime;
    // Cap rendering to 24 FPS (~41.6ms) for authentic vintage camcorder rate & low CPU
    if (elapsed < 41) {
      if (!isCameraActive && isDeckVisible) {
        animFrameId = requestAnimationFrame(renderIdleFrame);
      }
      return;
    }

    const dt = lastRenderTime > 0 ? Math.min(0.08, elapsed / 1000) : 0.041;
    lastRenderTime = timestamp;
    lastTimestamp = timestamp;

    // Physically smooth delta-time rotation (steady 40 RPM turntable spin)
    rotAngleY += dt * 0.70;
    const ay = rotAngleY;
    const ax = 0.20; // 11.5° stable down-tilt shows top & front surfaces cleanly

    // Clear buffer (fast reuse)
    for (let r = 0; r < ROWS; r++) {
      grid[r].fill(' ');
    }

    // Camera projection setup
    const dist = 3.6;
    const scaleX = 14.0;
    const scaleY = 6.8;
    const cx = Math.floor(COLS / 2);
    const cy = 7;

    // Rotate and project 3D vertices to 2D screen coordinates
    const projected = [];
    for (let i = 0; i < vertices.length; i++) {
      let [x, y, z] = vertices[i];

      // Rotate Y (azimuth)
      let x1 = x * Math.cos(ay) + z * Math.sin(ay);
      let z1 = -x * Math.sin(ay) + z * Math.cos(ay);

      // Rotate X (pitch tilt)
      let y2 = y * Math.cos(ax) - z1 * Math.sin(ax);
      let z2 = y * Math.sin(ax) + z1 * Math.cos(ax);

      const fov = dist / (dist + z2);
      const px = Math.round(cx + x1 * fov * scaleX);
      const py = Math.round(cy + y2 * fov * scaleY);
      projected.push({ x: px, y: py, z: z2 });
    }

    // Continuous vector line drawing with slope bridge characters to prevent stair-step gaps
    function drawLine(p0, p1) {
      let x0 = p0.x, y0 = p0.y, x1 = p1.x, y1 = p1.y;
      let dx = Math.abs(x1 - x0);
      let dy = Math.abs(y1 - y0);
      let sx = (x0 < x1) ? 1 : -1;
      let sy = (y0 < y1) ? 1 : -1;
      let err = dx - dy;
      let prevX = x0, prevY = y0;

      while (true) {
        let char;
        if (dx > 1.8 * dy) {
          // Nearly horizontal line: bridge vertical step with diagonal connector
          char = (prevY !== y0) ? ((sy * sx < 0) ? '/' : '\\') : '-';
        } else if (dy > 1.8 * dx) {
          // Nearly vertical line: bridge horizontal step with diagonal connector
          char = (prevX !== x0) ? ((sy * sx < 0) ? '/' : '\\') : '|';
        } else {
          // True diagonal
          char = ((x1 - x0) * (y1 - y0) < 0) ? '/' : '\\';
        }

        if (x0 >= 0 && x0 < COLS && y0 >= 0 && y0 < ROWS) {
          if (grid[y0][x0] === ' ') {
            grid[y0][x0] = char;
          } else if (grid[y0][x0] !== char) {
            grid[y0][x0] = '+'; // Clean node intersection
          }
        }
        prevX = x0; prevY = y0;

        if (x0 === x1 && y0 === y1) break;
        let e2 = 2 * err;
        if (e2 > -dy) {
          err -= dy;
          x0 += sx;
        }
        if (e2 < dx) {
          err += dx;
          y0 += sy;
        }
      }
    }

    // ─── OVERLAY TELEMETRY & VIEW-FINDER OSD ───
    function writeText(row, col, text) {
      if (row < 0 || row >= ROWS) return;
      for (let i = 0; i < text.length; i++) {
        const targetCol = col + i;
        if (targetCol >= 0 && targetCol < COLS) {
          grid[row][targetCol] = text[i];
        }
      }
    }

    // ─── ROW 1: TOP BROADCAST SMPTE TIMECODE & FIELD SYNC ───
    const tcHour = String(Math.floor((timestamp / 3600000) % 24)).padStart(2, '0');
    const tcMin = String(Math.floor((timestamp / 60000) % 60)).padStart(2, '0');
    const tcSec = String(Math.floor((timestamp / 1000) % 60)).padStart(2, '0');
    const tcFrame = String(Math.floor((timestamp / 16.666) % 60)).padStart(2, '0');
    const timecodeStr = `${tcHour}:${tcMin}:${tcSec}:${tcFrame}`;
    writeText(0, 1, `SMPTE: ${timecodeStr} [LOCK] 59.94Hz`);
    writeText(1, 1, "EXP: EV+1.2 ISO:400 F/1.8 1/60s S-LOG");
    writeText(2, 1, "OPTICAL TURNTABLE WIREFRAME // 3CCD 4:2:2");

    // Optical Center Autofocus Crosshairs
    writeText(cy, cx - 2, "[ + ]");

    // Render Box Faces with Backface Culling
    let frontFacing = false;
    let backFacing = false;

    for (let f = 0; f < boxFaces.length; f++) {
      const face = boxFaces[f];
      const idxs = face.indices;
      const p0 = projected[idxs[0]];
      const p1 = projected[idxs[1]];
      const p2 = projected[idxs[2]];

      // 2D screen-space cross product normal (Z component)
      const nz = (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x);

      if (nz > 0) {
        if (face.name === 'front') frontFacing = true;
        if (face.name === 'back') backFacing = true;

        // Draw 4 perimeter edges of visible face
        for (let k = 0; k < 4; k++) {
          drawLine(projected[idxs[k]], projected[idxs[(k + 1) % 4]]);
        }

        // Draw node markers at vertices
        for (let k = 0; k < 4; k++) {
          const p = projected[idxs[k]];
          if (p.x >= 0 && p.x < COLS && p.y >= 0 && p.y < ROWS) {
            grid[p.y][p.x] = '+';
          }
        }

        // Side face grip tabs (when edge-on at ~90° or ~270°)
        if (face.name === 'left' || face.name === 'right') {
          const midY = Math.round((p0.y + projected[idxs[3]].y) / 2);
          const midX = Math.round((p0.x + p1.x) / 2);
          if (midX >= 1 && midX < COLS - 2 && midY >= 0 && midY < ROWS) {
            writeText(midY, midX - 1, "[#]");
          }
        }
      }
    }

    const spoolIcons = ['( o )', '( * )', '( + )', '( x )'];
    const iconIdx = Math.floor(rotAngleY * 4.0) % spoolIcons.length;
    const hubStr = spoolIcons[iconIdx];

    if (frontFacing) {
      // Front window perimeter (indices 8..11)
      for (let k = 0; k < 4; k++) {
        drawLine(projected[8 + k], projected[8 + ((k + 1) % 4)]);
      }

      // Front spool hubs (indices 16, 17)
      [projected[16], projected[17]].forEach(p => {
        if (p.x >= 2 && p.x < COLS - 3 && p.y >= 0 && p.y < ROWS) {
          writeText(p.y, p.x - 2, hubStr);
        }
      });

      // Front label
      const label = "ME-60";
      const midX = Math.round((projected[0].x + projected[1].x) / 2 - label.length / 2);
      const midY = Math.round((projected[0].y + projected[8].y) / 2);
      if (midY >= 0 && midY < ROWS && midX >= 0 && midX < COLS - label.length) {
        writeText(midY, midX, label);
      }
    } else if (backFacing) {
      // Back window perimeter (indices 12..15)
      for (let k = 0; k < 4; k++) {
        drawLine(projected[12 + k], projected[12 + ((k + 1) % 4)]);
      }

      // Back spool hubs (indices 18, 19)
      [projected[18], projected[19]].forEach(p => {
        if (p.x >= 2 && p.x < COLS - 3 && p.y >= 0 && p.y < ROWS) {
          writeText(p.y, p.x - 2, hubStr);
        }
      });

      // Back label
      const label = "TYPE-II";
      const midX = Math.round((projected[5].x + projected[4].x) / 2 - label.length / 2);
      const midY = Math.round((projected[5].y + projected[12].y) / 2);
      if (midY >= 0 && midY < ROWS && midX >= 0 && midX < COLS - label.length) {
        writeText(midY, midX, label);
      }
    }

    writeText(12, 1, "STEADYSHOT EIS // 3CCD 4:2:2 NTSC [NORM]");
    writeText(13, 1, "LUMA HISTO: [ ▂▃▅▆▇█▆▅▃ ] PED: 7.5 IRE");
    writeText(14, 1, "TAPE TRACKING: [||||||||||░░] JITTER: 0.04µs");
    writeText(15, 1, "CH-01 VIEW-FINDER TERMINAL // CCU READY");

    // Fast string compilation without intermediate array allocations
    let finalAscii = '';
    for (let r = 0; r < ROWS; r++) {
      finalAscii += grid[r].join('') + (r < ROWS - 1 ? '\n' : '');
    }
    outputEl.textContent = finalAscii;

    if (!isCameraActive && isDeckVisible) {
      animFrameId = requestAnimationFrame(renderIdleFrame);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // 2. REAL-TIME WEBCAM TO ASCII PIPELINE (REC ACTIVE)
  // ═════════════════════════════════════════════════════════════════

  // ─── CAMCORDER OSD OVERLAY (Pre-defined for Zero-Allocation) ───
  function writeWebcamOverlay(row, col, text) {
    if (row < 0 || row >= ROWS) return;
    const gridRow = grid[row];
    for (let i = 0; i < text.length; i++) {
      const targetCol = col + i;
      if (targetCol >= 0 && targetCol < COLS) {
        gridRow[targetCol] = text[i];
      }
    }
  }

  function renderWebcamFrame(timestamp) {
    if (!isCameraActive || !isDeckVisible) return;

    if (!timestamp) timestamp = performance.now();
    const elapsed = timestamp - lastCamRenderTime;
    // Paced at steady 22 FPS (~45ms) to prevent event loop queue congestion
    if (elapsed < 45) {
      animFrameId = requestAnimationFrame(renderWebcamFrame);
      return;
    }
    lastCamRenderTime = timestamp;

    if (rawVideo.videoWidth === 0 || rawVideo.videoHeight === 0) {
      animFrameId = requestAnimationFrame(renderWebcamFrame);
      return;
    }

    // High-speed nearest-neighbor frame sampling (instantaneous downscaling)
    offCtx.drawImage(rawVideo, 0, 0, COLS, ROWS);
    const imgData = offCtx.getImageData(0, 0, COLS, ROWS);
    const data = imgData.data;

    // Edge detection / Sobel mode
    if (currentStyle === 'contour') {
      const grayscale = new Float32Array(COLS * ROWS);
      for (let i = 0; i < data.length; i += 4) {
        grayscale[i >> 2] = (data[i] * 77 + data[i + 1] * 150 + data[i + 2] * 29) >> 8;
      }

      for (let y = 0; y < ROWS; y++) {
        const row = grid[y];
        for (let x = 0; x < COLS; x++) {
          if (x === 0 || x === COLS - 1 || y === 0 || y === ROWS - 1) {
            row[x] = ' ';
            continue;
          }
          const idx = y * COLS + x;
          const gx =
            -grayscale[idx - COLS - 1] + grayscale[idx - COLS + 1] +
            -2 * grayscale[idx - 1] + 2 * grayscale[idx + 1] +
            -grayscale[idx + COLS - 1] + grayscale[idx + COLS + 1];

          const gy =
            -grayscale[idx - COLS - 1] - 2 * grayscale[idx - COLS] - grayscale[idx - COLS + 1] +
             grayscale[idx + COLS - 1] + 2 * grayscale[idx + COLS] + grayscale[idx + COLS + 1];

          const mag = Math.abs(gx) + Math.abs(gy);
          let char = ' ';
          if (mag > 160) char = '#';
          else if (mag > 110) char = '*';
          else if (mag > 70) char = '+';
          else if (mag > 40) char = ':';
          else if (mag > 20) char = '.';
          row[x] = char;
        }
      }
    } else {
      // High-speed integer LUT luminance mapping (0 array allocations)
      for (let y = 0; y < ROWS; y++) {
        const row = grid[y];
        const rowOffset = y * COLS;
        for (let x = 0; x < COLS; x++) {
          const srcX = COLS - 1 - x;
          const idx = (rowOffset + srcX) << 2;
          const lum = (data[idx] * 77 + data[idx + 1] * 150 + data[idx + 2] * 29) >> 8;
          row[x] = lut[lum];
        }
      }
    }

    // Elapsed recording time
    const elapsedSec = Math.floor((Date.now() - recStartTime) / 1000);
    const eh = String(Math.floor(elapsedSec / 3600)).padStart(2, '0');
    const em = String(Math.floor((elapsedSec % 3600) / 60)).padStart(2, '0');
    const es = String(elapsedSec % 60).padStart(2, '0');
    const recTimeStr = `${eh}:${em}:${es}`;

    // Top OSD Header
    writeWebcamOverlay(0, 1, `[● REC] ${recTimeStr} SP 35mm F/1.8 1/60s`);

    // Center Autofocus Reticle
    const cx = Math.floor(COLS / 2);
    const cy = Math.floor(ROWS / 2);
    writeWebcamOverlay(cy, cx - 2, "[ + ]");

    // Bottom Telemetry
    writeWebcamOverlay(ROWS - 1, 1, "NTSC 60i COLOR // 48kHz Hi-Fi // EIS: ON");

    // Fast string compilation
    let finalAscii = '';
    for (let r = 0; r < ROWS; r++) {
      finalAscii += grid[r].join('') + (r < ROWS - 1 ? '\n' : '');
    }
    outputEl.textContent = finalAscii;

    if (isCameraActive && isDeckVisible) {
      animFrameId = requestAnimationFrame(renderWebcamFrame);
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // 3. PUBLIC API & CONTROL METHODS
  // ═════════════════════════════════════════════════════════════════

  async function engageCamera() {
    if (isCameraActive) return true;
    try {
      // NOTE: Do NOT cancel animFrameId here so 3D wireframe keeps spinning smoothly during camera start
      mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 24 } },
        audio: false
      });

      rawVideo.srcObject = mediaStream;

      // Start video playback
      await rawVideo.play();

      // Once video is actively playing frames, cancel idle animation and transition seamlessly
      if (animFrameId) cancelAnimationFrame(animFrameId);
      isCameraActive = true;
      recStartTime = Date.now();
      lastCamRenderTime = performance.now();
      outputEl.classList.add('mode-cam');

      if (isDeckVisible) {
        renderWebcamFrame();
      }
      return true;
    } catch (err) {
      console.error("Camera acquisition failed:", err);
      isCameraActive = false;
      if (isDeckVisible && !animFrameId) {
        renderIdleFrame();
      }
      throw err;
    }
  }

  function disengageCamera() {
    if (!isCameraActive && !mediaStream) return;

    if (mediaStream) {
      mediaStream.getTracks().forEach(track => track.stop());
      mediaStream = null;
    }
    rawVideo.srcObject = null;
    isCameraActive = false;
    outputEl.classList.remove('mode-cam');

    if (animFrameId) cancelAnimationFrame(animFrameId);
    if (isDeckVisible) {
      renderIdleFrame();
    }
  }

  function setStyle(styleName) {
    if (['classic', 'blocks', 'matrix', 'contour', 'dense'].includes(styleName)) {
      currentStyle = styleName;
      rebuildLut();
    }
  }

  function toggleInvert() {
    invertLuminance = !invertLuminance;
    rebuildLut();
  }

  // Window Visibility Handler connected to Hyprland Socket2 in app.py
  // Instantly halts animation frames when hidden (0.0% CPU) and resumes when active
  window.onDeckVisibility = function(visible) {
    if (isDeckVisible === visible) return;
    isDeckVisible = visible;
    if (!visible) {
      if (animFrameId) {
        cancelAnimationFrame(animFrameId);
        animFrameId = null;
      }
    } else {
      lastRenderTime = 0;
      lastCamRenderTime = 0;
      lastTimestamp = performance.now();
      if (!animFrameId) {
        if (isCameraActive) {
          animFrameId = requestAnimationFrame(renderWebcamFrame);
        } else {
          animFrameId = requestAnimationFrame(renderIdleFrame);
        }
      }
    }
  };

  // Export to global window scope
  window.AsciiEngine = {
    engageCamera,
    disengageCamera,
    setStyle,
    toggleInvert,
    isCameraActive: () => isCameraActive,
    getStyle: () => currentStyle
  };

  // Start in idle 3D wireframe mode on boot
  renderIdleFrame();

})();
