"use client";

import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Icon } from "@iconify/react";
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

const pricingPlans = [
  {
    name: "Pro Monthly",
    price: "$12",
    cadence: "/ month",
    badge: "Flexible",
    description: "Full Pro access with a simple monthly subscription.",
    highlight: false,
    valueLine: "Cancel anytime",
    features: [
      "Unlimited dictation after trial",
      "Prioritized support",
      "Early access to new features",
      "Native macOS voice workflow"
    ]
  },
  {
    name: "Pro Yearly",
    price: "$120",
    cadence: "/ year",
    badge: "Best Value",
    description: "Two months free compared with paying monthly all year.",
    highlight: true,
    valueLine: "Works out to $10/month",
    features: [
      "Unlimited dictation after trial",
      "Prioritized support",
      "Early access to new features",
      "Best long-term value"
    ]
  }
];

const AUTH_INTENTS = ["download", "monthly", "yearly"] as const;

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
      {/* Subtle Ambient Background */}
      <div className="fixed inset-0 pointer-events-none z-0 flex justify-center">
        <div className="absolute top-[-20%] w-[1000px] h-[800px] bg-purple-900/15 blur-[150px] rounded-full mix-blend-screen"></div>
        <div className="absolute top-0 inset-x-0 h-[600px] bg-[linear-gradient(to_bottom,rgba(255,255,255,0.03)_1px,transparent_1px),linear-gradient(to_right,rgba(255,255,255,0.03)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)]"></div>
      </div>

      {/* Floating Navigation Bar */}
      <motion.nav
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        className={`fixed top-6 left-1/2 -translate-x-1/2 w-[calc(100%-3rem)] max-w-4xl z-50 transition-all duration-500 ${
          scrolled
            ? "bg-[#0A0A0A]/80 backdrop-blur-2xl border border-white/10 shadow-[0_8px_32px_rgba(0,0,0,0.4)]"
            : "bg-transparent border-transparent"
        } rounded-full px-6 py-5 flex items-center justify-center`}
      >
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-6 mx-auto w-full max-w-4xl flex-wrap">
          <img src="/voiyce_logo.png" alt="Voiyce Logo" className="h-[160px] w-auto object-contain -my-[68px]" />
          <div className="hidden md:flex items-center gap-6 text-sm font-medium text-[#888888]">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#how-it-works" className="hover:text-white transition-colors">How it works</a>
            <a href="#pricing" className="hover:text-white transition-colors">Pricing</a>
          </div>
          <Link
            prefetch
            href={buildAuthHref("download")}
            className="shrink-0 inline-flex items-center justify-center gap-2 rounded-full bg-white px-6 py-2.5 text-sm font-semibold text-black shadow-[0_0_20px_-5px_rgba(255,255,255,0.2)] transition-colors hover:bg-[#EDEDED]"
          >
            <Icon icon="mdi:apple" className="h-5 w-5" />
            Download for MacOS
          </Link>
        </div>
      </motion.nav>

      {/* Hero Section */}
      <section className="pt-40 pb-32 px-6 relative z-10 flex flex-col items-center text-center min-h-[90vh] justify-center overflow-hidden">
        {/* Wispr-style flowing particle background */}
        <div className="absolute inset-0 z-0">
          <HeroParticles />
        </div>

        <div className="max-w-4xl mx-auto relative z-10">
          <motion.div
            initial="initial"
            animate="animate"
            variants={staggerContainer}
            className="flex flex-col items-center"
          >
            <motion.div variants={fadeIn} className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/[0.03] border border-white/10 text-[#888888] text-xs font-medium mb-8 backdrop-blur-md">
              <span className="w-2 h-2 rounded-full bg-purple-500 animate-pulse"></span>
              Voiyce 1.0 for MacOS is here
            </motion.div>

            <motion.h1 variants={fadeIn} className="text-6xl md:text-8xl font-bold text-white tracking-tighter mb-8 leading-[1.05]">
              Write at the speed <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-b from-white to-white/40">
                of thought.
              </span>
            </motion.h1>

            <motion.p variants={fadeIn} className="text-xl md:text-2xl text-[#888888] mb-12 leading-relaxed max-w-2xl font-light">
              Voiyce captures your voice and instantly turns it into perfectly formatted text in any app. No more typing. Accelerate your productivity.
            </motion.p>

            <motion.div variants={fadeIn} className="flex w-full justify-center">
              <Link
                prefetch
                href={buildAuthHref("download")}
                className="w-full max-w-md px-8 py-4 bg-white text-black hover:bg-[#EDEDED] rounded-full font-semibold text-lg transition-all shadow-[0_0_40px_-10px_rgba(255,255,255,0.15)] flex items-center justify-center gap-3"
              >
                <Icon icon="mdi:apple" className="w-6 h-6" />
                Download for MacOS
              </Link>
            </motion.div>
            <motion.p variants={fadeIn} className="text-sm text-[#666666] mt-6">
              Try Voiyce for free. No credit card required.
            </motion.p>
          </motion.div>
        </div>
      </section>

      {/* The Magic (Animated Before/After) */}
      <section id="how-it-works" className="scroll-mt-36 py-40 px-6 relative z-20 bg-black">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tight mb-6">Speak naturally. We handle the rest.</h2>
            <p className="text-xl text-[#888888] font-light max-w-2xl mx-auto">
              Voiyce doesn't just transcribe—it understands context, removes filler words, and adds perfect punctuation instantly.
            </p>
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

      {/* Bento Grid (Features) */}
      <section id="features" className="scroll-mt-36 py-24 px-6 relative z-10 bg-black">
        <div className="max-w-6xl mx-auto">
          <div className="grid md:grid-cols-3 gap-6">
            
            {/* Feature 1: Native to macOS */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="md:col-span-2 bg-[#0A0A0A] p-10 rounded-[2rem] border border-white/10 hover:border-white/20 transition-colors relative overflow-hidden group flex flex-col justify-between min-h-[360px]"
            >
              <div className="absolute top-0 right-0 w-96 h-96 bg-blue-500/5 blur-3xl rounded-full transition-transform duration-700 group-hover:scale-110"></div>
              <div className="relative z-10">
                <h3 className="text-3xl font-bold text-white mb-4 tracking-tight">Native to macOS.</h3>
                <p className="text-[#888888] text-lg leading-relaxed max-w-md font-light">
                  Hold a single hotkey and dictate directly into Slack, Notion, Chrome, or any text field on your Mac. No copy-pasting required.
                </p>
              </div>
              
              {/* Mini UI element */}
              <div className="mt-10 relative z-10">
                <div className="inline-flex items-center gap-3 bg-[#111111] border border-white/10 rounded-full px-5 py-3 shadow-xl">
                  <div className="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse shadow-[0_0_10px_rgba(239,68,68,0.5)]"></div>
                  <span className="text-white text-sm font-medium">Listening...</span>
                  <div className="w-[1px] h-4 bg-white/20 mx-2"></div>
                  <div className="flex items-center gap-1.5 text-[#888888] text-xs">
                    <span>Hold</span>
                    <kbd className="px-2 py-1 bg-white/10 rounded border border-white/10 font-sans text-[10px] text-white">⌃ Control</kbd>
                  </div>
                </div>
              </div>
            </motion.div>
            
            {/* Feature 2: Blazing Fast */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.1 }}
              className="bg-[#0A0A0A] p-10 rounded-[2rem] border border-white/10 hover:border-white/20 transition-colors relative overflow-hidden group flex flex-col justify-between min-h-[360px]"
            >
              <div className="absolute top-0 right-0 w-64 h-64 bg-orange-500/5 blur-3xl rounded-full transition-transform duration-700 group-hover:scale-110"></div>
              <div className="relative z-10">
                <h3 className="text-3xl font-bold text-white mb-4 tracking-tight">3x Faster.</h3>
                <p className="text-[#888888] text-lg leading-relaxed font-light">
                  You type at 40 words per minute. You speak at 150. Stop fighting your keyboard and reclaim hours of your week.
                </p>
              </div>
            </motion.div>
            
            {/* Feature 3: Personal AI (Owl) */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2 }}
              className="md:col-span-3 bg-gradient-to-br from-[#111111] to-[#0A0A0A] p-10 md:p-12 rounded-[2rem] border border-white/10 relative overflow-hidden flex flex-col md:flex-row items-center gap-12"
            >
              <div className="relative z-10 flex-1">
                <h3 className="text-3xl md:text-4xl font-bold text-white mb-4 tracking-tight">Your personal AI agent.</h3>
                <p className="text-[#888888] text-xl leading-relaxed max-w-2xl font-light mb-8">
                  Voiyce learns your specific vocabulary, acronyms, and teammates' names. It adapts to your style over time, so you never have to correct the same mistake twice.
                </p>
                <div className="flex flex-wrap gap-3">
                  <span className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg text-sm text-slate-300">Custom Vocabulary</span>
                  <span className="text-sm text-[#666666] flex items-center">"Kubernetes" not "coober netties"</span>
                </div>
              </div>
              
              <div className="relative z-10 w-full md:w-1/3 aspect-square rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-black">
                <video 
                  src="/owl.mp4" 
                  autoPlay 
                  loop 
                  muted 
                  playsInline
                  className="w-full h-full object-cover"
                />
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Social Proof */}
      <section className="py-32 px-6 relative z-10 bg-black">
        <div className="max-w-4xl mx-auto text-center">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
          >
            <div className="flex justify-center mb-10">
              <div className="flex -space-x-4">
                {[
                  "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face",
                  "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=100&h=100&fit=crop&crop=face",
                  "https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f?w=100&h=100&fit=crop&crop=face",
                  "https://images.unsplash.com/photo-1589156229687-496a31ad1d1f?w=100&h=100&fit=crop&crop=face",
                  "https://images.unsplash.com/photo-1463453091185-61582044d556?w=100&h=100&fit=crop&crop=face"
                ].map((src, i) => (
                  <img key={i} src={src} alt="User avatar" className={`w-14 h-14 rounded-full border-2 border-black object-cover shadow-lg z-[${5-i}]`} />
                ))}
              </div>
            </div>
            <p className="text-3xl md:text-5xl text-white font-medium mb-12 tracking-tight leading-tight">
              "I stopped typing last month. It's like having a chief of staff sitting on my menu bar."
            </p>
            <div className="flex items-center justify-center gap-4">
              <div className="text-left">
                <p className="text-white font-medium text-lg">Sarah J.</p>
                <p className="text-[#888888] text-sm">Product Manager</p>
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="scroll-mt-36 py-40 px-6 relative z-10 overflow-hidden bg-black border-t border-white/5">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(255,255,255,0.03)_0%,transparent_70%)]"></div>
        
        <motion.div 
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="max-w-6xl mx-auto relative z-10"
        >
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-5xl md:text-7xl font-bold text-white mb-8 tracking-tighter leading-[1.05]">
              Start free.
              <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-b from-white to-white/40">
                Upgrade only if it earns it.
              </span>
            </h2>

            <p className="text-xl md:text-2xl text-[#888888] font-light leading-relaxed">
              Every account starts with a free Voiyce Pro trial. You get up to 2,500 words over 7 days, no credit card required. If it fits your workflow, choose the plan that keeps you flowing.
            </p>

            <p className="mt-4 text-base text-purple-300/70 font-light">
              Already subscribed to Pentridge? Voiyce is included in your subscription.{" "}
              <a href="#pentridge-labs" className="text-purple-300 underline underline-offset-4 decoration-purple-400/30 hover:decoration-purple-400/60 transition-colors">
                See details below
              </a>
            </p>
          </div>

          <div className="grid lg:grid-cols-2 gap-6">
            {pricingPlans.map((plan) => (
              <div
                key={plan.name}
                className={`relative rounded-[2rem] border p-8 md:p-10 overflow-hidden ${
                  plan.highlight
                    ? "bg-gradient-to-br from-[#141118] via-[#0F0D13] to-[#0A0A0A] border-purple-500/30 shadow-[0_0_80px_-30px_rgba(155,109,255,0.35)]"
                    : "bg-[#0A0A0A] border-white/10"
                }`}
              >
                <div className="absolute top-0 right-0 w-80 h-80 bg-purple-500/10 blur-3xl rounded-full"></div>

                <div className="relative z-10">
                  <div className="flex items-start justify-between gap-6 mb-8">
                    <div>
                      <div className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold mb-4 ${
                        plan.highlight
                          ? "bg-purple-500/15 text-purple-200 border border-purple-400/20"
                          : "bg-white/5 text-[#BBBBBB] border border-white/10"
                      }`}>
                        {plan.badge}
                      </div>
                      <h3 className="text-3xl font-bold text-white tracking-tight">{plan.name}</h3>
                      <p className="text-[#888888] text-lg font-light mt-3 max-w-md">{plan.description}</p>
                    </div>

                    <div className="text-right shrink-0">
                      <div className="text-5xl font-bold text-white tracking-tight">{plan.price}</div>
                      <div className="text-[#888888] mt-2">{plan.cadence}</div>
                    </div>
                  </div>

                  <div className={`rounded-2xl border p-5 mb-8 ${
                    plan.highlight ? "border-purple-500/20 bg-black/30" : "border-white/10 bg-white/[0.02]"
                  }`}>
                    <div className="text-sm uppercase tracking-[0.24em] text-[#777777] mb-2">Included</div>
                    <div className="text-white text-lg font-medium">{plan.valueLine}</div>
                    <p className="text-[#8A8A94] text-sm mt-2">
                      Upgrade anytime during trial or when your trial ends.
                    </p>
                  </div>

                  <div className="space-y-4 mb-10">
                    {plan.features.map((feature) => (
                      <div key={feature} className="flex items-center gap-3 text-[#D9D9DD]">
                        <div className={`w-5 h-5 rounded-full flex items-center justify-center ${
                          plan.highlight ? "bg-purple-500/15" : "bg-white/5"
                        }`}>
                          <Icon icon="mdi:check" className={`w-3.5 h-3.5 ${plan.highlight ? "text-purple-200" : "text-white"}`} />
                        </div>
                        <span>{feature}</span>
                      </div>
                    ))}
                  </div>

                  <Link
                    prefetch
                    href={buildAuthHref(plan.name === "Pro Monthly" ? "monthly" : "yearly")}
                    className={`w-full px-8 py-4 rounded-full font-semibold text-lg transition-all flex items-center justify-center gap-3 ${
                    plan.highlight
                      ? "bg-white text-black hover:bg-[#EDEDED]"
                      : "bg-transparent text-white hover:bg-white/5 border border-white/10"
                  }`}>
                    Get Started
                  </Link>
                </div>
              </div>
            ))}
          </div>

          {/* Pentridge Labs Upsell */}
          <motion.div
            id="pentridge-labs"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="scroll-mt-36 mt-10 rounded-[2rem] border border-purple-500/20 bg-gradient-to-r from-[#0F0A18] via-[#110D17] to-[#0F0A18] p-8 md:p-10 relative overflow-hidden"
          >
            <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(ellipse_at_top_left,rgba(168,85,247,0.08)_0%,transparent_60%)]" />
            <div className="relative z-10 flex flex-col md:flex-row items-start justify-between gap-8">
              <div className="flex-1">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-500/10 border border-purple-400/20 text-purple-200 text-xs font-semibold mb-4">
                  <span className="w-1.5 h-1.5 rounded-full bg-purple-400" />
                  Pentridge Labs
                </div>
                <h3 className="text-2xl md:text-3xl font-bold text-white tracking-tight mb-3">
                  Get the full suite for $20/mo
                </h3>
                <p className="text-[#999] text-lg font-light leading-relaxed max-w-xl mb-5">
                  One subscription. Four tools. Access AlignoPM, AlignoCRM, Voiyce &amp; DropCard — no separate billing for each app.
                </p>
                <div className="flex flex-wrap gap-3">
                  <span className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg text-sm text-slate-300">Voiyce included</span>
                  <span className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg text-sm text-slate-300">Up to unlimited words</span>
                  <span className="px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg text-sm text-slate-300">All apps, one price</span>
                </div>
              </div>
              <a
                href="https://pentridgemedia.com/labs"
                target="_blank"
                rel="noopener noreferrer"
                className="shrink-0 inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-600 to-pink-600 px-8 py-4 text-lg font-semibold text-white shadow-[0_0_30px_-8px_rgba(168,85,247,0.4)] transition-all hover:shadow-[0_0_40px_-8px_rgba(168,85,247,0.6)] hover:scale-[1.02]"
              >
                Learn More
                <Icon icon="mdi:arrow-right" className="w-5 h-5" />
              </a>
            </div>
          </motion.div>

          <div className="text-center mt-10 max-w-3xl mx-auto">
            <p className="text-sm text-[#666666] leading-relaxed">
              Trial ends when 7 days pass or 2,500 words are used, whichever comes first. After that, choose Monthly, Yearly, or subscribe through Pentridge Labs to keep dictating.
            </p>
          </div>
        </motion.div>
      </section>

      {/* Footer */}
      <footer className="py-14 md:py-16 px-6 border-t border-white/5 text-center text-[#888888] text-sm relative z-10 bg-black">
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row items-center justify-between gap-8 md:gap-10">
          <div className="flex w-full md:w-auto items-center justify-start">
            <img
              src="/voiyce_logo.png"
              alt="Voiyce Logo"
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
