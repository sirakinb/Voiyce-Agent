import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Mic, Search, Zap, MessageSquare, FileText, Edit3, Settings } from "lucide-react";

export default function Home() {
  const downloadUrl =
    process.env.NEXT_PUBLIC_DOWNLOAD_URL ??
    "https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg";

  return (
    <div className="min-h-screen bg-background text-foreground selection:bg-primary/30">
      {/* Navigation */}
      <header className="fixed top-0 left-0 right-0 z-50 border-b border-border/40 bg-background/80 backdrop-blur-md">
        <div className="container mx-auto px-4 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Image src="/images/voiyce_logo.png" alt="VOIYCE Logo" width={32} height={32} className="rounded-md" />
            <span className="font-bold text-xl tracking-tight">VOIYCE</span>
          </div>
          
          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-muted-foreground">
            <Link href="#how-it-works" className="hover:text-foreground transition-colors">How it works</Link>
            <Link href="#features" className="hover:text-foreground transition-colors">Features</Link>
            <Link href="#about" className="hover:text-foreground transition-colors">About Us</Link>
          </nav>
          
          <div className="flex items-center gap-4">
            <Link href="#download" className="hidden md:block text-sm font-medium hover:text-foreground transition-colors">
              Download
            </Link>
            <a href={downloadUrl} className="bg-primary text-primary-foreground px-4 py-2 rounded-full text-sm font-medium hover:bg-primary/90 transition-colors">
              Free Download
            </a>
          </div>
        </div>
      </header>

      <main className="pt-24 pb-16">
        {/* Hero Section */}
        <section className="container mx-auto px-4 pt-20 pb-32 text-center">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-secondary text-secondary-foreground text-sm font-medium mb-8 border border-border/50">
            <span className="flex h-2 w-2 rounded-full bg-primary animate-pulse"></span>
            VOIYCE is now available for Mac
          </div>
          
          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight mb-6 max-w-4xl mx-auto leading-tight">
            Turn what you say <br className="hidden md:block" />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-primary to-purple-400">
              into what gets done
            </span>
          </h1>
          
          <p className="text-xl text-muted-foreground mb-10 max-w-2xl mx-auto leading-relaxed">
            VOIYCE is the first AI agent that turns your voice instructions into finished tasks. Reply to messages, ask questions, and delegate tasks without ever leaving your current workflow.
          </p>
          
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a href={downloadUrl} className="w-full sm:w-auto bg-primary text-primary-foreground px-8 py-4 rounded-full text-lg font-medium hover:bg-primary/90 transition-colors flex items-center justify-center gap-2">
              Download for Mac <ArrowRight className="w-5 h-5" />
            </a>
            <Link href="#demo" className="w-full sm:w-auto bg-secondary text-secondary-foreground px-8 py-4 rounded-full text-lg font-medium hover:bg-secondary/80 transition-colors flex items-center justify-center gap-2 border border-border/50">
              Watch Demo
            </Link>
          </div>
        </section>

        {/* Value Prop Section */}
        <section id="how-it-works" className="container mx-auto px-4 py-24 border-t border-border/40">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-5xl font-bold mb-6">Your Voice is now your most powerful tool</h2>
            <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
              Press the shortcut key. Say what you want. Watch it get done. No new tabs. No context switching. No friction between thought and action. Pure flow.
            </p>
          </div>
          
          <div className="relative rounded-2xl overflow-hidden border border-border/50 bg-secondary/30 aspect-video max-w-5xl mx-auto flex items-center justify-center">
            {/* Placeholder for video/demo */}
            <div className="absolute inset-0 bg-gradient-to-br from-primary/10 to-background/50"></div>
            <div className="relative z-10 flex flex-col items-center">
              <div className="w-20 h-20 bg-primary/20 rounded-full flex items-center justify-center mb-4 border border-primary/30 backdrop-blur-sm">
                <Mic className="w-10 h-10 text-primary" />
              </div>
              <p className="text-lg font-medium">"Reply to this email and say I'll be there at 5"</p>
            </div>
          </div>
        </section>

        {/* Features Section */}
        <section id="features" className="container mx-auto px-4 py-24 border-t border-border/40">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-5xl font-bold mb-6">Built for deep workers</h2>
            <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
              If your job requires juggling apps, docs, messages, and research all day — VOIYCE is your unfair advantage.
            </p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {[
              { icon: MessageSquare, title: "Reply to emails and messages", desc: "Perfect replies in one tap." },
              { icon: FileText, title: "Research and create docs", desc: "Blank page to polished drafts in seconds." },
              { icon: Search, title: "Instant Search", desc: "Zero friction. Infinite knowledge." },
              { icon: Zap, title: "Feedback and ideation", desc: "Your second brain, on demand." },
              { icon: Edit3, title: "Modify tone and text", desc: "Edit without the headache." },
              { icon: Mic, title: "Dictation", desc: "Write at the speed of thought." },
            ].map((feature, i) => (
              <div key={i} className="p-6 rounded-2xl border border-border/50 bg-secondary/20 hover:bg-secondary/40 transition-colors">
                <div className="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center mb-6 border border-primary/20">
                  <feature.icon className="w-6 h-6 text-primary" />
                </div>
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-muted-foreground">{feature.desc}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Stats Section */}
        <section className="container mx-auto px-4 py-24 border-t border-border/40 bg-secondary/10">
          <div className="max-w-4xl mx-auto text-center">
            <h2 className="text-3xl md:text-5xl font-bold mb-6">
              You're not unproductive.<br />
              <span className="text-muted-foreground">You're interrupted.</span>
            </h2>
            <p className="text-xl text-muted-foreground mb-16">
              The average knowledge worker spends 3 hours typing and switches tabs 1,100 times per day. It's time to reclaim your time and focus.
            </p>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div className="p-8 rounded-2xl bg-background border border-border/50">
                <div className="text-4xl font-bold text-primary mb-2">5x</div>
                <div className="text-lg font-medium text-muted-foreground">Faster typing</div>
              </div>
              <div className="p-8 rounded-2xl bg-background border border-border/50">
                <div className="text-4xl font-bold text-primary mb-2">12x</div>
                <div className="text-lg font-medium text-muted-foreground">Faster email replies</div>
              </div>
              <div className="p-8 rounded-2xl bg-background border border-border/50">
                <div className="text-4xl font-bold text-primary mb-2">70%</div>
                <div className="text-lg font-medium text-muted-foreground">Fewer tabs opened</div>
              </div>
            </div>
          </div>
        </section>

        {/* CTA Section */}
        <section id="download" className="container mx-auto px-4 py-32 text-center">
          <div className="max-w-3xl mx-auto bg-gradient-to-b from-secondary/50 to-background border border-border/50 rounded-3xl p-12 relative overflow-hidden">
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-1/2 bg-primary/10 blur-3xl rounded-full"></div>
            
            <div className="relative z-10">
              <h2 className="text-4xl md:text-5xl font-bold mb-6">Ready to reclaim your time and focus?</h2>
              <p className="text-xl text-muted-foreground mb-10">
                Your voice is your most powerful tool. Start using it.
              </p>
              <a href={downloadUrl} className="inline-flex bg-primary text-primary-foreground px-10 py-5 rounded-full text-xl font-medium hover:bg-primary/90 transition-colors shadow-lg shadow-primary/20">
                Download for free
              </a>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-border/40 bg-secondary/20 pt-16 pb-8">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-16">
            <div className="col-span-2">
              <div className="flex items-center gap-2 mb-6">
                <Image src="/images/voiyce_logo.png" alt="VOIYCE Logo" width={24} height={24} className="rounded-md grayscale opacity-80" />
                <span className="font-bold text-lg text-muted-foreground">VOIYCE</span>
              </div>
              <p className="text-muted-foreground max-w-sm">
                Turn what you say into what gets done. The first AI agent that lives in your workflow.
              </p>
            </div>
            
            <div>
              <h4 className="font-semibold mb-4">Company</h4>
              <ul className="space-y-3 text-muted-foreground">
                <li><Link href="#" className="hover:text-foreground transition-colors">Homepage</Link></li>
                <li><Link href="#" className="hover:text-foreground transition-colors">About Us</Link></li>
                <li><Link href="#" className="hover:text-foreground transition-colors">Contact</Link></li>
              </ul>
            </div>
            
            <div>
              <h4 className="font-semibold mb-4">Product</h4>
              <ul className="space-y-3 text-muted-foreground">
                <li><Link href="#" className="hover:text-foreground transition-colors">Features</Link></li>
                <li><Link href="#" className="hover:text-foreground transition-colors">Download</Link></li>
              </ul>
            </div>
          </div>
          
          <div className="flex flex-col md:flex-row items-center justify-between pt-8 border-t border-border/40 text-sm text-muted-foreground">
            <p>© 2026 VOIYCE — All rights reserved</p>
            <div className="flex items-center gap-6 mt-4 md:mt-0">
              <Link href="#" className="hover:text-foreground transition-colors">Privacy Policy</Link>
              <Link href="#" className="hover:text-foreground transition-colors">Terms & Conditions</Link>
              <span>Contact us at support@voiyce.com</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
