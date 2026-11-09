/* ═══════════════════════════════════════════════════════════════════
   TACTICAL CRT PHOSPHOR RADAR SIMULATOR
   ═══════════════════════════════════════════════════════════════════ */

(function() {
  const canvas = document.getElementById('radar-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  let width = canvas.width = 600;
  let height = canvas.height = 380;
  let cx = width / 2;
  let cy = height / 2;
  let maxRadius = Math.min(cx, cy) - 20;

  let angle = 0;
  const blips = [
    { dist: 0.35, angle: 0.8, alpha: 0, label: "BT: EARFUN" },
    { dist: 0.65, angle: 2.4, alpha: 0, label: "NET: EDUROAM" },
    { dist: 0.85, angle: 4.1, alpha: 0, label: "NODE: GATEWAY" },
    { dist: 0.50, angle: 5.3, alpha: 0, label: "DEV: ANTIGRAV" }
  ];

  function drawGrid() {
    ctx.strokeStyle = "rgba(0, 255, 65, 0.2)";
    ctx.lineWidth = 1;

    // Concentric range rings
    for (let i = 1; i <= 4; i++) {
      ctx.beginPath();
      ctx.arc(cx, cy, (maxRadius / 4) * i, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Crosshairs
    ctx.beginPath();
    ctx.moveTo(cx - maxRadius, cy);
    ctx.lineTo(cx + maxRadius, cy);
    ctx.moveTo(cx, cy - maxRadius);
    ctx.lineTo(cx, cy + maxRadius);
    ctx.stroke();

    // 45 deg diagonals
    ctx.strokeStyle = "rgba(0, 255, 65, 0.08)";
    ctx.beginPath();
    let d = maxRadius * 0.7071;
    ctx.moveTo(cx - d, cy - d); ctx.lineTo(cx + d, cy + d);
    ctx.moveTo(cx - d, cy + d); ctx.lineTo(cx + d, cy - d);
    ctx.stroke();

    // Range labels
    ctx.fillStyle = "rgba(0, 255, 65, 0.4)";
    ctx.font = "9px 'VCR OSD Mono', monospace";
    ctx.fillText("25KM", cx + 5, cy - (maxRadius * 0.25) + 3);
    ctx.fillText("50KM", cx + 5, cy - (maxRadius * 0.50) + 3);
    ctx.fillText("75KM", cx + 5, cy - (maxRadius * 0.75) + 3);
    ctx.fillText("100KM", cx + 5, cy - maxRadius + 12);
  }

  function renderRadar() {
    // Fade out previous frame (creates authentic phosphor persistence trail)
    ctx.fillStyle = "rgba(2, 5, 3, 0.07)";
    ctx.fillRect(0, 0, width, height);

    drawGrid();

    // Sweep line
    let sx = cx + Math.cos(angle) * maxRadius;
    let sy = cy + Math.sin(angle) * maxRadius;

    ctx.strokeStyle = "rgba(0, 255, 65, 0.9)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(sx, sy);
    ctx.stroke();

    // Phosphor sweep fan gradient
    let fanAngle = 0.25;
    let grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxRadius);
    grad.addColorStop(0, "rgba(0, 255, 65, 0.25)");
    grad.addColorStop(1, "rgba(0, 255, 65, 0.0)");

    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, maxRadius, angle - fanAngle, angle);
    ctx.closePath();
    ctx.fill();

    // Check blips collision with sweep
    blips.forEach(b => {
      let diff = Math.abs(angle - b.angle);
      if (diff < 0.08 || diff > Math.PI * 2 - 0.08) {
        b.alpha = 1.0;
      }

      if (b.alpha > 0.01) {
        let bx = cx + Math.cos(b.angle) * (b.dist * maxRadius);
        let by = cy + Math.sin(b.angle) * (b.dist * maxRadius);

        ctx.fillStyle = `rgba(0, 255, 65, ${b.alpha})`;
        ctx.beginPath();
        ctx.arc(bx, by, 3, 0, Math.PI * 2);
        ctx.fill();

        // Blip text
        ctx.fillStyle = `rgba(0, 255, 65, ${b.alpha * 0.8})`;
        ctx.font = "8px 'VCR OSD Mono', monospace";
        ctx.fillText(b.label, bx + 6, by - 4);

        b.alpha *= 0.96; // fade out
      }
    });

    // Azimuth & Coordinate telemetry
    ctx.fillStyle = "rgba(0, 255, 65, 0.7)";
    ctx.font = "10px 'VCR OSD Mono', monospace";
    let deg = Math.round((angle * 180 / Math.PI) % 360);
    ctx.fillText(`AZ: ${deg}°  SWEEP: 48 RPM`, 20, height - 20);
    ctx.fillText(`TARGETS: ${blips.length} ACQUIRED`, width - 150, height - 20);

    angle = (angle + 0.025) % (Math.PI * 2);
    requestAnimationFrame(renderRadar);
  }

  // Initial clear
  ctx.fillStyle = "#020503";
  ctx.fillRect(0, 0, width, height);
  renderRadar();
})();
