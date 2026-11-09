/* ═══════════════════════════════════════════════════════════════════
 *  TOKYO 80S TRV30 MASTER DECK — JAVASCRIPT CONTROLLER
 *  Coordinates ASCII Engine, Tape Physics, Hardware Controls, and Python IPC
 * ═══════════════════════════════════════════════════════════════════ */

(function() {
  'use strict';

  // IPC Bridge Helper
  function sendHost(msg) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.host) {
      window.webkit.messageHandlers.host.postMessage(msg);
    } else {
      console.log("[IPC Mock]", msg);
    }
  }

  // ─── CLOCK RUNNER ───
  function updateClock() {
    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-US', { hour12: true });
    const clockEl = document.getElementById('clock-timecode');
    if (clockEl) clockEl.textContent = timeStr;
  }
  setInterval(updateClock, 1000);
  updateClock();

  // ─── WEBCAM & PRIVACY SWITCH (ASCII ENGINE INTEGRATION) ───
  const btnShutter = document.getElementById('btn-shutter-toggle');
  const shutterLabel = document.getElementById('shutter-label');
  const recIndicator = document.getElementById('rec-indicator');
  const recStatusText = document.getElementById('rec-status-text');
  const vfStatusTag = document.getElementById('vf-status-tag');

  async function toggleCamera() {
    if (!window.AsciiEngine) return;
    if (window.AsciiEngine.isCameraActive()) {
      window.AsciiEngine.disengageCamera();
      btnShutter.classList.remove('active-rec');
      shutterLabel.textContent = 'ENGAGE CAMERA (REC)';
      recIndicator.classList.remove('recording');
      recStatusText.textContent = 'STBY';
      if (vfStatusTag) {
        vfStatusTag.className = 'vf-pill-stby';
        vfStatusTag.textContent = 'TAPE: SP';
      }
    } else {
      try {
        shutterLabel.textContent = 'INITIALIZING...';
        await window.AsciiEngine.engageCamera();
        btnShutter.classList.add('active-rec');
        shutterLabel.textContent = 'DISENGAGE (PRIVACY)';
        recIndicator.classList.add('recording');
        recStatusText.textContent = '● REC';
        if (vfStatusTag) {
          vfStatusTag.className = 'vf-pill-rec';
          vfStatusTag.textContent = '● REC';
        }
      } catch (err) {
        console.error("Camera engage failed:", err);
        btnShutter.classList.remove('active-rec');
        shutterLabel.textContent = 'CAMERA ERROR';
        setTimeout(() => {
          shutterLabel.textContent = 'ENGAGE CAMERA (REC)';
        }, 2000);
      }
    }
  }

  if (btnShutter) {
    btnShutter.addEventListener('click', toggleCamera);
  }

  // Camera ASCII Style Selectors
  document.querySelectorAll('.cam-style-toggles .style-pill').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.cam-style-toggles .style-pill').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const style = btn.dataset.style;
      if (window.AsciiEngine) {
        window.AsciiEngine.setStyle(style);
      }
    });
  });

  // ─── TAPE CASSETTE DYNAMICS ───
  const spoolLeft = document.getElementById('spool-left');
  const spoolRight = document.getElementById('spool-right');
  const ribbonLeft = document.getElementById('tape-ribbon-left');
  const ribbonRight = document.getElementById('tape-ribbon-right');
  const trackTitle = document.getElementById('track-title');
  const trackArtist = document.getElementById('track-artist');
  const tapeTimecode = document.getElementById('tape-timecode');
  const btnPlayPause = document.getElementById('btn-play-pause');

  function updateTapePhysics(media) {
    if (!media) return;

    if (trackTitle) trackTitle.textContent = media.title || "Insert Tape / Start Music";
    if (trackArtist) trackArtist.textContent = media.artist || "Cassette Idle";

    const isPlaying = (media.status === "Playing");
    if (spoolLeft && spoolRight) {
      if (isPlaying) {
        spoolLeft.classList.add('spinning');
        spoolRight.classList.add('spinning');
        if (btnPlayPause) btnPlayPause.textContent = "❚❚ PAUSE";
      } else {
        spoolLeft.classList.remove('spinning');
        spoolRight.classList.remove('spinning');
        if (btnPlayPause) btnPlayPause.textContent = "▶ PLAY";
      }
    }

    // Dynamic ribbon thickness transfer for bigger spools (74px down to 46px)
    const prog = media.progress !== undefined ? media.progress : 0.0;
    const leftSize = Math.round(74 - (prog * 28));  // 74px down to 46px
    const rightSize = Math.round(46 + (prog * 28)); // 46px up to 74px

    if (ribbonLeft) {
      ribbonLeft.style.width = `${leftSize}px`;
      ribbonLeft.style.height = `${leftSize}px`;
    }
    if (ribbonRight) {
      ribbonRight.style.width = `${rightSize}px`;
      ribbonRight.style.height = `${rightSize}px`;
    }

    if (tapeTimecode && media.pos_str) {
      tapeTimecode.textContent = `${media.pos_str} [TAPE]`;
    }
  }

  // Transport Click Handlers
  document.getElementById('btn-prev')?.addEventListener('click', () => sendHost({ action: 'media', cmd: 'previous' }));
  document.getElementById('btn-next')?.addEventListener('click', () => sendHost({ action: 'media', cmd: 'next' }));
  btnPlayPause?.addEventListener('click', () => sendHost({ action: 'media', cmd: 'play-pause' }));

  // ─── FADERS & VU METERS ───
  const sliderVol = document.getElementById('slider-vol');
  const volVal = document.getElementById('vol-val');
  const sliderBright = document.getElementById('slider-bright');
  const brightVal = document.getElementById('bright-val');

  function updateVuLadder(container, pct) {
    if (!container) return;
    const leds = container.querySelectorAll('.vu-led');
    const total = leds.length;
    const litCount = Math.round((pct / 100) * total);

    // LEDs arranged top to bottom: [red peak, amber, amber, normal...]
    leds.forEach((led, idx) => {
      const bottomIdx = total - 1 - idx;
      if (bottomIdx < litCount) led.classList.add('on');
      else led.classList.remove('on');
    });
  }

  if (sliderVol) {
    sliderVol.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      if (volVal) volVal.textContent = `${val}%`;
      updateVuLadder(sliderVol.parentElement?.querySelector('.vu-meter-ladder'), val);
      sendHost({ action: 'set_volume', value: val });
    });
  }

  if (sliderBright) {
    sliderBright.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      if (brightVal) brightVal.textContent = `${val}%`;
      updateVuLadder(sliderBright.parentElement?.querySelector('.vu-meter-ladder'), val);
      sendHost({ action: 'set_brightness', value: val });
    });
  }

  // Bass & Treble Sliders
  const sliderBass = document.getElementById('slider-bass');
  const bassVal = document.getElementById('bass-val');
  const sliderTreb = document.getElementById('slider-treb');
  const trebVal = document.getElementById('treb-val');

  if (sliderBass) {
    sliderBass.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      if (bassVal) bassVal.textContent = (val >= 0 ? `+${val}` : `${val}`) + 'dB';
      const pct = Math.round(((val + 12) / 24) * 100);
      updateVuLadder(sliderBass.parentElement?.querySelector('.vu-meter-ladder'), pct);
    });
  }

  if (sliderTreb) {
    sliderTreb.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      if (trebVal) trebVal.textContent = (val >= 0 ? `+${val}` : `${val}`) + 'dB';
      const pct = Math.round(((val + 12) / 24) * 100);
      updateVuLadder(sliderTreb.parentElement?.querySelector('.vu-meter-ladder'), pct);
    });
  }

  // ─── TAPE COUNTER & FOCUS POMODORO ───
  let tapeCounter = 0;
  let pomoActive = false;
  let pomoSecLeft = 25 * 60;
  let pomoTimer = null;
  const counterVal = document.getElementById('tape-counter-val');
  const btnCounterReset = document.getElementById('btn-counter-reset');
  const btnPomo = document.getElementById('btn-pomo-toggle');

  btnCounterReset?.addEventListener('click', () => {
    tapeCounter = 0;
    if (counterVal) counterVal.textContent = "0000";
  });

  btnPomo?.addEventListener('click', () => {
    pomoActive = !pomoActive;
    if (pomoActive) {
      btnPomo.classList.add('active');
      pomoSecLeft = 25 * 60;
      if (pomoTimer) clearInterval(pomoTimer);
      pomoTimer = setInterval(() => {
        if (!pomoActive) return;
        pomoSecLeft--;
        if (pomoSecLeft <= 0) {
          pomoActive = false;
          btnPomo.classList.remove('active');
          clearInterval(pomoTimer);
          if (counterVal) counterVal.textContent = "DONE";
          sendHost({ action: 'sys_action', cmd: 'drop_caches' });
        } else {
          const m = String(Math.floor(pomoSecLeft / 60)).padStart(2, '0');
          const s = String(pomoSecLeft % 60).padStart(2, '0');
          if (counterVal) counterVal.textContent = `${m}:${s}`;
        }
      }, 1000);
    } else {
      btnPomo.classList.remove('active');
      if (pomoTimer) clearInterval(pomoTimer);
      if (counterVal) counterVal.textContent = String(tapeCounter).padStart(4, '0');
    }
  });

  // ─── OPTIMISTIC LATCH STATE ENGINE & PERSISTENCE ───
  const userLocks = {};
  function setLock(key, ms = 4500) {
    userLocks[key] = Date.now() + ms;
  }
  function isLocked(key) {
    return (userLocks[key] && Date.now() < userLocks[key]);
  }
  function savePref(k, v) {
    try { localStorage.setItem('trv30_' + k, String(v)); } catch(e){}
  }
  function getPref(k, def) {
    try {
      const v = localStorage.getItem('trv30_' + k);
      return v !== null ? v : def;
    } catch(e) { return def; }
  }

  // ─── BAY 01: COLOR TEMP & NIGHT WARMTH HANGER ───
  document.querySelectorAll('.kelvin-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.kelvin-btn').forEach(b => {
        b.classList.remove('active');
        b.querySelector('.latch-led')?.classList.remove('on');
      });
      btn.classList.add('active');
      btn.querySelector('.latch-led')?.classList.add('on');
      const k = btn.dataset.kelvin;
      const sh = btn.dataset.shader;
      const readout = document.getElementById('kelvin-readout');
      if (readout) readout.textContent = `${k}K [LATCHED]`;
      setLock('crt_mode', 6000);
      savePref('kelvin', k);
      savePref('crt_shader', sh);
      sendHost({ action: 'set_shader', mode: sh });
    });
  });

  // ─── BAY 02: RADIO & COMM-LINK SWITCHBOARD ───
  const btnWifi = document.getElementById('btn-toggle-wifi');
  const btnBt = document.getElementById('btn-toggle-bt');
  const btnAirplane = document.getElementById('btn-toggle-airplane');
  const btnDnd = document.getElementById('btn-toggle-dnd');

  btnWifi?.addEventListener('click', () => {
    const isAct = !btnWifi.classList.contains('active');
    btnWifi.classList.toggle('active', isAct);
    btnWifi.querySelector('.latch-led')?.classList.toggle('on', isAct);
    setLock('wifi', 4000);
    savePref('wifi', isAct ? '1' : '0');
    sendHost({ action: 'toggle_wifi' });
  });

  btnBt?.addEventListener('click', () => {
    const isAct = !btnBt.classList.contains('active');
    btnBt.classList.toggle('active', isAct);
    btnBt.querySelector('.latch-led')?.classList.toggle('on', isAct);
    setLock('bt', 4000);
    savePref('bt', isAct ? '1' : '0');
    sendHost({ action: 'toggle_bt' });
  });

  btnAirplane?.addEventListener('click', () => {
    const isAct = !btnAirplane.classList.contains('active');
    btnAirplane.classList.toggle('active', isAct);
    btnAirplane.querySelector('.latch-led')?.classList.toggle('on', isAct);
    if (isAct) {
      btnWifi?.classList.remove('active');
      btnWifi?.querySelector('.latch-led')?.classList.remove('on');
      btnBt?.classList.remove('active');
      btnBt?.querySelector('.latch-led')?.classList.remove('on');
    }
    setLock('wifi', 4000);
    setLock('bt', 4000);
    sendHost({ action: 'toggle_airplane' });
  });

  btnDnd?.addEventListener('click', () => {
    const isAct = !btnDnd.classList.contains('active');
    btnDnd.classList.toggle('active', isAct);
    btnDnd.querySelector('.latch-led')?.classList.toggle('on', isAct);
    setLock('dnd', 4000);
    savePref('dnd', isAct ? '1' : '0');
    sendHost({ action: 'toggle_dnd' });
  });

  document.getElementById('btn-ping-probe')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 600);
    sendHost({ action: 'ping_test' });
  });

  document.getElementById('btn-flush-dns')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 600);
    sendHost({ action: 'flush_dns' });
  });

  document.getElementById('btn-quick-ping')?.addEventListener('click', () => sendHost({ action: 'ping_test' }));
  document.getElementById('btn-quick-dns')?.addEventListener('click', () => sendHost({ action: 'flush_dns' }));
  document.getElementById('btn-quick-rescan')?.addEventListener('click', () => {
    sendHost({ action: 'rescan_wifi' });
  });

  document.querySelectorAll('.sys-act-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const act = btn.dataset.act;
      btn.classList.add('active');
      setTimeout(() => btn.classList.remove('active'), 400);
      sendHost({ action: 'sys_action', cmd: act });
    });
  });

  // ─── BAY 03: TOUCHPAD & INPUT HARDWARE MATRIX ───
  document.querySelectorAll('.latch-toggle-btn[data-touch]').forEach(btn => {
    btn.addEventListener('click', () => {
      const param = btn.dataset.touch;
      const isAct = !btn.classList.contains('active');
      btn.classList.toggle('active', isAct);
      btn.querySelector('.latch-led')?.classList.toggle('on', isAct);
      setLock('touch_' + param, 5000);
      savePref('touch_' + param, isAct ? '1' : '0');
      sendHost({ action: 'set_touchpad', param: param, value: isAct });
    });
  });

  document.querySelectorAll('#cursor-timeout-group .tri-opt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#cursor-timeout-group .tri-opt-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const val = btn.dataset.timeout;
      setLock('cursor_timeout', 5000);
      savePref('cursor_timeout', val);
      sendHost({ action: 'set_cursor_timeout', value: val });
    });
  });

  // ─── BAY 03: POWER GOVERNOR & CAFFEINE SLEEP INHIBITOR ───
  const btnCaffeine = document.getElementById('btn-caffeine-toggle');
  const caffeineLed = document.getElementById('caffeine-led');
  const caffeineBadge = document.getElementById('caffeine-status-badge');
  const caffeineDesc = document.getElementById('caffeine-desc');

  btnCaffeine?.addEventListener('click', () => {
    const isAct = !btnCaffeine.classList.contains('active');
    btnCaffeine.classList.toggle('active', isAct);
    caffeineLed?.classList.toggle('on', isAct);
    if (isAct) {
      if (caffeineBadge) caffeineBadge.textContent = "CAFFEINE: ACTIVE";
      if (caffeineDesc) caffeineDesc.textContent = "SLEEP & LOCK INHIBITED";
    } else {
      if (caffeineBadge) caffeineBadge.textContent = "IDLE: ARMED";
      if (caffeineDesc) caffeineDesc.textContent = "CLICK TO INHIBIT SLEEP & LOCK";
    }
    setLock('caffeine', 5000);
    savePref('caffeine', isAct ? '1' : '0');
    sendHost({ action: 'set_caffeine', enabled: isAct });
  });

  document.querySelectorAll('#gov-profile-group .tri-btn[data-pwr]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#gov-profile-group .tri-btn[data-pwr]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const pwr = btn.dataset.pwr;
      setLock('power_mode', 5000);
      savePref('power_mode', pwr);
      sendHost({ action: 'set_power', profile: pwr });
    });
  });

  // ─── BAY 03: HYPRLAND COMPOSITOR FX ENGINE ───
  document.querySelectorAll('#fx-anim-group .comp-opt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#fx-anim-group .comp-opt-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      savePref('fx_anim', btn.dataset.anim);
      sendHost({ action: 'set_compositor_fx', fx: 'animations', value: btn.dataset.anim });
    });
  });

  document.querySelectorAll('#fx-blur-group .comp-opt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#fx-blur-group .comp-opt-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      savePref('fx_blur', btn.dataset.blur);
      sendHost({ action: 'set_compositor_fx', fx: 'blur', value: btn.dataset.blur });
    });
  });

  document.querySelectorAll('#fx-gaps-group .comp-opt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#fx-gaps-group .comp-opt-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      savePref('fx_gaps', btn.dataset.gaps);
      sendHost({ action: 'set_compositor_fx', fx: 'gaps', value: btn.dataset.gaps });
    });
  });

  document.querySelectorAll('#fx-round-group .comp-opt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#fx-round-group .comp-opt-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      savePref('fx_round', btn.dataset.round);
      sendHost({ action: 'set_compositor_fx', fx: 'rounding', value: btn.dataset.round });
    });
  });

  // ─── BAY 03: RECOVERY ACTIONS ───
  document.getElementById('btn-purge-browser')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 500);
    sendHost({ action: 'kill_runaways' });
  });

  document.getElementById('btn-restart-waybar')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 500);
    sendHost({ action: 'sys_action', cmd: 'restart_waybar' });
  });

  document.getElementById('btn-reload-hypr')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 500);
    sendHost({ action: 'sys_action', cmd: 'reload_hypr' });
  });

  document.getElementById('btn-flush-buffers')?.addEventListener('click', (e) => {
    const b = e.currentTarget;
    b.classList.add('active');
    setTimeout(() => b.classList.remove('active'), 500);
    sendHost({ action: 'sys_action', cmd: 'drop_caches' });
  });

  // ─── BAY 04: STUDIO HARDWARE MIXING & MASTERING ───
  const swBtMusic = document.getElementById('sw-bt-music');
  const swBtCall = document.getElementById('sw-bt-call');

  swBtMusic?.addEventListener('click', () => {
    swBtCall?.classList.remove('active');
    swBtMusic.classList.add('active');
    setLock('audio_mode', 5000);
    savePref('audio_mode', 'music');
    sendHost({ action: 'set_audio_profile', mode: 'music' });
  });

  swBtCall?.addEventListener('click', () => {
    swBtMusic?.classList.remove('active');
    swBtCall.classList.add('active');
    setLock('audio_mode', 5000);
    savePref('audio_mode', 'call');
    sendHost({ action: 'set_audio_profile', mode: 'call' });
  });

  document.getElementById('btn-toggle-mic')?.addEventListener('click', () => {
    sendHost({ action: 'toggle_mic' });
  });

  // Tri-state CRT shader
  document.querySelectorAll('.switch-tri-state .tri-btn[data-mode]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-mode]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const mode = btn.dataset.mode;
      setLock('crt_mode', 5000);
      savePref('crt_shader', mode);
      sendHost({ action: 'set_shader', mode: mode });
    });
  });

  // Tri-state Power Profile (syncs with Bay 3)
  document.querySelectorAll('.switch-tri-state .tri-btn[data-pwr]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-pwr]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const profile = btn.dataset.pwr;
      setLock('power_mode', 5000);
      savePref('power_mode', profile);
      sendHost({ action: 'set_power', profile: profile });
    });
  });

  // Audio Mastering Processor Controls
  const btnTapeWarmth = document.getElementById('btn-tape-warmth');
  btnTapeWarmth?.addEventListener('click', () => {
    btnTapeWarmth.classList.toggle('active');
    savePref('tape_warmth', btnTapeWarmth.classList.contains('active') ? '1' : '0');
  });

  document.querySelectorAll('.m-mini-btn[data-limit]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.m-mini-btn[data-limit]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      savePref('limiter', btn.dataset.limit);
    });
  });

  // ─── OVERLOAD VS MINIMALIST COCKPIT MODE ───
  let currentDeckMode = getPref('deck_mode', 'overload');
  let isDeckVisible = true;

  function setDeckMode(mode) {
    currentDeckMode = mode;
    savePref('deck_mode', mode);

    const btnOverload = document.getElementById('btn-mode-overload');
    const btnMinimal = document.getElementById('btn-mode-minimal');

    if (mode === 'minimal') {
      document.body.classList.remove('mode-overload');
      document.body.classList.add('mode-minimal');
      btnOverload?.classList.remove('active');
      btnMinimal?.classList.add('active');
      if (window.VectorLab) window.VectorLab.stop();
    } else {
      document.body.classList.remove('mode-minimal');
      document.body.classList.add('mode-overload');
      btnMinimal?.classList.remove('active');
      btnOverload?.classList.add('active');
      if (window.VectorLab && isDeckVisible) window.VectorLab.start();
    }
  }

  function toggleDeckMode() {
    setDeckMode(currentDeckMode === 'minimal' ? 'overload' : 'minimal');
  }

  document.getElementById('btn-mode-overload')?.addEventListener('click', () => setDeckMode('overload'));
  document.getElementById('btn-mode-minimal')?.addEventListener('click', () => setDeckMode('minimal'));
  document.getElementById('btn-master-close')?.addEventListener('click', () => sendHost({ action: 'close' }));

  // Initialize saved mode
  setDeckMode(currentDeckMode);

  window.setDeckMode = setDeckMode;
  window.toggleDeckMode = toggleDeckMode;

  // ─── TAPE LIBRARY (THEME SWITCHER) ───
  document.querySelectorAll('.tape-cartridge').forEach(tape => {
    tape.addEventListener('click', () => {
      const theme = tape.dataset.theme;
      document.querySelectorAll('.tape-cartridge').forEach(t => {
        t.classList.remove('active');
        t.querySelector('.tape-status-led')?.classList.remove('on');
      });
      tape.classList.add('active');
      tape.querySelector('.tape-status-led')?.classList.add('on');

      document.body.classList.remove('theme-trv30', 'theme-cyber', 'theme-pvm', 'theme-nerv');
      document.body.classList.add(`theme-${theme}`);
      savePref('theme', theme);
      sendHost({ action: 'set_theme', theme: theme });
    });
  });

  // Restore saved theme
  const savedTheme = getPref('theme', 'trv30');
  const savedTapeEl = document.querySelector(`.tape-cartridge[data-theme="${savedTheme}"]`);
  if (savedTapeEl) {
    document.querySelectorAll('.tape-cartridge').forEach(t => {
      t.classList.remove('active');
      t.querySelector('.tape-status-led')?.classList.remove('on');
    });
    savedTapeEl.classList.add('active');
    savedTapeEl.querySelector('.tape-status-led')?.classList.add('on');
    document.body.classList.remove('theme-trv30', 'theme-cyber', 'theme-pvm', 'theme-nerv');
    document.body.classList.add(`theme-${savedTheme}`);
  }

  // Restore other saved preferences on startup
  function restoreSavedPrefs() {
    const savedKelvin = getPref('kelvin', null);
    if (savedKelvin) {
      const b = document.querySelector(`.kelvin-btn[data-kelvin="${savedKelvin}"]`);
      if (b) {
        document.querySelectorAll('.kelvin-btn').forEach(x => {
          x.classList.remove('active');
          x.querySelector('.latch-led')?.classList.remove('on');
        });
        b.classList.add('active');
        b.querySelector('.latch-led')?.classList.add('on');
        const readout = document.getElementById('kelvin-readout');
        if (readout) readout.textContent = `${savedKelvin}K [LATCHED]`;
      }
    }

    const savedCrt = getPref('crt_shader', null);
    if (savedCrt) {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-mode]').forEach(b => {
        b.classList.toggle('active', b.dataset.mode === savedCrt);
      });
    }

    const savedPwr = getPref('power_mode', null);
    if (savedPwr) {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-pwr]').forEach(b => {
        b.classList.toggle('active', b.dataset.pwr === savedPwr);
      });
    }

    const savedTimeout = getPref('cursor_timeout', null);
    if (savedTimeout) {
      document.querySelectorAll('#cursor-timeout-group .tri-opt-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.timeout === savedTimeout);
      });
    }

    const savedCaff = getPref('caffeine', null);
    if (savedCaff === '1') {
      btnCaffeine?.classList.add('active');
      caffeineLed?.classList.add('on');
      if (caffeineBadge) caffeineBadge.textContent = "CAFFEINE: ACTIVE";
      if (caffeineDesc) caffeineDesc.textContent = "SLEEP & LOCK INHIBITED";
    }

    const savedLimiter = getPref('limiter', null);
    if (savedLimiter) {
      document.querySelectorAll('.m-mini-btn[data-limit]').forEach(b => {
        b.classList.toggle('active', b.dataset.limit === savedLimiter);
      });
    }

    const savedWarmth = getPref('tape_warmth', null);
    if (savedWarmth !== null && btnTapeWarmth) {
      btnTapeWarmth.classList.toggle('active', savedWarmth === '1');
    }

    ['tap_to_click', 'tap_and_drag', 'drag_lock', 'natural_scroll'].forEach(p => {
      const v = getPref('touch_' + p, null);
      if (v !== null) {
        const b = document.querySelector(`.latch-toggle-btn[data-touch="${p}"]`);
        if (b) {
          const isAct = (v === '1');
          b.classList.toggle('active', isAct);
          b.querySelector('.latch-led')?.classList.toggle('on', isAct);
        }
      }
    });

    ['anim', 'blur', 'gaps', 'round'].forEach(fx => {
      const v = getPref('fx_' + fx, null);
      if (v !== null) {
        const b = document.querySelector(`#fx-${fx}-group .comp-opt-btn[data-${fx}="${v}"]`);
        if (b) {
          document.querySelectorAll(`#fx-${fx}-group .comp-opt-btn`).forEach(x => x.classList.remove('active'));
          b.classList.add('active');
        }
      }
    });
  }
  restoreSavedPrefs();

  // ─── CLOSE BUTTON & PHYSICAL KEYBOARD SHORTCUTS ───
  document.getElementById('btn-close')?.addEventListener('click', () => sendHost({ action: 'close' }));

  window.addEventListener('keydown', (e) => {
    if (e.target && e.target.tagName === 'INPUT' && e.key !== 'Escape') {
      return;
    }

    if (e.key === 'Escape') {
      sendHost({ action: 'close' });
    } else if (e.key === 'Tab') {
      e.preventDefault();
      toggleDeckMode();
    } else if (e.key === ' ') {
      e.preventDefault();
      sendHost({ action: 'media', cmd: 'play-pause' });
    } else if (e.key === 'c' || e.key === 'C') {
      toggleCamera();
    } else if (e.key === '1') {
      document.querySelector('.tape-cartridge[data-theme="trv30"]')?.click();
    } else if (e.key === '2') {
      document.querySelector('.tape-cartridge[data-theme="cyber"]')?.click();
    } else if (e.key === '3') {
      document.querySelector('.tape-cartridge[data-theme="pvm"]')?.click();
    } else if (e.key === '4') {
      document.querySelector('.tape-cartridge[data-theme="nerv"]')?.click();
    } else if (e.key === 'm' || e.key === 'M') {
      e.preventDefault();
      toggleDeckMode();
    } else if (e.key === 's' || e.key === 'S') {
      const crtBtns = Array.from(document.querySelectorAll('.switch-tri-state .tri-btn[data-mode]'));
      const activeIdx = crtBtns.findIndex(b => b.classList.contains('active'));
      const nextIdx = (activeIdx + 1) % (crtBtns.length || 1);
      crtBtns[nextIdx]?.click();
    }
  });

  // ─── BTOP TELEMETRY SUITE CONTROLLERS ───
  const cpuSparkCanvas = document.getElementById('cpu-sparkline-canvas');
  const cpuSparkCtx = cpuSparkCanvas ? cpuSparkCanvas.getContext('2d') : null;
  const cpuHist = [];

  function drawCpuSparkline(usage) {
    if (!cpuSparkCtx || !cpuSparkCanvas) return;
    cpuHist.push(usage);
    if (cpuHist.length > 40) cpuHist.shift();

    const w = cpuSparkCanvas.width;
    const h = cpuSparkCanvas.height;
    cpuSparkCtx.clearRect(0, 0, w, h);

    // Subtle grid lines
    cpuSparkCtx.strokeStyle = 'rgba(212, 148, 76, 0.15)';
    cpuSparkCtx.lineWidth = 1;
    cpuSparkCtx.beginPath();
    cpuSparkCtx.moveTo(0, h * 0.5); cpuSparkCtx.lineTo(w, h * 0.5);
    cpuSparkCtx.stroke();

    if (cpuHist.length < 2) return;

    // Waveform line
    cpuSparkCtx.beginPath();
    const step = w / (cpuHist.length - 1);
    cpuHist.forEach((v, i) => {
      const x = i * step;
      const y = h - (v / 100) * (h - 4) - 2;
      if (i === 0) cpuSparkCtx.moveTo(x, y);
      else cpuSparkCtx.lineTo(x, y);
    });
    cpuSparkCtx.strokeStyle = '#d4944c';
    cpuSparkCtx.lineWidth = 1.5;
    cpuSparkCtx.stroke();

    // Gradient fill under waveform
    const grad = cpuSparkCtx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, 'rgba(212, 148, 76, 0.35)');
    grad.addColorStop(1, 'rgba(212, 148, 76, 0.02)');
    cpuSparkCtx.lineTo(w, h);
    cpuSparkCtx.lineTo(0, h);
    cpuSparkCtx.closePath();
    cpuSparkCtx.fillStyle = grad;
    cpuSparkCtx.fill();
  }

  // Pre-populate 16 CPU cores in #btop-cores-grid
  const btopCoresGrid = document.getElementById('btop-cores-grid');
  if (btopCoresGrid) {
    let coresHtml = '';
    for (let c = 0; c < 16; c++) {
      const label = `T${String(c).padStart(2, '0')}`;
      coresHtml += `
        <div class="core-cell">
          <span class="core-num">${label}</span>
          <div class="core-bar-track"><div class="core-bar-fill" id="core-fill-${c}" style="width: 0%"></div></div>
          <span class="core-pct" id="core-pct-${c}">0%</span>
        </div>
      `;
    }
    btopCoresGrid.innerHTML = coresHtml;
  }

  // Click-to-kill process delegate
  document.getElementById('btop-procs-list')?.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-proc-kill');
    if (!btn) return;
    const pid = btn.dataset.pid;
    const name = btn.dataset.name;
    if (pid) {
      sendHost({ action: 'kill_process', pid: pid, name: name });
    }
  });

  // ─── STATS HEARTBEAT FROM PYTHON ───
  window.onHostStats = function(stats) {
    if (!stats) return;

    // Session time
    if (stats.session_time) {
      const sp = document.getElementById('sp-timecode');
      if (sp) sp.textContent = stats.session_time;
    }

    // Battery
    if (stats.battery) {
      const bPct = document.getElementById('batt-pct');
      const bBars = document.getElementById('batt-bars');
      if (bPct) bPct.textContent = `${stats.battery.pct}%`;
      if (bBars) {
        const blocks = Math.round(stats.battery.pct / 20);
        bBars.textContent = `[${'█'.repeat(blocks)}${'░'.repeat(5 - blocks)}]`;
      }
    }

    // CPU
    if (stats.cpu_usage !== undefined) {
      const cpuVal = document.getElementById('cpu-val');
      if (cpuVal) cpuVal.textContent = `${stats.cpu_usage}%`;
      drawCpuSparkline(stats.cpu_usage);
    }

    // 16 CPU Cores
    if (stats.cpu_cores && Array.isArray(stats.cpu_cores)) {
      stats.cpu_cores.forEach((pct, idx) => {
        const fill = document.getElementById(`core-fill-${idx}`);
        const label = document.getElementById(`core-pct-${idx}`);
        if (fill) fill.style.width = `${pct}%`;
        if (label) label.textContent = `${pct}%`;
      });
    }

    // RAM
    if (stats.mem) {
      const ramVal = document.getElementById('ram-val');
      const ramBar = document.getElementById('ram-bar');
      const ramPctBadge = document.getElementById('ram-pct-badge');
      if (ramVal) ramVal.textContent = `${stats.mem.used_gb}G / ${stats.mem.total_gb}G`;
      if (ramBar) ramBar.style.width = `${stats.mem.pct}%`;
      if (ramPctBadge) ramPctBadge.textContent = `${stats.mem.pct}%`;
    }

    // ZRAM
    if (stats.zram) {
      const zVal = document.getElementById('zram-val');
      const zBar = document.getElementById('zram-bar');
      if (zVal) zVal.textContent = `${stats.zram.orig_gb}G / ${stats.zram.total_gb}G (${stats.zram.ratio}x)`;
      if (zBar) zBar.style.width = `${Math.min(100, stats.zram.pct)}%`;
    }

    // Disk
    if (stats.disk) {
      const diskVal = document.getElementById('disk-val');
      const diskBar = document.getElementById('disk-bar');
      if (diskVal) diskVal.textContent = `${stats.disk.free_gb} GB FREE (${stats.disk.pct}% USED)`;
      if (diskBar) diskBar.style.width = `${stats.disk.pct}%`;
    } else if (stats.disk_remain) {
      const diskVal = document.getElementById('disk-val');
      if (diskVal) diskVal.textContent = stats.disk_remain;
    }

    // GPU & Thermal
    if (stats.gpu_usage !== undefined) {
      const gpuDetail = document.getElementById('gpu-detail');
      const gpuBar = document.getElementById('gpu-bar');
      const t = stats.thermal !== undefined ? stats.thermal : 48;
      if (gpuDetail) gpuDetail.textContent = `${stats.gpu_usage}% // SOC: ${t}°C`;
      if (gpuBar) gpuBar.style.width = `${stats.gpu_usage}%`;
    }

    // Thermal Header Tag
    if (stats.thermal !== undefined) {
      const tempVal = document.getElementById('temp-val');
      if (tempVal) tempVal.textContent = `${stats.thermal}°C`;
    }

    // Top Processes Table
    if (stats.top_procs && Array.isArray(stats.top_procs)) {
      const procsList = document.getElementById('btop-procs-list');
      if (procsList) {
        let html = '';
        stats.top_procs.slice(0, 6).forEach(p => {
          html += `
            <div class="proc-row">
              <span class="p-col p-pid">${p.pid}</span>
              <span class="p-col p-name" title="${p.name}">${p.name}</span>
              <span class="p-col p-cpu">${p.cpu}%</span>
              <span class="p-col p-mem">${p.mem}%</span>
              <span class="p-col p-act"><button class="btn-proc-kill" data-pid="${p.pid}" data-name="${p.name}">✕</button></span>
            </div>
          `;
        });
        procsList.innerHTML = html;
      }
    }

    // Network Traffic
    if (stats.net_traffic) {
      const txEl = document.getElementById('net-tx');
      const rxEl = document.getElementById('net-rx');
      if (txEl && stats.net_traffic.tx) txEl.textContent = stats.net_traffic.tx;
      if (rxEl && stats.net_traffic.rx) rxEl.textContent = stats.net_traffic.rx;
    }

    // Volume & Brightness sliders (if not dragging)
    if (stats.volume && sliderVol && document.activeElement !== sliderVol) {
      sliderVol.value = stats.volume.vol;
      if (volVal) volVal.textContent = `${stats.volume.vol}%`;
      updateVuLadder(sliderVol.parentElement?.querySelector('.vu-meter-ladder'), stats.volume.vol);
    }
    if (stats.brightness !== undefined && sliderBright && document.activeElement !== sliderBright) {
      sliderBright.value = stats.brightness;
      if (brightVal) brightVal.textContent = `${stats.brightness}%`;
      updateVuLadder(sliderBright.parentElement?.querySelector('.vu-meter-ladder'), stats.brightness);
    }

    // Media
    if (stats.media) {
      updateTapePhysics(stats.media);
    }

    // Feed Live Bandwidth Oscilloscope
    if (stats.net_traffic && window.VectorLab && window.VectorLab.pushBandwidth) {
      window.VectorLab.pushBandwidth(
        stats.net_traffic.rx_kb,
        stats.net_traffic.tx_kb,
        stats.net_traffic.rx,
        stats.net_traffic.tx
      );
    }

    // Audio Profile (Hi-Fi vs Call)
    if (stats.audio_mode && !isLocked('audio_mode')) {
      if (stats.audio_mode === 'call') {
        swBtMusic?.classList.remove('active');
        swBtCall?.classList.add('active');
      } else {
        swBtCall?.classList.remove('active');
        swBtMusic?.classList.add('active');
      }
    }

    // CRT Mode (Respect user lock)
    if (stats.crt_mode && !isLocked('crt_mode')) {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-mode]').forEach(b => {
        b.classList.toggle('active', b.dataset.mode === stats.crt_mode);
      });
      document.querySelectorAll('.kelvin-btn').forEach(b => {
        const isMatch = (b.dataset.shader === stats.crt_mode);
        b.classList.toggle('active', isMatch);
        b.querySelector('.latch-led')?.classList.toggle('on', isMatch);
        if (isMatch) {
          const readout = document.getElementById('kelvin-readout');
          if (readout) readout.textContent = `${b.dataset.kelvin}K [LATCHED]`;
        }
      });
    }

    // Power Mode (Respect user lock)
    if (stats.power_mode && !isLocked('power_mode')) {
      document.querySelectorAll('.switch-tri-state .tri-btn[data-pwr]').forEach(b => {
        b.classList.toggle('active', b.dataset.pwr === stats.power_mode);
      });
    }

    // Touchpad Hardware State Sync
    if (stats.touchpad) {
      ['tap_to_click', 'tap_and_drag', 'drag_lock', 'natural_scroll'].forEach(p => {
        if (!isLocked('touch_' + p) && stats.touchpad[p] !== undefined) {
          const b = document.querySelector(`.latch-toggle-btn[data-touch="${p}"]`);
          if (b) {
            b.classList.toggle('active', !!stats.touchpad[p]);
            b.querySelector('.latch-led')?.classList.toggle('on', !!stats.touchpad[p]);
          }
        }
      });
    }

    // Cursor timeout
    if (stats.cursor_timeout !== undefined && !isLocked('cursor_timeout')) {
      document.querySelectorAll('#cursor-timeout-group .tri-opt-btn').forEach(b => {
        b.classList.toggle('active', String(b.dataset.timeout) === String(stats.cursor_timeout));
      });
    }

    // Caffeine Sleep Inhibitor State
    if (stats.caffeine !== undefined && !isLocked('caffeine')) {
      btnCaffeine?.classList.toggle('active', !!stats.caffeine);
      caffeineLed?.classList.toggle('on', !!stats.caffeine);
      if (stats.caffeine) {
        if (caffeineBadge) caffeineBadge.textContent = "CAFFEINE: ACTIVE";
        if (caffeineDesc) caffeineDesc.textContent = "SLEEP & LOCK INHIBITED";
      } else {
        if (caffeineBadge) caffeineBadge.textContent = "IDLE: ARMED";
        if (caffeineDesc) caffeineDesc.textContent = "CLICK TO INHIBIT SLEEP & LOCK";
      }
    }

    // Network Telemetry & Link Status
    if (stats.net_info) {
      const n = stats.net_info;
      const elSsid = document.getElementById('net-ssid');
      const elIp = document.getElementById('net-ip');
      const elPing = document.getElementById('net-ping');
      if (elSsid && n.ssid) elSsid.textContent = n.ssid;
      if (elIp && n.ip) elIp.textContent = n.ip;
      if (elPing && n.ping) elPing.textContent = n.ping;

      if (!isLocked('wifi') && n.wifi_enabled !== undefined && btnWifi) {
        btnWifi.classList.toggle('active', !!n.wifi_enabled);
        btnWifi.querySelector('.latch-led')?.classList.toggle('on', !!n.wifi_enabled);
      }
      if (!isLocked('bt') && n.bt_enabled !== undefined && btnBt) {
        btnBt.classList.toggle('active', !!n.bt_enabled);
        btnBt.querySelector('.latch-led')?.classList.toggle('on', !!n.bt_enabled);
      }
      if (!isLocked('dnd') && n.dnd !== undefined && btnDnd) {
        btnDnd.classList.toggle('active', !!n.dnd);
        btnDnd.querySelector('.latch-led')?.classList.toggle('on', !!n.dnd);
      }
      if (n.airplane !== undefined && btnAirplane) {
        btnAirplane.classList.toggle('active', !!n.airplane);
        btnAirplane.querySelector('.latch-led')?.classList.toggle('on', !!n.airplane);
      }
    }

    // RF Diagnostics & 802.11ax PHY Link
    if (stats.rf_info) {
      const rf = stats.rf_info;
      const rfBadge = document.getElementById('rf-status-badge');
      const rfRssiVal = document.getElementById('rf-rssi-val');
      const rfRssiBar = document.getElementById('rf-rssi-bar');
      const rfBssid = document.getElementById('rf-bssid');
      const rfFreq = document.getElementById('rf-freq');
      const rfRate = document.getElementById('rf-rate');
      const rfCidr = document.getElementById('rf-cidr');

      if (rfBadge) rfBadge.textContent = `${rf.ssid} [${rf.freq.includes('5') ? '5GHz' : '2.4GHz'}]`;
      const dbm = Math.round(-1 * (100 - rf.signal) * 0.5 - 35);
      if (rfRssiVal) rfRssiVal.textContent = `${dbm} dBm [${rf.signal}% EXCELLENT]`;
      if (rfRssiBar) rfRssiBar.style.width = `${rf.signal}%`;
      if (rfBssid && rf.bssid) rfBssid.textContent = rf.bssid;
      if (rfFreq && rf.freq) rfFreq.textContent = `${rf.freq} (CH ${rf.chan})`;
      if (rfRate && rf.rate) rfRate.textContent = rf.rate;
      if (rfCidr) {
        const ip = (stats.net_info && stats.net_info.ip) ? stats.net_info.ip : '10.45.113.12';
        rfCidr.textContent = `${ip}/21`;
      }
    }

    // Active Sockets & Port Telemetry
    if (stats.sockets && Array.isArray(stats.sockets)) {
      const sockBody = document.getElementById('socket-list-body');
      if (sockBody) {
        let html = '';
        stats.sockets.forEach(s => {
          const stClass = s.state.includes('ESTAB') ? 'st-estab' : (s.state.includes('LISTEN') ? 'st-listen' : 'st-unconn');
          html += `
            <div class="socket-row">
              <span class="s-col s-proto">${s.proto}</span>
              <span class="s-col s-port">${s.port}</span>
              <span class="s-col s-svc" title="${s.service}">${s.service}</span>
              <span class="s-col s-st ${stClass}">${s.state}</span>
            </div>
          `;
        });
        sockBody.innerHTML = html;
      }
    }

    // Hardware Battery Subsystem & Thermals Bus
    if (stats.battery_subsystem) {
      const b = stats.battery_subsystem;
      const batBadge = document.getElementById('bat-status-badge');
      const batMain = document.getElementById('bat-main-txt');
      const batDetail = document.getElementById('bat-detail-txt');
      const batBar = document.getElementById('bat-bar-fill');

      if (batBadge) batBadge.textContent = `ACPI BAT0 [${b.status.toUpperCase()}]`;
      if (batMain) batMain.textContent = `BAT0: ${b.cap}% [${b.status.toUpperCase()}]`;
      if (batDetail) batDetail.textContent = `DRAW: ${b.power_w} // ${b.volts} // HEALTH: ${b.health}%`;
      if (batBar) batBar.style.width = `${b.cap}%`;

      const t = stats.thermal !== undefined ? stats.thermal : 54;
      const thCpu = document.getElementById('th-cpu');
      const thGpu = document.getElementById('th-gpu');
      const thNvme = document.getElementById('th-nvme');
      const thFan = document.getElementById('th-fan');

      if (thCpu) thCpu.textContent = `${t}°C`;
      if (thGpu) thGpu.textContent = `${Math.max(35, t - 3)}°C`;
      if (thNvme) thNvme.textContent = `${Math.max(30, t - 8)}°C`;
      if (thFan) thFan.textContent = `1850 RPM`;
    }

    // System Kernel & Hyprland Monotonic Stream
    if (stats.system_log && stats.system_log.length > 0) {
      const logStream = document.getElementById('journal-log-stream');
      if (logStream) {
        let html = '';
        stats.system_log.slice(-10).forEach(line => {
          const match = line.match(/^(\[[^\]]+\])\s*([^:]+:)?(.*)$/);
          if (match) {
            const ts = match[1] || '';
            const mod = match[2] || '';
            const msg = match[3] || '';
            html += `<div class="log-line"><span class="log-ts">${ts}</span> <span class="log-mod">${mod}</span>${msg}</div>`;
          } else {
            html += `<div class="log-line">${line}</div>`;
          }
        });
        logStream.innerHTML = html;
      }
    }

    // 16-Band Real-Time Studio Graphic Equalizer Animation
    const isPlaying = stats.media && stats.media.status === 'Playing';
    const now = Date.now() / 180.0;
    for (let b = 0; b < 16; b++) {
      const specFill = document.getElementById(`spec-b${b}`);
      const specPeak = document.getElementById(`spec-peak-${b}`);
      if (specFill) {
        const freqWeight = Math.sin((b / 16) * Math.PI);
        const wave1 = Math.sin(now * 1.8 + b * 0.7);
        const wave2 = Math.cos(now * 2.4 - b * 0.5);
        const energy = Math.abs(wave1 * 0.55 + wave2 * 0.45);
        const base = isPlaying
          ? Math.max(12, Math.min(95, Math.round(energy * 68 + freqWeight * 24)))
          : Math.max(8, Math.min(26, Math.round(Math.sin(now * 0.5 + b * 0.4) * 8 + 14)));
        specFill.style.height = `${base}%`;
        if (specPeak) {
          specPeak.style.bottom = `${Math.min(98, base + 2)}%`;
        }
      }
    }

    // Master Stereo Program Meters (PPM)
    const ppmFillL = document.getElementById('ppm-meter-l');
    const ppmFillR = document.getElementById('ppm-meter-r');
    const ppmPeakL = document.getElementById('ppm-peak-l');
    const ppmPeakR = document.getElementById('ppm-peak-r');
    const ppmValL = document.getElementById('ppm-val-l');
    const ppmValR = document.getElementById('ppm-val-r');
    if (ppmFillL && ppmFillR) {
      const lvlL = isPlaying ? Math.round(Math.abs(Math.sin(now * 1.6)) * 40 + 44) : 16;
      const lvlR = isPlaying ? Math.round(Math.abs(Math.cos(now * 1.4)) * 38 + 40) : 12;
      ppmFillL.style.width = `${lvlL}%`;
      ppmFillR.style.width = `${lvlR}%`;
      if (ppmPeakL) ppmPeakL.style.left = `${Math.min(98, lvlL + 6)}%`;
      if (ppmPeakR) ppmPeakR.style.left = `${Math.min(98, lvlR + 6)}%`;
      if (ppmValL) ppmValL.textContent = `${isPlaying ? (-24 + Math.round(lvlL * 0.28)) : -40} dBFS`;
      if (ppmValR) ppmValR.textContent = `${isPlaying ? (-26 + Math.round(lvlR * 0.28)) : -42} dBFS`;
    }

    // Tape Counter tick when music is playing
    if (stats.media && stats.media.status === 'Playing' && !pomoActive) {
      tapeCounter++;
      if (counterVal) counterVal.textContent = String(tapeCounter).padStart(4, '0');
    }
  };

  // ─── HYPRLAND ZERO-CPU VISIBILITY HOOK ───
  window.onDeckVisibility = function(visible) {
    isDeckVisible = visible;
    if (visible) {
      if (window.AsciiEngine) window.AsciiEngine.start();
      if (currentDeckMode === 'overload' && window.VectorLab) window.VectorLab.start();
    } else {
      if (window.AsciiEngine) window.AsciiEngine.stop();
      if (window.VectorLab) window.VectorLab.stop();
    }
  };

})();
