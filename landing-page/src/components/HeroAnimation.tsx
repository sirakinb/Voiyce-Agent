"use client";

import React, { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

// ---- Flowing dots along a curved SVG path ----

const CURVE_PATH =
  "M 0,200 C 200,100 400,300 600,180 C 800,60 1000,250 1200,200";

const NUM_DOTS = 60;

function FlowingDots() {
  const pathRef = useRef<SVGPathElement>(null);
  const [dots, setDots] = useState<{ x: number; y: number; opacity: number; size: number }[]>([]);
  const frameRef = useRef<number>(0);
  const offsetRef = useRef(0);

  useEffect(() => {
    const path = pathRef.current;
    if (!path) return;

    const totalLength = path.getTotalLength();
    let running = true;

    const animate = () => {
      if (!running) return;
      offsetRef.current = (offsetRef.current + 0.4) % totalLength;

      const newDots = [];
      for (let i = 0; i < NUM_DOTS; i++) {
        const t = ((offsetRef.current + (i * totalLength) / NUM_DOTS) % totalLength);
        const point = path.getPointAtLength(t);
        const progress = i / NUM_DOTS;
        // Fade in at start, fade out at end
        const fadeIn = Math.min(progress * 4, 1);
        const fadeOut = Math.min((1 - progress) * 4, 1);
        const opacity = fadeIn * fadeOut * (0.3 + Math.sin(Date.now() * 0.002 + i) * 0.2);
        const size = 1.5 + Math.sin(Date.now() * 0.003 + i * 0.5) * 1;
        newDots.push({ x: point.x, y: point.y, opacity, size });
      }
      setDots(newDots);
      frameRef.current = requestAnimationFrame(animate);
    };

    frameRef.current = requestAnimationFrame(animate);
    return () => {
      running = false;
      cancelAnimationFrame(frameRef.current);
    };
  }, []);

  return (
    <g>
      <path
        ref={pathRef}
        d={CURVE_PATH}
        fill="none"
        stroke="url(#curveGradient)"
        strokeWidth="1"
        opacity="0.15"
      />
      {dots.map((dot, i) => (
        <circle
          key={i}
          cx={dot.x}
          cy={dot.y}
          r={dot.size}
          fill="url(#dotGradient)"
          opacity={dot.opacity}
        />
      ))}
    </g>
  );
}

// ---- Animated voice waveform bars ----

function VoiceWaveform() {
  const bars = 24;
  return (
    <div className="flex items-center gap-[2px] h-12">
      {Array.from({ length: bars }).map((_, i) => {
        const delay = i * 0.05;
        const baseHeight = 8 + Math.sin(i * 0.8) * 12;
        const duration = 1.2 + (i % 5) * 0.08;
        return (
          <motion.div
            key={i}
            className="w-[2px] rounded-full bg-gradient-to-t from-purple-500/60 to-purple-300/80"
            animate={{
              height: [baseHeight, baseHeight * 2.5, baseHeight * 0.6, baseHeight * 1.8, baseHeight],
            }}
            transition={{
              duration,
              repeat: Infinity,
              ease: "easeInOut",
              delay,
            }}
          />
        );
      })}
    </div>
  );
}

// ---- Typing text reveal ----

const RAW_TEXT = `um hey so I was thinking about the new landing page and we should probably make the hero section way bigger and um maybe add like a dark mode glow effect behind the dashboard image because right now it looks kinda flat and yeah let me know what you think about that`;
const CLEAN_TEXT = `Hey team, I was reviewing the new landing page. We should make the hero section significantly larger and add a dark mode glow effect behind the dashboard image to prevent it from looking flat. Let me know your thoughts.`;

function TypingText({ text, className, speed = 30 }: { text: string; className?: string; speed?: number }) {
  const [displayed, setDisplayed] = useState("");
  const [started, setStarted] = useState(false);

  useEffect(() => {
    const startTimer = setTimeout(() => setStarted(true), 800);
    return () => clearTimeout(startTimer);
  }, []);

  useEffect(() => {
    if (!started) return;
    if (displayed.length >= text.length) return;

    const timer = setTimeout(() => {
      setDisplayed(text.slice(0, displayed.length + 1));
    }, speed);
    return () => clearTimeout(timer);
  }, [displayed, started, text, speed]);

  return (
    <span className={className}>
      {displayed}
      {displayed.length < text.length && (
        <motion.span
          animate={{ opacity: [1, 0] }}
          transition={{ duration: 0.5, repeat: Infinity }}
          className="inline-block w-[2px] h-[1em] bg-current ml-[1px] align-middle"
        />
      )}
    </span>
  );
}

// ---- Main hero animation ----

export default function HeroAnimation() {
  const [phase, setPhase] = useState<"speaking" | "transforming" | "complete">("speaking");

  useEffect(() => {
    const t1 = setTimeout(() => setPhase("transforming"), 5500);
    const t2 = setTimeout(() => setPhase("complete"), 6500);
    // Loop the animation
    const t3 = setTimeout(() => setPhase("speaking"), 14000);
    const interval = setInterval(() => {
      setPhase("speaking");
      setTimeout(() => setPhase("transforming"), 5500);
      setTimeout(() => setPhase("complete"), 6500);
    }, 14000);

    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
      clearTimeout(t3);
      clearInterval(interval);
    };
  }, []);

  return (
    <div className="relative w-full max-w-5xl mx-auto">
      {/* SVG flowing curve background */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <svg
          viewBox="0 0 1200 400"
          className="w-full h-full"
          preserveAspectRatio="xMidYMid slice"
        >
          <defs>
            <linearGradient id="curveGradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#a855f7" stopOpacity="0.6" />
              <stop offset="50%" stopColor="#c084fc" stopOpacity="0.8" />
              <stop offset="100%" stopColor="#a855f7" stopOpacity="0.6" />
            </linearGradient>
            <radialGradient id="dotGradient">
              <stop offset="0%" stopColor="#e9d5ff" />
              <stop offset="60%" stopColor="#a855f7" />
              <stop offset="100%" stopColor="#7c3aed" stopOpacity="0" />
            </radialGradient>
            {/* Glow filter */}
            <filter id="glow">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>
          <FlowingDots />
          {/* Additional ambient curves */}
          <path
            d="M 0,300 C 300,200 600,350 900,250 C 1050,200 1150,300 1200,280"
            fill="none"
            stroke="url(#curveGradient)"
            strokeWidth="0.5"
            opacity="0.08"
          />
          <path
            d="M 0,100 C 200,150 500,50 700,120 C 900,190 1100,100 1200,130"
            fill="none"
            stroke="url(#curveGradient)"
            strokeWidth="0.5"
            opacity="0.06"
          />
        </svg>
      </div>

      {/* Main content cards */}
      <div className="relative z-10 grid md:grid-cols-2 gap-6 p-4 sm:p-6">
        {/* Left: Voice Input */}
        <motion.div
          initial={{ opacity: 0, x: -30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="bg-[#0A0A0A]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-6 sm:p-8 relative overflow-hidden"
        >
          {/* Subtle top accent */}
          <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-purple-500/30 to-transparent" />

          <div className="flex items-center gap-3 mb-6">
            <div className="relative">
              <div className="w-10 h-10 rounded-full bg-purple-500/10 flex items-center justify-center border border-purple-500/20">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-purple-400">
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                  <line x1="12" x2="12" y1="19" y2="22" />
                </svg>
              </div>
              <AnimatePresence>
                {phase === "speaking" && (
                  <motion.div
                    initial={{ scale: 0.8, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    exit={{ scale: 0.8, opacity: 0 }}
                    className="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full border-2 border-[#0A0A0A]"
                  >
                    <motion.div
                      animate={{ scale: [1, 1.5, 1], opacity: [1, 0, 1] }}
                      transition={{ duration: 1, repeat: Infinity }}
                      className="w-full h-full bg-red-500 rounded-full"
                    />
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
            <div>
              <span className="text-white/90 font-medium text-sm">Voice Input</span>
              <div className="flex items-center gap-2 mt-0.5">
                <AnimatePresence mode="wait">
                  {phase === "speaking" ? (
                    <motion.span
                      key="recording"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="text-red-400 text-xs font-medium"
                    >
                      Recording...
                    </motion.span>
                  ) : (
                    <motion.span
                      key="done"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="text-[#666] text-xs"
                    >
                      Captured
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>
            </div>
          </div>

          {/* Waveform */}
          <div className="mb-6">
            {phase === "speaking" ? (
              <VoiceWaveform />
            ) : (
              <div className="flex items-center gap-[2px] h-12">
                {Array.from({ length: 24 }).map((_, i) => (
                  <motion.div
                    key={i}
                    initial={{ height: 8 + Math.sin(i * 0.8) * 12 }}
                    animate={{ height: 3 }}
                    transition={{ duration: 0.4, delay: i * 0.02 }}
                    className="w-[2px] rounded-full bg-purple-500/30"
                  />
                ))}
              </div>
            )}
          </div>

          {/* Raw transcript */}
          <div className="bg-black/40 rounded-xl p-4 border border-white/5 min-h-[140px]">
            <p className="text-[#666] text-sm leading-relaxed font-light italic">
              {phase === "speaking" ? (
                <TypingText text={RAW_TEXT} className="text-[#666]" speed={25} />
              ) : (
                <span className="text-[#555]">{RAW_TEXT}</span>
              )}
            </p>
          </div>
        </motion.div>

        {/* Right: Polished Output */}
        <motion.div
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, delay: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="bg-gradient-to-b from-[#111]/80 to-[#0A0A0A]/80 backdrop-blur-xl border border-purple-500/20 rounded-2xl p-6 sm:p-8 relative overflow-hidden shadow-[0_0_60px_-20px_rgba(168,85,247,0.15)]"
        >
          {/* Accent line */}
          <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-purple-500/50 to-transparent" />

          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-full bg-purple-500/10 flex items-center justify-center border border-purple-500/20">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-purple-400">
                <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" x2="8" y1="13" y2="13" />
                <line x1="16" x2="8" y1="17" y2="17" />
                <line x1="10" x2="8" y1="9" y2="9" />
              </svg>
            </div>
            <div>
              <span className="text-white/90 font-medium text-sm">Voiyce Output</span>
              <div className="flex items-center gap-2 mt-0.5">
                <AnimatePresence mode="wait">
                  {phase === "complete" ? (
                    <motion.span
                      key="done"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      className="text-green-400 text-xs font-medium flex items-center gap-1"
                    >
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" className="text-green-400">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                      Polished
                    </motion.span>
                  ) : phase === "transforming" ? (
                    <motion.span
                      key="processing"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="text-purple-400 text-xs font-medium"
                    >
                      Processing...
                    </motion.span>
                  ) : (
                    <motion.span
                      key="waiting"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="text-[#666] text-xs"
                    >
                      Waiting for input...
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>
            </div>
          </div>

          {/* Improvements badges */}
          <AnimatePresence>
            {(phase === "transforming" || phase === "complete") && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
                className="flex flex-wrap gap-2 mb-6"
              >
                {["Filler words removed", "Grammar corrected", "Punctuation added"].map((label, i) => (
                  <motion.span
                    key={label}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: 0.3 + i * 0.15 }}
                    className="px-2.5 py-1 bg-purple-500/10 border border-purple-500/20 rounded-full text-purple-300 text-[11px] font-medium"
                  >
                    {label}
                  </motion.span>
                ))}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Clean output text */}
          <div className="bg-black/30 rounded-xl p-4 border border-purple-500/10 min-h-[140px] flex items-start">
            <AnimatePresence mode="wait">
              {phase === "speaking" && (
                <motion.div
                  key="waiting"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 0.3 }}
                  exit={{ opacity: 0 }}
                  className="flex items-center gap-2 text-[#555] text-sm"
                >
                  <motion.span
                    animate={{ opacity: [0.3, 0.6, 0.3] }}
                    transition={{ duration: 2, repeat: Infinity }}
                  >
                    Listening to your voice...
                  </motion.span>
                </motion.div>
              )}
              {(phase === "transforming" || phase === "complete") && (
                <motion.p
                  key="output"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="text-white text-sm sm:text-base leading-relaxed font-medium"
                >
                  <TypingText text={CLEAN_TEXT} className="text-white" speed={15} />
                </motion.p>
              )}
            </AnimatePresence>
          </div>

          {/* Bottom stats */}
          <AnimatePresence>
            {phase === "complete" && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.8 }}
                className="mt-4 flex items-center gap-4 text-xs text-[#666]"
              >
                <span className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
                  3.2s processing
                </span>
                <span>27 words</span>
                <span className="text-purple-400">4 improvements</span>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </div>

      {/* Connecting arrow between cards (desktop) */}
      <div className="hidden md:flex absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-20">
        <motion.div
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 1.2, duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
          className="w-10 h-10 bg-[#0A0A0A] border border-purple-500/30 rounded-full flex items-center justify-center shadow-[0_0_20px_-5px_rgba(168,85,247,0.3)]"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-purple-400">
            <path d="M5 12h14" />
            <path d="m12 5 7 7-7 7" />
          </svg>
        </motion.div>
      </div>
    </div>
  );
}
