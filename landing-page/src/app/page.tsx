"use client";

import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Icon } from "@iconify/react";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import HeroParticles from "@/components/HeroParticles";
import HeroAnimation from "@/components/HeroAnimation";
import { buildAuthHref } from "@/lib/voiyce-config";

const fadeIn = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.8, ease: [0.16, 1, 0.3, 1] }
};

const staggerContainer = {
  animate: {
    transition: {
      staggerChildren: 0.15
    }
  }
};

const AUTH_INTENTS = ["download"] as const;

const painPoints = [
  "Every agent asks for the backstory again.",
  "Context is split across chats, tabs, repos, docs, calls, and browser state.",
  "You copy screenshots, logs, prompts, and summaries from one tool into the next.",
  "The hard-won context from Claude Code, Codex, Hermes Agent, OpenClaw, and Cursor rarely travels with you."
];

const productSteps = [
  {
    title: "Capture the session",
    description: "Screen state, spoken notes, app context, and agent learnings become one working record."
  },
  {
    title: "Keep what matters",
    description: "Decisions, files, blockers, and next steps become searchable project memory."
  },
  {
    title: "Brief the next tool",
    description: "Send the right context to Claude Code, Codex, Hermes Agent, OpenClaw, or Cursor."
  }
];

const useCases = [
  "I am stuck in this automation flow. Debug it from the current screen.",
  "Remind me why we made this product decision.",
  "Turn this working session into launch notes.",
  "Catch Codex up on what Hermes already learned."
];

const features = [
  {
    icon: "mdi:brain",
    title: "Shared AI memory",
    description: "One memory base across the tools you already use."
  },
  {
    icon: "mdi:monitor-eye",
    title: "Workspace context",
    description: "Capture the active app, page, repo, workflow, and visible state."
  },
  {
    icon: "mdi:source-branch-sync",
    title: "Agent handoff",
    description: "Brief the next agent without rebuilding the story."
  },
  {
    icon: "mdi:camera-metering-center",
    title: "Session snapshots",
    description: "Save the state of a bug, build, decision, or workflow."
  },
  {
    icon: "mdi:shield-lock",
    title: "Private memory base",
    description: "User-controlled memory with clear capture boundaries."
  },
  {
    icon: "mdi:magnify-scan",
    title: "Context search",
    description: "Find the prompt, note, file, or decision that explains what changed."
  }
];

type AgentStackItem =
  | {
      kind: "icon";
      name: string;
      icon: string;
      tone: string;
      iconClassName: string;
    }
  | {
      kind: "image";
      name: string;
      image: string;
      imageAlt: string;
      tone: string;
      imageClassName: string;
    };

const agentStack: AgentStackItem[] = [
  {
    kind: "icon",
    name: "Claude Code",
    icon: "simple-icons:anthropic",
    tone: "from-orange-300/20 to-white/[0.02]",
    iconClassName: "text-orange-100"
  },
  {
    kind: "icon",
    name: "Codex",
    icon: "simple-icons:openai",
    tone: "from-emerald-300/20 to-white/[0.02]",
    iconClassName: "text-emerald-100"
  },
  {
    kind: "image",
    name: "Hermes Agent",
    image: "/hermes-agent.png",
    tone: "from-white/15 to-purple-300/[0.03]",
    imageClassName: "rounded-lg",
    imageAlt: "Hermes Agent icon"
  },
  {
    kind: "image",
    name: "OpenClaw",
    image: "/openclaw.svg",
    tone: "from-red-400/20 to-white/[0.02]",
    imageClassName: "",
    imageAlt: "OpenClaw icon"
  },
  {
    kind: "icon",
    name: "Cursor",
    icon: "simple-icons:cursor",
    tone: "from-white/15 to-white/[0.02]",
    iconClassName: "text-white"
  }
];

export default function LandingPage() {
  const router = useRouter();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    const run = () => {
      for (const intent of AUTH_INTENTS) {
        router.prefetch(`/auth?intent=${intent}`);
      }
    };
    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(run);
      return () => window.cancelIdleCallback(id);
    }
    const t = window.setTimeout(run, 0);
    return () => window.clearTimeout(t);
  }, [router]);

  return (
    <div className="min-h-screen bg-black text-[#EDEDED] font-sans selection:bg-white/20 overflow-x-hidden">
      <div className="fixed inset-0 pointer-events-none z-0 flex justify-center">
        <div className="absolute top-[-24%] w-[1000px] h-[780px] bg-purple-900/14 blur-[150px] rounded-full mix-blend-screen"></div>
        <div className="absolute top-0 inset-x-0 h-[620px] bg-[linear-gradient(to_bottom,rgba(255,255,255,0.035)_1px,transparent_1px),linear-gradient(to_right,rgba(255,255,255,0.035)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_62%_50%_at_50%_0%,#000_70%,transparent_100%)]"></div>
      </div>

      <motion.nav
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        className={`fixed top-6 left-1/2 -translate-x-1/2 w-[calc(100%-2rem)] max-w-5xl z-50 transition-all duration-500 ${
          scrolled
            ? "bg-[#0A0A0A]/80 backdrop-blur-2xl border border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.4)]"
            : "bg-transparent border-transparent"
        } rounded-full px-5 py-4 flex items-center justify-center`}
      >
        <div className="flex items-center justify-between gap-5 mx-auto w-full">
          <Image
            src="/voiyce_logo.png"
            alt="Voiyce Logo"
            width={240}
            height={120}
            priority
            className="h-[120px] w-auto object-contain -my-[50px]"
          />
          <div className="hidden md:flex items-center gap-6 text-sm font-medium text-[#888888]">
            <a href="#pain" className="hover:text-white transition-colors">Problem</a>
            <a href="#how-it-works" className="hover:text-white transition-colors">How it works</a>
            <a href="#features" className="hover:text-white transition-colors">Memory</a>
            <a href="#trust" className="hover:text-white transition-colors">Trust</a>
          </div>
          <Link
            prefetch
            href={buildAuthHref("download")}
            className="shrink-0 inline-flex items-center justify-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-black shadow-[0_0_20px_-5px_rgba(255,255,255,0.2)] transition-colors hover:bg-[#EDEDED]"
          >
            Join the beta
          </Link>
        </div>
      </motion.nav>

      <section className="pt-40 pb-24 px-6 relative z-10 flex flex-col items-center text-center min-h-[92vh] justify-center overflow-hidden">
        <div className="absolute inset-0 z-0">
          <HeroParticles />
        </div>

        <div className="max-w-5xl mx-auto relative z-10">
          <motion.div
            initial="initial"
            animate="animate"
            variants={staggerContainer}
            className="flex flex-col items-center"
          >
            <motion.h1 variants={fadeIn} className="text-5xl sm:text-6xl md:text-8xl font-bold text-white tracking-tighter mb-7 leading-[1.02]">
              Stop re-explaining <br />
              <span className="text-[#C9C5D1]">
                your work to AI.
              </span>
            </motion.h1>

            <motion.p variants={fadeIn} className="text-lg md:text-2xl text-[#A8A3B3] mb-10 leading-relaxed max-w-3xl font-light">
              Voiyce is the agent context layer that captures what you&apos;re doing, what you&apos;re saying, and what your agents already learned, then turns it into reusable context for the tools you work with.
            </motion.p>

            <motion.div variants={fadeIn} className="flex w-full flex-col sm:flex-row justify-center gap-4">
              <Link
                prefetch
                href={buildAuthHref("download")}
                className="w-full sm:w-auto px-8 py-4 bg-white text-black hover:bg-[#EDEDED] rounded-full font-semibold text-lg transition-all shadow-[0_0_40px_-10px_rgba(255,255,255,0.15)] flex items-center justify-center gap-3"
              >
                Join the beta
              </Link>
              <a
                href="#how-it-works"
                className="w-full sm:w-auto px-8 py-4 bg-white/[0.03] text-white hover:bg-white/[0.06] rounded-full font-semibold text-lg transition-all border border-white/10 flex items-center justify-center gap-3"
              >
                See how it works
              </a>
            </motion.div>
            <motion.div variants={fadeIn} className="mt-10 w-full max-w-6xl rounded-[2rem] border border-white/10 bg-white/[0.04] p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),0_24px_90px_-50px_rgba(168,85,247,0.75)] backdrop-blur-xl">
              <div className="mb-3 flex items-center justify-between px-2 text-xs font-semibold uppercase tracking-[0.24em] text-purple-200/70">
                <span>Agent Context</span>
                <span className="hidden text-[#8A8494] sm:block">Works across your coding agents</span>
              </div>
              <div className="grid grid-cols-1 gap-px overflow-hidden rounded-3xl border border-white/[0.06] bg-white/10 sm:grid-cols-2 lg:grid-cols-[1.05fr_0.95fr_1.05fr_1.1fr_0.9fr]">
                {agentStack.map((agent) => (
                  <div
                    key={agent.name}
                    className={`group flex min-h-24 items-center gap-3 bg-[#0B0910] bg-gradient-to-br ${agent.tone} px-4 py-4 text-left transition-colors hover:bg-white/[0.03] xl:gap-4 xl:px-5`}
                  >
                    <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl border border-white/10 bg-black/45 shadow-[0_10px_30px_-18px_rgba(255,255,255,0.7)]">
                      {agent.kind === "image" ? (
                        <Image
                          src={agent.image}
                          alt={agent.imageAlt}
                          width={32}
                          height={32}
                          unoptimized
                          className={`h-8 w-8 object-contain ${agent.imageClassName}`}
                        />
                      ) : (
                        <Icon icon={agent.icon} className={`h-8 w-8 ${agent.iconClassName}`} />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="whitespace-normal text-2xl font-bold leading-tight text-white lg:text-[1.35rem] xl:text-2xl">{agent.name}</div>
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>
            <motion.p variants={fadeIn} className="text-sm text-[#8A8494] mt-5">
              Built for founders, builders, operators, and developers who move between agents all day.
            </motion.p>
          </motion.div>
        </div>
      </section>

      {/* Pain */}
      <section id="pain" className="scroll-mt-36 py-28 px-6 relative z-20 bg-black border-y border-white/5">
        <div className="max-w-6xl mx-auto">
          <div className="grid lg:grid-cols-[0.9fr_1.1fr] gap-12 items-start">
            <motion.div
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
            >
              <div className="text-sm uppercase tracking-[0.3em] text-purple-300/70 mb-5">The context tax</div>
              <h2 className="text-4xl md:text-6xl font-bold text-white tracking-tight leading-[1.05]">
                Your agents should not act like strangers.
              </h2>
            </motion.div>

            <div className="grid gap-4">
              {painPoints.map((point, index) => (
                <motion.div
                  key={point}
                  initial={{ opacity: 0, y: 18 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: index * 0.06 }}
                  className="rounded-2xl border border-white/10 bg-white/[0.025] p-5 text-base md:text-lg text-[#C9C9D1] leading-relaxed"
                >
                  {point}
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Dictation + Owl */}
      <section className="py-20 px-6 relative z-20 bg-black">
        <div className="max-w-6xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 32 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="grid md:grid-cols-[0.9fr_1.1fr] gap-10 md:gap-14 items-center rounded-[2rem] border border-white/10 bg-[#0A0A0A] p-8 md:p-12 overflow-hidden relative"
          >
            <div className="absolute top-0 left-0 w-80 h-80 bg-purple-500/10 blur-3xl rounded-full"></div>
            <div className="relative z-10 aspect-square max-w-sm mx-auto md:mx-0 rounded-[1.5rem] overflow-hidden border border-white/10 bg-black shadow-2xl">
              <video
                src="/owl.mp4"
                autoPlay
                loop
                muted
                playsInline
                className="w-full h-full object-cover"
              />
            </div>

            <div className="relative z-10">
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/[0.04] border border-white/10 text-[#B8B8B8] text-xs font-medium mb-6">
                <Icon icon="mdi:microphone" className="h-4 w-4 text-purple-200" />
                Dictation is the core workflow
              </div>
              <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tight mb-6">
                Voiyce is built for people who would rather speak than type.
              </h2>
              <p className="text-xl text-[#888888] font-light leading-relaxed max-w-2xl mb-8">
                Use the owl as your always-ready Mac dictation layer: hold a hotkey, talk naturally, and drop polished text into the app you are already using. Context and Talk modes stay available when you want the assistant to understand more of your workspace.
              </p>
              <div className="grid sm:grid-cols-3 gap-3">
                {[
                  ["Dictate", "Your everyday Wispr Flow-style workflow"],
                  ["Context", "Extra screen awareness when it helps"],
                  ["Talk", "A conversational layer for agent work"]
                ].map(([label, text]) => (
                  <div key={label} className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
                    <div className="text-white text-sm font-semibold">{label}</div>
                    <div className="text-[#777777] text-sm mt-2 leading-relaxed">{text}</div>
                  </div>
                ))}
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Product */}
      <section id="how-it-works" className="scroll-mt-36 py-36 px-6 relative z-20 bg-black">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-6xl font-bold text-white tracking-tight mb-6">One working record. Many tools.</h2>
            <p className="text-xl text-[#888888] font-light max-w-2xl mx-auto">
              Capture the useful parts of a session, then hand the right memory to the next agent.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-5 mb-16">
            {productSteps.map((step, index) => (
              <motion.div
                key={step.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.08 }}
                className="rounded-2xl border border-white/10 bg-white/[0.025] p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]"
              >
                <div className="text-sm text-purple-300 mb-4">0{index + 1}</div>
                <h3 className="text-xl font-semibold text-white mb-3">{step.title}</h3>
                <p className="text-[#888888] leading-relaxed">{step.description}</p>
              </motion.div>
            ))}
          </div>

          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
          >
            <HeroAnimation />
          </motion.div>
        </div>
      </section>

      {/* Use cases */}
      <section className="py-28 px-6 relative z-10 bg-black">
        <div className="max-w-6xl mx-auto">
          <div className="max-w-3xl mb-12">
            <div className="text-sm uppercase tracking-[0.3em] text-purple-300/70 mb-5">Concrete handoffs</div>
            <h2 className="text-4xl md:text-6xl font-bold text-white tracking-tight mb-6">Short requests. Full context behind them.</h2>
            <p className="text-xl text-[#888888] font-light">
              The prompt stays simple because Voiyce carries the backstory.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            {useCases.map((useCase) => (
              <motion.div
                key={useCase}
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                className="rounded-2xl border border-white/10 bg-[#0A0A0A] p-5 text-lg text-white"
              >
                &ldquo;{useCase}&rdquo;
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Before / After */}
      <section className="py-28 px-6 relative z-10 bg-black border-y border-white/5">
        <div className="max-w-6xl mx-auto grid lg:grid-cols-2 gap-6">
          <motion.div
            initial={{ opacity: 0, x: -24 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="rounded-[2rem] border border-white/10 bg-[#0A0A0A] p-8 md:p-10"
          >
            <div className="text-sm uppercase tracking-[0.25em] text-[#8A8A8A] mb-6">Before</div>
            <h3 className="text-3xl font-bold text-white mb-5">Manual context hauling.</h3>
            <p className="text-[#8F8F99] text-lg leading-relaxed">
              Screenshots, logs, repo notes, chat summaries, workflow state. You move it by hand every time the tool changes.
            </p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 24 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="rounded-[2rem] border border-purple-500/30 bg-gradient-to-br from-[#141118] via-[#0F0D13] to-[#0A0A0A] p-8 md:p-10 shadow-[0_0_80px_-30px_rgba(155,109,255,0.35)]"
          >
            <div className="text-sm uppercase tracking-[0.25em] text-purple-300/80 mb-6">After</div>
            <h3 className="text-3xl font-bold text-white mb-5">A context layer your agents can use.</h3>
            <p className="text-[#D7D1E8] text-lg leading-relaxed">
              Voiyce stores the useful parts and helps you brief the right agent when it is time to debug, build, write, or decide.
            </p>
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="scroll-mt-36 py-28 px-6 relative z-10 bg-black">
        <div className="max-w-6xl mx-auto">
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-4xl md:text-6xl font-bold text-white tracking-tight mb-6">Memory built for the work between tools.</h2>
            <p className="text-xl text-[#888888] font-light">
              Capture less by hand. Restart fewer conversations. Keep the trail of decisions intact.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map((feature, index) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.04 }}
                className="bg-[#0A0A0A] p-7 rounded-2xl border border-white/10 hover:border-white/20 transition-colors relative overflow-hidden min-h-[230px]"
              >
                <div className="absolute top-0 right-0 w-64 h-64 bg-purple-500/5 blur-3xl rounded-full"></div>
                <div className="relative z-10">
                  <div className="w-11 h-11 rounded-2xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center mb-6">
                    <Icon icon={feature.icon} className="w-6 h-6 text-purple-300" />
                  </div>
                  <h3 className="text-xl font-bold text-white mb-3 tracking-tight">{feature.title}</h3>
                  <p className="text-[#888888] text-base leading-relaxed font-light">{feature.description}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Trust */}
      <section id="trust" className="scroll-mt-36 py-28 px-6 relative z-10 bg-black border-y border-white/5">
        <div className="max-w-6xl mx-auto grid lg:grid-cols-[0.95fr_1.05fr] gap-12 items-start">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
          >
            <div className="text-sm uppercase tracking-[0.3em] text-purple-300/70 mb-5">Privacy principles</div>
            <h2 className="text-4xl md:text-6xl font-bold text-white tracking-tight mb-6 leading-[1.05]">Memory only works if you control it.</h2>
            <p className="text-xl text-[#888888] font-light leading-relaxed">
              Voiyce is designed around explicit capture, editable memory, and boundaries for sensitive information.
            </p>
          </motion.div>

          <div className="grid gap-4">
            {[
              "You decide when capture is on.",
              "Memory should be searchable, editable, and deletable by you.",
              "Credentials, payment details, and sensitive apps stay protected by default.",
              "Agents need permission before using private context or taking higher-risk actions."
            ].map((principle) => (
              <div key={principle} className="rounded-2xl border border-white/10 bg-[#0A0A0A] p-6 flex gap-4">
                <Icon icon="mdi:shield-check-outline" className="w-6 h-6 text-purple-300 shrink-0 mt-0.5" />
                <p className="text-[#C9C9D1] text-lg leading-relaxed">{principle}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-36 px-6 relative z-10 overflow-hidden bg-black">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(155,109,255,0.12)_0%,transparent_65%)]"></div>
        <motion.div
          initial={{ opacity: 0, y: 32 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="max-w-4xl mx-auto relative z-10 text-center"
        >
          <h2 className="text-5xl md:text-7xl font-bold text-white mb-8 tracking-tighter leading-[1.05]">
            Stop re-explaining your work to AI.
          </h2>
          <p className="text-xl md:text-2xl text-[#888888] font-light leading-relaxed mb-10 max-w-2xl mx-auto">
            Give Claude Code, Codex, Hermes Agent, OpenClaw, and Cursor the context they should already have.
          </p>
          <Link
            prefetch
            href={buildAuthHref("download")}
            className="inline-flex px-8 py-4 bg-white text-black hover:bg-[#EDEDED] rounded-full font-semibold text-lg transition-all shadow-[0_0_40px_-10px_rgba(255,255,255,0.15)] items-center justify-center"
          >
            Get early access
          </Link>
          <div className="text-sm text-[#8A8A8A] mt-6">
            For AI power users, builders, operators, developers, creators, and founders.
          </div>
        </motion.div>
      </section>

      {/* Footer */}
      <footer className="py-14 md:py-16 px-6 border-t border-white/5 text-center text-[#888888] text-sm relative z-10 bg-black">
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row items-center justify-between gap-8 md:gap-10">
          <div className="flex w-full md:w-auto items-center justify-start">
            <Image
              src="/voiyce_logo.png"
              alt="Voiyce Logo"
              width={320}
              height={160}
              className="h-28 sm:h-32 md:h-40 w-auto max-w-[min(320px,100%)] object-contain object-left opacity-95 hover:opacity-100 transition-opacity"
            />
          </div>
          <p>© 2026 Voiyce. All rights reserved.</p>
          <div className="flex gap-8">
            <a href="/privacy" className="hover:text-white transition-colors">
              Privacy
            </a>
            <a href="/terms" className="hover:text-white transition-colors">
              Terms
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
