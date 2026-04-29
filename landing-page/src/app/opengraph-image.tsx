import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Voiyce - Write at the speed of thought. Download for macOS.";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background:
            "radial-gradient(circle at 72% 18%, rgba(139, 92, 246, 0.32), transparent 32%), radial-gradient(circle at 18% 88%, rgba(255, 255, 255, 0.12), transparent 26%), #050505",
          color: "#f7f7f8",
          padding: "64px 72px",
          fontFamily: "Arial, Helvetica, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage:
              "linear-gradient(rgba(255,255,255,0.045) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.045) 1px, transparent 1px)",
            backgroundSize: "44px 44px",
            maskImage:
              "radial-gradient(ellipse 80% 64% at 50% 42%, black 32%, transparent 86%)",
          }}
        />

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 22,
            position: "relative",
          }}
        >
          <div
            style={{
              width: 74,
              height: 74,
              borderRadius: 22,
              background:
                "linear-gradient(135deg, rgba(168, 85, 247, 0.95), rgba(88, 28, 135, 0.92))",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 42,
              fontWeight: 800,
              boxShadow: "0 22px 58px rgba(139, 92, 246, 0.38)",
            }}
          >
            V
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            <div style={{ fontSize: 34, fontWeight: 800 }}>Voiyce</div>
            <div style={{ color: "#a7a4b4", fontSize: 24 }}>
              Native dictation for macOS
            </div>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: 28,
            maxWidth: 850,
            position: "relative",
          }}
        >
          <div
            style={{
              fontSize: 86,
              lineHeight: 0.98,
              letterSpacing: "-2px",
              fontWeight: 900,
            }}
          >
            Write at the speed of thought.
          </div>
          <div
            style={{
              fontSize: 31,
              lineHeight: 1.28,
              color: "#c9c6d5",
              maxWidth: 760,
            }}
          >
            Turn natural speech into polished text in any app.
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            position: "relative",
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 14,
              borderRadius: 999,
              background: "#ffffff",
              color: "#050505",
              padding: "18px 28px",
              fontSize: 28,
              fontWeight: 800,
            }}
          >
            <span style={{ fontSize: 30 }}>⌘</span>
            Download for macOS
          </div>
          <div style={{ color: "#8f8a9d", fontSize: 24 }}>
            voiyce-mac-app.vercel.app
          </div>
        </div>
      </div>
    ),
    size,
  );
}
