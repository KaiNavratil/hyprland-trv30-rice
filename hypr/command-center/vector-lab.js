/* ═══════════════════════════════════════════════════════════════════
 *  TOKYO 80S TRV30 — VECTOR LAB & MISSION CONTROL VISUALIZERS
 *  Features:
 *    1. Lissajous Parametric Oscilloscope (Multi-harmonic XY vector knot)
 *    2. Celestial Orbital Satellite Radar (NASA / Tokyo mission track)
 *    3. 3D Spacecraft Descent Runway Horizon (Retro perspective vector grid)
 *    4. Integrated zero-CPU sleep suspension when hidden or in minimal mode
 * ═══════════════════════════════════════════════════════════════════ */

(function() {
  'use strict';

  let isRunning = false;
  let animId = null;

  // ═════════════════════════════════════════════════════════════════
  // 1. LISSAJOUS PARAMETRIC OSCILLOSCOPE
  // ═════════════════════════════════════════════════════════════════

  const lissCanvas = document.getElementById('lissajous-canvas');
  let lissCtx = lissCanvas ? lissCanvas.getContext('2d') : null;
  let lissMode = 'lissajous'; // 'lissajous', 'harmonic', 'pulse'
  let lissSpeed = 1.0;
  let lissTime = 0;

  function initLissajous() {
    if (!lissCanvas || !lissCtx) return;
    const rect = lissCanvas.getBoundingClientRect();
    lissCanvas.width = rect.width > 0 ? rect.width : 340;
    lissCanvas.height = rect.height > 0 ? rect.height : 140;
  }

  function renderLissajous() {
    if (!lissCtx) return;
    const w = lissCanvas.width;
    const h = lissCanvas.height;
    const cx = w / 2;
    const cy = h / 2;

    // Phosphor decay persistence
    lissCtx.fillStyle = 'rgba(5, 4, 3, 0.16)';
    lissCtx.fillRect(0, 0, w, h);

    // Reticle crosshair grid
    lissCtx.strokeStyle = 'rgba(184, 169, 152, 0.12)';
    lissCtx.lineWidth = 1;
    lissCtx.setLineDash([2, 4]);

    lissCtx.beginPath();
    lissCtx.moveTo(0, cy); lissCtx.lineTo(w, cy);
    lissCtx.moveTo(cx, 0); lissCtx.lineTo(cx, h);
    // Outer border
    lissCtx.strokeRect(4, 4, w - 8, h - 8);
    lissCtx.stroke();
    lissCtx.setLineDash([]);

    lissTime += 0.025 * lissSpeed;

    if (lissMode === 'lissajous') {
      // 3D rotating multi-frequency parametric Lissajous knot
      const a = 3, b = 2;
      const delta = lissTime * 0.7;
      const rx = (w * 0.38);
      const ry = (h * 0.36);

      lissCtx.lineWidth = 1.6;
      lissCtx.shadowBlur = 4;
      lissCtx.shadowColor = '#d4944c';
      lissCtx.strokeStyle = '#e8dfd4';

      lissCtx.beginPath();
      const steps = 180;
      for (let i = 0; i <= steps; i++) {
        const theta = (i / steps) * Math.PI * 2;
        const x = cx + rx * Math.sin(a * theta + delta) * Math.cos(lissTime * 0.2);
        const y = cy + ry * Math.sin(b * theta) * Math.cos(lissTime * 0.15);
        if (i === 0) lissCtx.moveTo(x, y);
        else lissCtx.lineTo(x, y);
      }
      lissCtx.stroke();

      // Second harmonic overtone (amber / gold glow)
      lissCtx.shadowColor = '#c44444';
      lissCtx.strokeStyle = 'rgba(212, 148, 76, 0.7)';
      lissCtx.lineWidth = 1.0;
      lissCtx.beginPath();
      for (let i = 0; i <= steps; i++) {
        const theta = (i / steps) * Math.PI * 2;
        const x = cx + (rx * 0.85) * Math.sin((a + 1) * theta + delta * 1.3);
        const y = cy + (ry * 0.85) * Math.sin((b + 1) * theta + delta * 0.8);
        if (i === 0) lissCtx.moveTo(x, y);
        else lissCtx.lineTo(x, y);
      }
      lissCtx.stroke();
      lissCtx.shadowBlur = 0;

    } else if (lissMode === 'harmonic') {
      // Multi-channel chromatic wave curves (inspired by Pinterest bottom-left monitor)
      const curves = [
        { color: '#d4944c', freq: 1.2, speed: 1.0, amp: h * 0.28, phase: 0 },
        { color: '#88aa88', freq: 2.1, speed: 1.4, amp: h * 0.22, phase: 1.2 },
        { color: '#6898b8', freq: 3.5, speed: 0.7, amp: h * 0.16, phase: 2.5 },
        { color: '#e8dfd4', freq: 0.8, speed: 1.8, amp: h * 0.32, phase: 4.0 }
      ];

      curves.forEach(c => {
        lissCtx.strokeStyle = c.color;
        lissCtx.lineWidth = 1.4;
        lissCtx.beginPath();
        for (let x = 0; x < w; x += 3) {
          const normX = (x / w) * Math.PI * 4;
          const y = cy + Math.sin(normX * c.freq + lissTime * c.speed + c.phase) * c.amp;
          if (x === 0) lissCtx.moveTo(x, y);
          else lissCtx.lineTo(x, y);
        }
        lissCtx.stroke();
      });

    } else if (lissMode === 'pulse') {
      // ECG / Radar Telemetry Waveform Pulse
      lissCtx.strokeStyle = '#88aa88';
      lissCtx.lineWidth = 1.8;
      lissCtx.shadowBlur = 5;
      lissCtx.shadowColor = '#88aa88';

      lissCtx.beginPath();
      for (let x = 0; x < w; x += 2) {
        const progress = ((x - (lissTime * 60) % w) + w) % w;
        let spike = 0;
        if (progress > w * 0.45 && progress < w * 0.55) {
          const p = (progress - w * 0.45) / (w * 0.10);
          if (p < 0.2) spike = -Math.sin(p * Math.PI * 5) * (h * 0.2);
          else if (p < 0.6) spike = Math.sin((p - 0.2) * Math.PI * 2.5) * (h * 0.42);
          else spike = -Math.sin((p - 0.6) * Math.PI * 2.5) * (h * 0.15);
        }
        const y = cy + spike;
        if (x === 0) lissCtx.moveTo(x, y);
        else lissCtx.lineTo(x, y);
      }
      lissCtx.stroke();
      lissCtx.shadowBlur = 0;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // 2. LIVE NETWORK BANDWIDTH DUAL-TRACE OSCILLOSCOPE (Bay 2)
  // ═════════════════════════════════════════════════════════════════
  const bwCanvas = document.getElementById('bandwidth-canvas');
  let bwCtx = bwCanvas ? bwCanvas.getContext('2d') : null;
  let rxHistory = new Array(48).fill(8);
  let txHistory = new Array(48).fill(4);
  let curRxSpeedStr = "0 KB/s";
  let curTxSpeedStr = "0 KB/s";
  let peakRxKb = 40;

  function initBandwidthScope() {
    if (!bwCanvas || !bwCtx) return;
    const rect = bwCanvas.getBoundingClientRect();
    bwCanvas.width = rect.width > 0 ? rect.width : 340;
    bwCanvas.height = rect.height > 0 ? rect.height : 125;
  }

  function pushBandwidth(rxKb, txKb, rxStr, txStr) {
    if (rxKb !== undefined) {
      rxHistory.push(rxKb);
      if (rxHistory.length > 48) rxHistory.shift();
      if (rxKb > peakRxKb) peakRxKb = rxKb;
    }
    if (txKb !== undefined) {
      txHistory.push(txKb);
      if (txHistory.length > 48) txHistory.shift();
    }
    if (rxStr) curRxSpeedStr = rxStr;
    if (txStr) curTxSpeedStr = txStr;
  }

  function renderBandwidthScope() {
    if (!bwCtx) return;
    const w = bwCanvas.width || 340;
    const h = bwCanvas.height || 125;

    // Phosphor decay
    bwCtx.fillStyle = 'rgba(5, 5, 5, 0.28)';
    bwCtx.fillRect(0, 0, w, h);

    const padL = 36;
    const padR = 10;
    const padT = 16;
    const padB = 18;
    const graphW = w - padL - padR;
    const graphH = h - padT - padB;

    // Reticle & Grid
    bwCtx.strokeStyle = 'rgba(184, 169, 152, 0.12)';
    bwCtx.lineWidth = 1;
    bwCtx.setLineDash([2, 3]);

    for (let i = 0; i <= 4; i++) {
      const y = padT + (graphH / 4) * i;
      bwCtx.beginPath();
      bwCtx.moveTo(padL, y);
      bwCtx.lineTo(padL + graphW, y);
      bwCtx.stroke();
    }
    const tDivs = 6;
    for (let i = 0; i <= tDivs; i++) {
      const x = padL + (graphW / tDivs) * i;
      bwCtx.beginPath();
      bwCtx.moveTo(x, padT);
      bwCtx.lineTo(x, padT + graphH);
      bwCtx.stroke();
    }
    bwCtx.setLineDash([]);

    // Grid labels
    bwCtx.fillStyle = 'rgba(184, 169, 152, 0.6)';
    bwCtx.font = "7.5px 'VCR OSD Mono', monospace";
    const maxScale = Math.max(80, Math.ceil(peakRxKb * 1.25 / 50) * 50);
    bwCtx.fillText(`${Math.round(maxScale)}K`, 4, padT + 6);
    bwCtx.fillText(`${Math.round(maxScale / 2)}K`, 4, padT + graphH / 2 + 3);
    bwCtx.fillText("0", 18, padT + graphH + 2);

    function drawTrace(history, color, shadowColor, isFill) {
      if (history.length < 2) return;
      bwCtx.strokeStyle = color;
      bwCtx.lineWidth = 1.6;
      bwCtx.shadowBlur = 4;
      bwCtx.shadowColor = shadowColor;
      bwCtx.beginPath();

      const step = graphW / (history.length - 1);
      history.forEach((val, i) => {
        const x = padL + i * step;
        const norm = Math.min(1.0, val / maxScale);
        const y = padT + graphH - norm * graphH;
        if (i === 0) bwCtx.moveTo(x, y);
        else bwCtx.lineTo(x, y);
      });
      bwCtx.stroke();

      if (isFill) {
        bwCtx.lineTo(padL + graphW, padT + graphH);
        bwCtx.lineTo(padL, padT + graphH);
        bwCtx.closePath();
        bwCtx.fillStyle = shadowColor;
        bwCtx.fill();
      }
      bwCtx.shadowBlur = 0;
    }

    drawTrace(rxHistory, '#88ff88', 'rgba(136, 255, 136, 0.15)', true);
    drawTrace(txHistory, '#d4944c', 'rgba(212, 148, 76, 0.18)', false);

    bwCtx.fillStyle = '#d4944c';
    bwCtx.font = "bold 8px 'VCR OSD Mono', monospace";
    bwCtx.fillText(`▲ TX: ${curTxSpeedStr}`, padL + 4, padT - 4);
    bwCtx.fillStyle = '#88ff88';
    bwCtx.fillText(`▼ RX: ${curRxSpeedStr}`, padL + 84, padT - 4);
    bwCtx.fillStyle = '#b8a998';
    bwCtx.fillText(`[PEAK: ${Math.round(peakRxKb)} KB/s]`, padL + graphW - 74, padT - 4);
  }

  // ═════════════════════════════════════════════════════════════════
  // 3. INTERACTIVE TOUCHPAD & VECTOR CALIBRATION SCOPE (Bay 3)
  // ═════════════════════════════════════════════════════════════════
  const touchCanvas = document.getElementById('touchpad-canvas');
  let touchCtx = touchCanvas ? touchCanvas.getContext('2d') : null;
  let touchX = 170, touchY = 62;
  let originX = 170, originY = 62;
  let isDragging = false;
  let dragLockActive = false;
  let touchTrail = [];
  let touchRipples = [];
  let touchSweepAngle = 0;
  let tapCount = 0;
  let lastTapTime = 0;
  let lastMoveTime = 0;
  let curSpeed = 0;
  let targetSpeed = 0;
  let headingDeg = 0;
  let isDirectHover = false;
  let lastScrollTime = 0;
  let scrollDir = '';
  let scrollEnergy = 0;
  let scrollDeltaY = 0;
  let touchGlobalListenersAttached = false;
  let badgeUpdateCounter = 0;

  function getCompass(deg) {
    const d = (deg + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'E';
    if (d < 67.5) return 'SE';
    if (d < 112.5) return 'S';
    if (d < 157.5) return 'SW';
    if (d < 202.5) return 'W';
    if (d < 247.5) return 'NW';
    if (d < 292.5) return 'N';
    return 'NE';
  }

  function flashTouchButton(id) {
    const btn = document.getElementById(id);
    if (!btn) return;
    const led = btn.querySelector('.latch-led');
    if (led) {
      led.classList.add('flash');
      setTimeout(() => led.classList.remove('flash'), 220);
    }
  }

  function initTouchpadScope() {
    if (!touchCanvas || !touchCtx) return;
    const rect = touchCanvas.getBoundingClientRect();
    touchCanvas.width = rect.width > 0 ? rect.width : 340;
    touchCanvas.height = rect.height > 0 ? rect.height : 125;
    if (touchX === 170 && touchY === 62) {
      touchX = touchCanvas.width / 2;
      touchY = touchCanvas.height / 2;
      originX = touchX;
      originY = touchY;
    }

    if (touchGlobalListenersAttached) return;
    touchGlobalListenersAttached = true;

    // Global pointer move tracks finger gliding across the entire window
    window.addEventListener('pointermove', (e) => {
      if (!touchCanvas) return;
      const now = performance.now();
      const dt = lastMoveTime ? Math.max(8, now - lastMoveTime) : 16;
      lastMoveTime = now;

      const r = touchCanvas.getBoundingClientRect();
      const isDirect = (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom);
      isDirectHover = isDirect;

      let targetX, targetY;
      const w = touchCanvas.width || 340;
      const h = touchCanvas.height || 125;

      if (isDirect) {
        targetX = Math.max(4, Math.min(w - 4, e.clientX - r.left));
        targetY = Math.max(4, Math.min(h - 4, e.clientY - r.top));
      } else {
        const padX = 14;
        const padY = 12;
        const normX = Math.min(1.0, Math.max(0.0, e.clientX / window.innerWidth));
        const normY = Math.min(1.0, Math.max(0.0, e.clientY / window.innerHeight));
        targetX = padX + normX * (w - padX * 2);
        targetY = padY + normY * (h - padY * 2);
      }

      const dx = targetX - touchX;
      const dy = targetY - touchY;
      const dist = Math.hypot(dx, dy);

      if (dist > 0.4) {
        headingDeg = Math.round(Math.atan2(dy, dx) * 180 / Math.PI);
        const instantSpeed = (dist / dt) * 1000;
        targetSpeed = Math.min(2200, instantSpeed);
      }

      touchX = targetX;
      touchY = targetY;

      const isContact = (e.buttons === 1) || isDragging || dragLockActive;
      touchTrail.push({
        x: touchX,
        y: touchY,
        life: 1.0,
        speed: targetSpeed,
        contact: isContact,
        direct: isDirect
      });
      if (touchTrail.length > 34) touchTrail.shift();
    }, { passive: true });

    // Tap / Click detection with shockwaves
    window.addEventListener('pointerdown', (e) => {
      if (!touchCanvas) return;
      const now = Date.now();
      const r = touchCanvas.getBoundingClientRect();
      const isDirect = (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom);

      const w = touchCanvas.width || 340;
      const h = touchCanvas.height || 125;
      let targetX, targetY;
      if (isDirect) {
        targetX = Math.max(4, Math.min(w - 4, e.clientX - r.left));
        targetY = Math.max(4, Math.min(h - 4, e.clientY - r.top));
      } else {
        const padX = 14;
        const padY = 12;
        const normX = Math.min(1.0, Math.max(0.0, e.clientX / window.innerWidth));
        const normY = Math.min(1.0, Math.max(0.0, e.clientY / window.innerHeight));
        targetX = padX + normX * (w - padX * 2);
        targetY = padY + normY * (h - padY * 2);
      }

      touchX = targetX;
      touchY = targetY;
      originX = targetX;
      originY = targetY;
      isDragging = true;

      // Sonar Shockwave Ripple
      touchRipples.push({
        x: touchX,
        y: touchY,
        r: 3,
        maxR: 32,
        alpha: 1.0,
        color: dragLockActive ? '#ffaa44' : '#d4944c'
      });

      // Double-tap to drag logic
      if (now - lastTapTime < 340) {
        tapCount++;
        if (tapCount >= 2) {
          dragLockActive = !dragLockActive; // Toggle drag lock
          if (dragLockActive) {
            flashTouchButton('btn-touch-drag');
            flashTouchButton('btn-touch-lock');
          }
        }
      } else {
        tapCount = 1;
      }
      lastTapTime = now;

      flashTouchButton('btn-touch-tap');
    }, { passive: true });

    window.addEventListener('pointerup', () => {
      if (!dragLockActive) {
        isDragging = false;
      }
    }, { passive: true });

    // 2-Finger scroll wheel detection
    window.addEventListener('wheel', (e) => {
      if (!touchCanvas) return;
      lastScrollTime = performance.now();
      scrollDir = e.deltaY < 0 ? 'UP' : 'DOWN';
      scrollDeltaY = e.deltaY;
      scrollEnergy = 1.0;
      flashTouchButton('btn-touch-scroll');
    }, { passive: true });
  }

  function renderTouchpadScope() {
    if (!touchCtx) return;
    const w = touchCanvas.width || 340;
    const h = touchCanvas.height || 125;
    const cx = w / 2;
    const cy = h / 2;
    const now = performance.now();

    // Smooth speed easing
    curSpeed += (targetSpeed - curSpeed) * 0.16;
    if (now - lastMoveTime > 650) {
      targetSpeed = 0;
    }

    // High retention phosphor decay
    touchCtx.fillStyle = 'rgba(6, 5, 4, 0.28)';
    touchCtx.fillRect(0, 0, w, h);

    // 1. Grid & Precision Coordinate Reticle
    touchCtx.strokeStyle = 'rgba(184, 169, 152, 0.10)';
    touchCtx.lineWidth = 1;
    touchCtx.setLineDash([2, 4]);

    for (let x = 20; x < w; x += 30) {
      touchCtx.beginPath();
      touchCtx.moveTo(x, 8);
      touchCtx.lineTo(x, h - 8);
      touchCtx.stroke();
    }
    for (let y = 16; y < h; y += 26) {
      touchCtx.beginPath();
      touchCtx.moveTo(10, y);
      touchCtx.lineTo(w - 10, y);
      touchCtx.stroke();
    }
    touchCtx.setLineDash([]);

    // Outer Touchpad Surface Bezel
    touchCtx.strokeStyle = isDragging || dragLockActive
      ? 'rgba(212, 148, 76, 0.7)'
      : 'rgba(212, 148, 76, 0.35)';
    touchCtx.lineWidth = 1;
    touchCtx.strokeRect(6, 6, w - 12, h - 12);

    // Corner alignment ticks
    touchCtx.strokeStyle = 'rgba(232, 223, 212, 0.4)';
    const cSize = 6;
    // Top-left
    touchCtx.beginPath();
    touchCtx.moveTo(10, 10 + cSize); touchCtx.lineTo(10, 10); touchCtx.lineTo(10 + cSize, 10);
    // Top-right
    touchCtx.moveTo(w - 10 - cSize, 10); touchCtx.lineTo(w - 10, 10); touchCtx.lineTo(w - 10, 10 + cSize);
    // Bottom-left
    touchCtx.moveTo(10, h - 10 - cSize); touchCtx.lineTo(10, h - 10); touchCtx.lineTo(10 + cSize, h - 10);
    // Bottom-right
    touchCtx.moveTo(w - 10 - cSize, h - 10); touchCtx.lineTo(w - 10, h - 10); touchCtx.lineTo(w - 10, h - 10 - cSize);
    touchCtx.stroke();

    // 2. Standby Radar Sweep (When hands are still)
    const isPassive = (curSpeed < 10 && !isDragging && !dragLockActive && scrollEnergy <= 0.05);
    if (isPassive) {
      touchSweepAngle += 0.032;
      const beamX = cx + Math.cos(touchSweepAngle) * (w * 0.44);
      const beamY = cy + Math.sin(touchSweepAngle) * (h * 0.38);
      touchCtx.strokeStyle = 'rgba(136, 170, 136, 0.22)';
      touchCtx.lineWidth = 1;
      touchCtx.beginPath();
      touchCtx.moveTo(cx, cy);
      touchCtx.lineTo(beamX, beamY);
      touchCtx.stroke();

      // Faint central target graticule
      touchCtx.strokeStyle = 'rgba(136, 170, 136, 0.12)';
      touchCtx.beginPath();
      touchCtx.arc(cx, cy, 22, 0, Math.PI * 2);
      touchCtx.stroke();
    }

    // 3. Shockwave Pings on Tap / Click
    touchRipples.forEach(rip => {
      touchCtx.strokeStyle = rip.color || '#d4944c';
      touchCtx.globalAlpha = Math.max(0, rip.alpha);
      touchCtx.lineWidth = 1.6;
      touchCtx.beginPath();
      touchCtx.arc(rip.x, rip.y, rip.r, 0, Math.PI * 2);
      touchCtx.stroke();
      touchCtx.globalAlpha = 1.0;

      rip.r += 2.0;
      rip.alpha -= 0.06;
    });
    touchRipples = touchRipples.filter(r => r.alpha > 0);

    // 4. Two-Finger Scroll Indicator Waves
    if (scrollEnergy > 0.02) {
      const isUp = (scrollDir === 'UP');
      touchCtx.fillStyle = `rgba(104, 200, 255, ${scrollEnergy * 0.8})`;
      touchCtx.font = "bold 9px 'VCR OSD Mono', monospace";
      touchCtx.fillText(isUp ? "▲▲ 2F-SCROLL UP" : "▼▼ 2F-SCROLL DOWN", cx - 44, cy - 2);

      // Dual vertical scroll velocity bars
      const barH = Math.min(36, Math.abs(scrollDeltaY) * 0.35) * scrollEnergy;
      touchCtx.strokeStyle = '#68c8ff';
      touchCtx.lineWidth = 2;
      touchCtx.beginPath();
      if (isUp) {
        touchCtx.moveTo(w - 24, cy + barH);
        touchCtx.lineTo(w - 24, cy - barH);
        touchCtx.lineTo(w - 28, cy - barH + 5);
      } else {
        touchCtx.moveTo(w - 24, cy - barH);
        touchCtx.lineTo(w - 24, cy + barH);
        touchCtx.lineTo(w - 28, cy + barH - 5);
      }
      touchCtx.stroke();

      scrollEnergy *= 0.91;
    }

    // 5. Phosphor Comet Trails (Reactive to finger gliding)
    if (touchTrail.length > 1) {
      for (let i = 1; i < touchTrail.length; i++) {
        const p1 = touchTrail[i - 1];
        const p2 = touchTrail[i];
        const alpha = p2.life * 0.75;
        const col = p2.contact
          ? `rgba(212, 148, 76, ${alpha})`
          : (scrollEnergy > 0.1 ? `rgba(104, 200, 255, ${alpha})` : `rgba(136, 255, 136, ${alpha})`);

        touchCtx.strokeStyle = col;
        touchCtx.lineWidth = Math.min(4, 1.2 + (p2.speed / 500));
        touchCtx.beginPath();
        touchCtx.moveTo(p1.x, p1.y);
        touchCtx.lineTo(p2.x, p2.y);
        touchCtx.stroke();
      }
    }

    touchTrail.forEach(p => {
      const radius = Math.min(5, (1.0 - p.life) * 3 + 2);
      touchCtx.fillStyle = p.contact
        ? `rgba(255, 180, 80, ${p.life * 0.9})`
        : (scrollEnergy > 0.1 ? `rgba(120, 220, 255, ${p.life * 0.85})` : `rgba(136, 255, 136, ${p.life * 0.85})`);
      touchCtx.beginPath();
      touchCtx.arc(p.x, p.y, radius, 0, Math.PI * 2);
      touchCtx.fill();
      p.life -= 0.045;
    });
    touchTrail = touchTrail.filter(p => p.life > 0);

    // 6. Vector Drag Anchor or Tracking Crosshair
    if (isDragging || dragLockActive) {
      // Dynamic dashed drag vector
      touchCtx.strokeStyle = '#d4944c';
      touchCtx.lineWidth = 2;
      touchCtx.setLineDash([3, 3]);
      touchCtx.beginPath();
      touchCtx.moveTo(originX, originY);
      touchCtx.lineTo(touchX, touchY);
      touchCtx.stroke();
      touchCtx.setLineDash([]);

      // Anchor circle
      touchCtx.strokeStyle = '#88aa88';
      touchCtx.lineWidth = 1.5;
      touchCtx.beginPath();
      touchCtx.arc(originX, originY, 6, 0, Math.PI * 2);
      touchCtx.stroke();

      // Dynamic cursor target square
      touchCtx.strokeStyle = dragLockActive ? '#ff8800' : '#c44444';
      touchCtx.lineWidth = 2;
      touchCtx.strokeRect(touchX - 7, touchY - 7, 14, 14);

      const dx = touchX - originX;
      const dy = touchY - originY;
      const dist = Math.round(Math.hypot(dx, dy));
      const deg = Math.round(Math.atan2(dy, dx) * 180 / Math.PI);

      touchCtx.fillStyle = '#e8dfd4';
      touchCtx.font = "8px 'VCR OSD Mono', monospace";
      touchCtx.fillText(`Δ: ${dist}px @ ${deg}°`, touchX + 10, touchY + 4);
    } else {
      // Precision Tracking Reticle
      touchCtx.strokeStyle = (curSpeed > 20) ? '#88ff88' : 'rgba(136, 170, 136, 0.7)';
      touchCtx.lineWidth = 1.2;
      touchCtx.beginPath();
      touchCtx.moveTo(touchX - 9, touchY); touchCtx.lineTo(touchX - 3, touchY);
      touchCtx.moveTo(touchX + 3, touchY); touchCtx.lineTo(touchX + 9, touchY);
      touchCtx.moveTo(touchX, touchY - 9); touchCtx.lineTo(touchX, touchY - 3);
      touchCtx.moveTo(touchX, touchY + 3); touchCtx.lineTo(touchX, touchY + 9);
      touchCtx.stroke();

      // Center laser dot
      touchCtx.fillStyle = (curSpeed > 20) ? '#ffffff' : '#88aa88';
      touchCtx.beginPath();
      touchCtx.arc(touchX, touchY, 1.5, 0, Math.PI * 2);
      touchCtx.fill();
    }

    // 7. Telemetry & Kinematics OSD
    const compass = getCompass(headingDeg);
    touchCtx.fillStyle = '#b8a998';
    touchCtx.font = "8px 'VCR OSD Mono', monospace";
    touchCtx.fillText(`POS: [X:${Math.round(touchX).toString().padStart(3, '0')}, Y:${Math.round(touchY).toString().padStart(3, '0')}]`, 12, h - 8);

    touchCtx.fillStyle = (curSpeed > 10) ? '#88ff88' : '#b8a998';
    touchCtx.fillText(`VEL: ${Math.round(curSpeed).toString().padStart(4, ' ')} px/s`, 126, h - 8);

    touchCtx.fillStyle = '#b8a998';
    touchCtx.fillText(`DIR: ${compass}`, 216, h - 8);

    // Status Mode on Right
    if (dragLockActive) {
      touchCtx.fillStyle = '#ff8800';
      touchCtx.fillText("🔒 DRAG LOCK", w - 88, h - 8);
    } else if (isDragging) {
      touchCtx.fillStyle = '#d4944c';
      touchCtx.fillText("● TAP-DRAG", w - 80, h - 8);
    } else if (scrollEnergy > 0.1) {
      touchCtx.fillStyle = '#68c8ff';
      touchCtx.fillText("▲▼ 2F-SCROLL", w - 86, h - 8);
    } else if (curSpeed > 20) {
      touchCtx.fillStyle = '#88ff88';
      touchCtx.fillText("● GLIDE ACTIVE", w - 94, h - 8);
    } else {
      touchCtx.fillStyle = '#88aa88';
      touchCtx.fillText("○ STANDBY", w - 68, h - 8);
    }

    // 8. Dynamic Header Badge Update (Throttled every 6 frames)
    badgeUpdateCounter++;
    if (badgeUpdateCounter % 6 === 0) {
      const badge = document.getElementById('touchpad-status-badge');
      if (badge) {
        if (dragLockActive) {
          badge.textContent = "ELAN SENSOR [DRAG-LOCK]";
          badge.style.color = "#ffaa44";
        } else if (isDragging) {
          badge.textContent = "ELAN SENSOR [TAP-DRAG]";
          badge.style.color = "#d4944c";
        } else if (scrollEnergy > 0.1) {
          badge.textContent = `ELAN SENSOR [2F-SCROLL ${scrollDir}]`;
          badge.style.color = "#68c8ff";
        } else if (curSpeed > 25) {
          badge.textContent = `ELAN SENSOR [GLIDE: ${Math.round(curSpeed)}px/s]`;
          badge.style.color = "#88ff88";
        } else {
          badge.textContent = "ELAN SENSOR [ARMED]";
          badge.style.color = "";
        }
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // 4. 8-CHANNEL DIGITAL LOGIC TIMING ANALYZER (Pinterest Timing Bus)
  // ═════════════════════════════════════════════════════════════════

  const logicCanvas = document.getElementById('logic-analyzer-canvas');
  let logicCtx = logicCanvas ? logicCanvas.getContext('2d') : null;
  let logicShift = 0;

  function initLogicAnalyzer() {
    if (!logicCanvas || !logicCtx) return;
    const rect = logicCanvas.getBoundingClientRect();
    logicCanvas.width = rect.width > 0 ? rect.width : 340;
    logicCanvas.height = rect.height > 0 ? rect.height : 110;
  }

  const LOGIC_CHANNELS = [
    { name: 'D0', color: '#d4944c', period: 16, offset: 0 },
    { name: 'D1', color: '#d4944c', period: 32, offset: 8 },
    { name: 'D2', color: '#d4944c', period: 24, offset: 4 },
    { name: 'D3', color: '#d4944c', period: 48, offset: 12 },
    { name: 'CLK', color: '#88ff88', period: 8, offset: 0 },
    { name: 'ALE', color: '#88aa88', period: 64, offset: 16 },
    { name: 'RD',  color: '#7b9db7', period: 32, offset: 2 },
    { name: 'WR',  color: '#c44444', period: 48, offset: 18 }
  ];

  function renderLogicAnalyzer() {
    if (!logicCtx) return;
    const w = logicCanvas.width;
    const h = logicCanvas.height;

    // Faint decay background
    logicCtx.fillStyle = '#060504';
    logicCtx.fillRect(0, 0, w, h);

    logicShift += 1.2;

    const startX = 28;
    const endX = w - 42;
    const numChannels = LOGIC_CHANNELS.length;
    const laneH = (h - 10) / numChannels;

    // Timing grid lines (vertical ticks)
    logicCtx.strokeStyle = 'rgba(184, 169, 152, 0.08)';
    logicCtx.lineWidth = 1;
    logicCtx.setLineDash([2, 4]);
    const gridSpacing = 32;
    const offsetGrid = (logicShift % gridSpacing);
    for (let x = startX; x < endX; x += gridSpacing) {
      const gx = x - offsetGrid;
      if (gx >= startX && gx <= endX) {
        logicCtx.beginPath();
        logicCtx.moveTo(gx, 4);
        logicCtx.lineTo(gx, h - 6);
        logicCtx.stroke();
      }
    }
    logicCtx.setLineDash([]);

    // Draw Trigger Cursor
    const trigX = Math.round(startX + (endX - startX) * 0.42);
    logicCtx.strokeStyle = 'rgba(196, 68, 68, 0.4)';
    logicCtx.lineWidth = 1;
    logicCtx.setLineDash([1, 2]);
    logicCtx.beginPath();
    logicCtx.moveTo(trigX, 4);
    logicCtx.lineTo(trigX, h - 4);
    logicCtx.stroke();
    logicCtx.setLineDash([]);

    // Render channels
    LOGIC_CHANNELS.forEach((ch, idx) => {
      const yBase = Math.round(8 + idx * laneH + laneH * 0.85);
      const yHigh = yBase - Math.round(laneH * 0.65);

      // Channel label
      logicCtx.fillStyle = ch.color;
      logicCtx.font = "8px 'VCR OSD Mono', monospace";
      logicCtx.fillText(ch.name, 4, yBase - 1);

      // Channel separator line
      logicCtx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
      logicCtx.lineWidth = 0.5;
      logicCtx.beginPath();
      logicCtx.moveTo(startX, yBase + 2);
      logicCtx.lineTo(endX, yBase + 2);
      logicCtx.stroke();

      // Digital Pulse Waveform
      logicCtx.strokeStyle = ch.color;
      logicCtx.lineWidth = 1.2;
      logicCtx.beginPath();

      let lastLevel = null;
      for (let x = startX; x <= endX; x += 1) {
        const samplePos = x + logicShift + ch.offset;
        let isHigh = false;
        if (ch.name === 'CLK') {
          isHigh = ((samplePos % ch.period) < ch.period / 2);
        } else if (ch.name === 'ALE') {
          isHigh = ((samplePos % ch.period) < 8);
        } else if (ch.name === 'RD' || ch.name === 'WR') {
          isHigh = ((samplePos % ch.period) > 12); // active low inverted
        } else {
          // Data channels (pseudo-bus pattern)
          const bit = Math.floor(samplePos / ch.period);
          isHigh = ((bit * 37 + idx * 13) % 7) > 2;
        }

        const y = isHigh ? yHigh : yBase;

        if (lastLevel === null) {
          logicCtx.moveTo(x, y);
        } else if (lastLevel !== y) {
          // Sharp vertical transition edge
          logicCtx.lineTo(x, lastLevel);
          logicCtx.lineTo(x, y);
        } else {
          logicCtx.lineTo(x, y);
        }
        lastLevel = y;
      }
      logicCtx.stroke();

      // Instantaneous Hex State on Right
      const sampleAtTrig = trigX + logicShift + ch.offset;
      const bitVal = ((Math.floor(sampleAtTrig / ch.period) * 37 + idx) % 2);
      logicCtx.fillStyle = '#b8a998';
      logicCtx.font = "8px 'VCR OSD Mono', monospace";
      logicCtx.fillText(bitVal ? "1" : "0", endX + 8, yBase - 1);
    });

    // Hex Bus Decode byte at bottom right
    const busByte = ((Math.floor(logicShift / 16) * 43) % 256).toString(16).toUpperCase().padStart(2, '0');
    logicCtx.fillStyle = '#d4944c';
    logicCtx.font = "bold 8.5px 'VCR OSD Mono', monospace";
    logicCtx.fillText(`0x${busByte}`, endX + 18, h - 6);
  }

  // ═════════════════════════════════════════════════════════════════
  // ═════════════════════════════════════════════════════════════════
  // 5. AUDIO MASTERING STEREO GONIOMETER & PHASE VECTORSCOPE (Bay 4)
  // ═════════════════════════════════════════════════════════════════

  const gonioCanvas = document.getElementById('goniometer-canvas');
  let gonioCtx = gonioCanvas ? gonioCanvas.getContext('2d') : null;
  let gonioW = 0, gonioH = 0;
  let gonioTime = 0;
  let stereoWidthFactor = 1.0;

  function initGoniometer() {
    if (!gonioCanvas || !gonioCtx) return;
    const rect = gonioCanvas.getBoundingClientRect();
    gonioCanvas.width = rect.width > 0 ? rect.width : 340;
    gonioCanvas.height = rect.height > 0 ? rect.height : 125;
    gonioW = gonioCanvas.width;
    gonioH = gonioCanvas.height;
  }

  function renderGoniometer() {
    if (!gonioCtx) return;
    if (gonioCanvas.width === 0 || gonioW === 0) {
      initGoniometer();
    }
    const w = gonioW || 340;
    const h = gonioH || 125;
    gonioTime += 0.06;

    // High-retention phosphor fade
    gonioCtx.fillStyle = 'rgba(5, 5, 5, 0.32)';
    gonioCtx.fillRect(0, 0, w, h);

    const cx = w / 2;
    const cy = h / 2 - 4;
    const r = Math.min(cx, cy) - 8;
    const cos45 = 0.7071;

    // 1. Polar Circle & Diagonal Graticule
    gonioCtx.strokeStyle = 'rgba(80, 70, 56, 0.45)';
    gonioCtx.lineWidth = 1;

    gonioCtx.beginPath();
    gonioCtx.arc(cx, cy, r, 0, Math.PI * 2);
    gonioCtx.arc(cx, cy, r * 0.5, 0, Math.PI * 2);
    gonioCtx.stroke();

    // 45° L/R axes & M/S crosshair
    gonioCtx.setLineDash([2, 3]);
    gonioCtx.beginPath();
    // +45° line (+L axis)
    gonioCtx.moveTo(cx - r * cos45, cy + r * cos45);
    gonioCtx.lineTo(cx + r * cos45, cy - r * cos45);
    // -45° line (+R axis)
    gonioCtx.moveTo(cx - r * cos45, cy - r * cos45);
    gonioCtx.lineTo(cx + r * cos45, cy + r * cos45);
    // Vertical M (Mid/Mono) & Horizontal S (Side/Stereo)
    gonioCtx.moveTo(cx, cy - r);
    gonioCtx.lineTo(cx, cy + r);
    gonioCtx.moveTo(cx - r, cy);
    gonioCtx.lineTo(cx + r, cy);
    gonioCtx.stroke();
    gonioCtx.setLineDash([]);

    // 2. Graticule Labels
    gonioCtx.fillStyle = 'rgba(184, 169, 152, 0.75)';
    gonioCtx.font = "7.5px 'VCR OSD Mono', monospace";
    gonioCtx.fillText("+L", cx - r * cos45 - 2, cy - r * cos45 + 10);
    gonioCtx.fillText("+R", cx + r * cos45 - 12, cy - r * cos45 + 10);
    gonioCtx.fillText("M (MID)", cx - 14, cy - r + 9);
    gonioCtx.fillText("S", cx + r - 8, cy - 2);

    // 3. Dynamic Stereo Lissajous Vectorscope Trace
    const numPoints = 72;
    gonioCtx.beginPath();
    gonioCtx.strokeStyle = '#d4944c';
    gonioCtx.lineWidth = 1.3;

    for (let i = 0; i < numPoints; i++) {
      const t = gonioTime + i * 0.14;
      const sigL = Math.sin(t * 1.7) * 0.52 + Math.sin(t * 3.1 + 0.3) * 0.32 + Math.cos(t * 5.4) * 0.16;
      const sigR = Math.sin(t * 1.7 + 0.22) * 0.52 * stereoWidthFactor + Math.sin(t * 3.1 - 0.25) * 0.32 + Math.sin(t * 7.2) * 0.12;

      // 45° rotation for Goniometer: X = (R - L) * cos45, Y = -(L + R) * cos45
      const x = cx + ((sigR - sigL) * cos45 * stereoWidthFactor) * (r * 0.82);
      const y = cy - ((sigL + sigR) * cos45) * (r * 0.82);

      if (i === 0) gonioCtx.moveTo(x, y);
      else gonioCtx.lineTo(x, y);
    }
    gonioCtx.stroke();

    // Secondary soft phosphor glow trace
    gonioCtx.strokeStyle = 'rgba(212, 148, 76, 0.25)';
    gonioCtx.lineWidth = 3.5;
    gonioCtx.stroke();

    // 4. Phase Correlation Meter at bottom
    const meterY = cy + r + 2;
    const meterW = r * 1.35;
    const meterX = cx - meterW / 2;

    gonioCtx.fillStyle = '#100e0b';
    gonioCtx.fillRect(meterX, meterY, meterW, 4);
    gonioCtx.strokeStyle = '#3a3228';
    gonioCtx.strokeRect(meterX, meterY, meterW, 4);

    const phaseVal = 0.86 + Math.sin(gonioTime * 0.6) * 0.08;
    const zeroX = meterX + meterW / 2;
    const needleX = meterX + ((phaseVal + 1) / 2) * meterW;

    gonioCtx.fillStyle = '#88aa88';
    gonioCtx.fillRect(zeroX, meterY + 1, Math.max(0, needleX - zeroX), 2);

    gonioCtx.fillStyle = '#b8a998';
    gonioCtx.font = "6.5px 'VCR OSD Mono', monospace";
    gonioCtx.fillText("-1", meterX - 8, meterY + 4);
    gonioCtx.fillText("0", zeroX - 2, meterY + 9);
    gonioCtx.fillText("+1", meterX + meterW + 2, meterY + 4);
  }

  // ═════════════════════════════════════════════════════════════════
  // 6. ANIMATION LOOP & CONTROLS
  // ═════════════════════════════════════════════════════════════════

  let lastFrameTime = 0;

  function renderAllVectors(timestamp) {
    if (!isRunning) return;

    if (!timestamp) timestamp = performance.now();
    const elapsed = timestamp - lastFrameTime;
    // Cap at 30 FPS (~33ms) for silky motion without CPU load
    if (elapsed < 33) {
      animId = requestAnimationFrame(renderAllVectors);
      return;
    }
    lastFrameTime = timestamp;

    renderLissajous();
    renderBandwidthScope();
    renderTouchpadScope();
    renderGoniometer();

    if (isRunning) {
      animId = requestAnimationFrame(renderAllVectors);
    }
  }

  function start() {
    if (isRunning) return;
    isRunning = true;
    initLissajous();
    initBandwidthScope();
    initTouchpadScope();
    initGoniometer();
    animId = requestAnimationFrame(renderAllVectors);
  }

  function stop() {
    isRunning = false;
    if (animId) {
      cancelAnimationFrame(animId);
      animId = null;
    }
  }

  // Window resize handler
  window.addEventListener('resize', () => {
    initLissajous();
    initBandwidthScope();
    initTouchpadScope();
    initGoniometer();
  });

  // UI Button Listeners for Scope Mode (Persisted)
  document.querySelectorAll('.btn-scope-mode').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.btn-scope-mode').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      lissMode = btn.dataset.mode || 'lissajous';
      try { localStorage.setItem('trv30_liss_mode', lissMode); } catch(e){}
    });
  });

  // Restore saved scope mode
  try {
    const savedLiss = localStorage.getItem('trv30_liss_mode');
    if (savedLiss) {
      const b = document.querySelector(`.btn-scope-mode[data-mode="${savedLiss}"]`);
      if (b) {
        document.querySelectorAll('.btn-scope-mode').forEach(x => x.classList.remove('active'));
        b.classList.add('active');
        lissMode = savedLiss;
      }
    }
  } catch(e){}

  // Stereo Width Button Listeners (Persisted)
  document.querySelectorAll('.m-mini-btn[data-width]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.m-mini-btn[data-width]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const w = btn.dataset.width;
      if (w === 'mono') stereoWidthFactor = 0.0;
      else if (w === 'wide') stereoWidthFactor = 1.4;
      else stereoWidthFactor = 1.0;
      try { localStorage.setItem('trv30_stereo_width', w); } catch(e){}
    });
  });

  // Restore saved stereo width
  try {
    const savedWidth = localStorage.getItem('trv30_stereo_width');
    if (savedWidth) {
      const b = document.querySelector(`.m-mini-btn[data-width="${savedWidth}"]`);
      if (b) {
        document.querySelectorAll('.m-mini-btn[data-width]').forEach(x => x.classList.remove('active'));
        b.classList.add('active');
        if (savedWidth === 'mono') stereoWidthFactor = 0.0;
        else if (savedWidth === 'wide') stereoWidthFactor = 1.4;
        else stereoWidthFactor = 1.0;
      }
    }
  } catch(e){}

  // Export control interface
  window.VectorLab = {
    start,
    stop,
    isRunning: () => isRunning,
    setLissMode: (m) => { lissMode = m; },
    setLissajousMode: (m) => { lissMode = m; },
    setSpeed: (s) => { lissSpeed = s; },
    setStereoWidth: (w) => { stereoWidthFactor = w; },
    pushBandwidth
  };

  // Auto-start on load if deck is visible
  setTimeout(() => {
    start();
  }, 100);

})();
