"use client";

import { useEffect, useRef } from "react";

// Multiple curved paths for visual depth
const PATHS = [
  { d: "M -100,250 C 200,80 500,350 800,200 C 1100,50 1300,300 1500,220", speed: 0.35, dotCount: 50, width: 1.2 },
  { d: "M -50,350 C 250,200 450,450 750,300 C 1050,150 1250,380 1550,280", speed: 0.25, dotCount: 40, width: 0.8 },
  { d: "M -100,150 C 300,300 500,100 800,250 C 1000,350 1200,150 1500,200", speed: 0.45, dotCount: 45, width: 1.0 },
  { d: "M -50,450 C 200,350 500,500 800,380 C 1100,260 1300,420 1550,350", speed: 0.2, dotCount: 30, width: 0.6 },
  { d: "M -100,100 C 150,200 400,50 700,180 C 1000,310 1200,100 1500,160", speed: 0.3, dotCount: 35, width: 0.7 },
];

interface Dot {
  offset: number;
  baseSpeed: number;
  size: number;
  brightness: number;
  pulsePhase: number;
}

export default function HeroParticles() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const pathsRef = useRef<{ path: Path2D; length: number; svg: SVGPathElement }[]>([]);
  const dotsRef = useRef<Dot[][]>([]);
  const frameRef = useRef<number>(0);
  const timeRef = useRef(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Measure paths using an offscreen SVG
    const svgNS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("width", "0");
    svg.setAttribute("height", "0");
    svg.style.position = "absolute";
    svg.style.visibility = "hidden";
    document.body.appendChild(svg);

    const pathData = PATHS.map((p) => {
      const svgPath = document.createElementNS(svgNS, "path");
      svgPath.setAttribute("d", p.d);
      svg.appendChild(svgPath);
      const length = svgPath.getTotalLength();
      return { path: new Path2D(p.d), length, svg: svgPath };
    });
    pathsRef.current = pathData;

    // Initialize dots for each path
    dotsRef.current = PATHS.map((p, pi) => {
      const pathLength = pathData[pi].length;
      return Array.from({ length: p.dotCount }, (_, i) => ({
        offset: (i / p.dotCount) * pathLength,
        baseSpeed: p.speed * (0.8 + Math.random() * 0.4),
        size: 1 + Math.random() * 2,
        brightness: 0.3 + Math.random() * 0.7,
        pulsePhase: Math.random() * Math.PI * 2,
      }));
    });

    const resize = () => {
      const dpr = window.devicePixelRatio || 1;
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    resize();
    window.addEventListener("resize", resize);

    const animate = () => {
      const rect = canvas.getBoundingClientRect();
      ctx.clearRect(0, 0, rect.width, rect.height);
      timeRef.current += 0.016;

      // Scale factor to map SVG coords (1500x550) to canvas size
      const scaleX = rect.width / 1500;
      const scaleY = rect.height / 550;

      PATHS.forEach((pathConfig, pi) => {
        const pathInfo = pathsRef.current[pi];
        const dots = dotsRef.current[pi];
        if (!pathInfo || !dots) return;

        // Draw the path line (subtle)
        ctx.save();
        ctx.scale(scaleX, scaleY);
        ctx.strokeStyle = `rgba(168, 85, 247, 0.06)`;
        ctx.lineWidth = pathConfig.width;
        ctx.stroke(pathInfo.path);
        ctx.restore();

        // Draw and update dots
        dots.forEach((dot) => {
          dot.offset = (dot.offset + dot.baseSpeed) % pathInfo.length;

          const point = pathInfo.svg.getPointAtLength(dot.offset);
          const x = point.x * scaleX;
          const y = point.y * scaleY;

          // Pulsing opacity
          const pulse = Math.sin(timeRef.current * 2 + dot.pulsePhase) * 0.3 + 0.7;
          const alpha = dot.brightness * pulse;

          // Glow
          const gradient = ctx.createRadialGradient(x, y, 0, x, y, dot.size * 4);
          gradient.addColorStop(0, `rgba(196, 132, 252, ${alpha})`);
          gradient.addColorStop(0.4, `rgba(168, 85, 247, ${alpha * 0.5})`);
          gradient.addColorStop(1, `rgba(168, 85, 247, 0)`);

          ctx.beginPath();
          ctx.arc(x, y, dot.size * 4, 0, Math.PI * 2);
          ctx.fillStyle = gradient;
          ctx.fill();

          // Core dot
          ctx.beginPath();
          ctx.arc(x, y, dot.size, 0, Math.PI * 2);
          ctx.fillStyle = `rgba(233, 213, 255, ${alpha})`;
          ctx.fill();
        });
      });

      frameRef.current = requestAnimationFrame(animate);
    };

    frameRef.current = requestAnimationFrame(animate);

    return () => {
      cancelAnimationFrame(frameRef.current);
      window.removeEventListener("resize", resize);
      document.body.removeChild(svg);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 w-full h-full pointer-events-none"
      style={{ opacity: 0.9 }}
    />
  );
}
