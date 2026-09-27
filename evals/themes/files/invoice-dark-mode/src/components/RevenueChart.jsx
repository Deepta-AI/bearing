import React, { useEffect, useRef } from 'react';
import { chartTheme } from '../lib/chartTheme.js';

// Drawn on a canvas: canvas does not read CSS custom properties, so the
// colours come from chartTheme.
export default function RevenueChart({ months }) {
  const ref = useRef(null);
  useEffect(() => {
    const ctx = ref.current.getContext('2d');
    const { width, height } = ref.current;
    const max = Math.max(...months);
    ctx.clearRect(0, 0, width, height);
    ctx.strokeStyle = chartTheme.grid;
    for (let y = 0; y <= 4; y++) {
      ctx.beginPath(); ctx.moveTo(40, 10 + y * 40); ctx.lineTo(width, 10 + y * 40); ctx.stroke();
    }
    ctx.fillStyle = chartTheme.axis;
    ctx.font = '12px Inter, sans-serif';
    ctx.fillText(String(max), 0, 14);
    ctx.fillStyle = chartTheme.series[0];
    months.forEach((m, i) => {
      const h = (m / max) * 160;
      ctx.fillRect(50 + i * 60, 170 - h, 36, h);
    });
  }, [months]);
  return <div className="card chart"><h2>Revenue</h2><canvas ref={ref} width={420} height={180} /></div>;
}
