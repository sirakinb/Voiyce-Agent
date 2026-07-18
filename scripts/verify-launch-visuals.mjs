#!/usr/bin/env node

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const VIEWPORTS = [
  { name: "desktop-1440", width: 1440, height: 1100 },
  { name: "desktop-1280", width: 1280, height: 1000 },
  { name: "desktop-1024", width: 1024, height: 1000 },
  { name: "mobile-375", width: 375, height: 1200 },
  { name: "mobile-390", width: 390, height: 1200 },
  { name: "mobile-430", width: 430, height: 1200 },
];

const ROUTES = [
  {
    name: "home",
    path: "/",
    viewports: VIEWPORTS,
    expectedText: [
      "Stop re-explaining",
      "your work to AI.",
      "agent context layer",
      "Claude Code",
      "Codex",
      "Hermes Agent",
      "OpenClaw",
      "Cursor",
    ],
    homeChecks: true,
  },
  {
    name: "auth",
    path: "/auth?intent=download",
    viewports: [VIEWPORTS[0], VIEWPORTS[3]],
    expectedText: ["Create your account", "Continue to download"],
  },
  {
    name: "download",
    path: "/download?intent=download",
    viewports: [VIEWPORTS[0], VIEWPORTS[3]],
    expectedText: ["Create your account", "Continue to download"],
  },
  {
    name: "privacy",
    path: "/privacy",
    viewports: [VIEWPORTS[0], VIEWPORTS[3]],
    expectedText: ["Privacy Policy", "aki.b@pentridgemedia.com"],
  },
  {
    name: "terms",
    path: "/terms",
    viewports: [VIEWPORTS[0], VIEWPORTS[3]],
    expectedText: ["Terms of Service", "aki.b@pentridgemedia.com"],
  },
];

class CDP {
  static async connect(wsUrl) {
    const client = new CDP(wsUrl);
    await client.ready;
    return client;
  }

  constructor(wsUrl) {
    this.nextId = 1;
    this.pending = new Map();
    this.socket = new WebSocket(wsUrl);
    this.ready = new Promise((resolve, reject) => {
      this.socket.addEventListener("open", resolve, { once: true });
      this.socket.addEventListener("error", reject, { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (!message.id) {
        return;
      }
      const pending = this.pending.get(message.id);
      if (!pending) {
        return;
      }
      this.pending.delete(message.id);
      if (message.error) {
        pending.reject(new Error(`${message.error.message}: ${JSON.stringify(message.error.data ?? "")}`));
      } else {
        pending.resolve(message.result ?? {});
      }
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.socket.send(payload);
    });
  }

  close() {
    this.socket.close();
    return Promise.resolve();
  }
}

const args = parseArgs(process.argv.slice(2));
const baseUrl = (args.url ?? "").replace(/\/$/, "");
if (!baseUrl) {
  fail("Usage: scripts/verify-launch-visuals.mjs --url <base-url> [--output-dir <dir>] [--chrome-path <path>]");
}

const outputDir = args.outputDir ?? join(tmpdir(), `voiyce-launch-visuals-${Date.now()}`);
mkdirSync(outputDir, { recursive: true });

const chromePath = args.chromePath ?? process.env.CHROME_PATH ?? findChromePath();
if (!chromePath) {
  fail("Google Chrome or Chromium was not found. Set CHROME_PATH to run visual QA.");
}

let chrome;
let page;

try {
  const port = 41000 + Math.floor(Math.random() * 10000);
  const userDataDir = join(tmpdir(), `voiyce-chrome-profile-${Date.now()}-${process.pid}`);
  chrome = spawn(chromePath, [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--hide-scrollbars",
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`,
    "about:blank",
  ], {
    stdio: ["ignore", "ignore", "pipe"],
  });

  let stderr = "";
  chrome.stderr.on("data", (chunk) => {
    stderr += String(chunk);
  });

  const debuggerUrl = await waitForDebugger(port, stderr);
  const target = await createTarget(port);
  page = await CDP.connect(target.webSocketDebuggerUrl ?? debuggerUrl);
  await page.send("Page.enable");
  await page.send("Runtime.enable");
  await page.send("Emulation.setEmulatedMedia", {
    features: [{ name: "prefers-reduced-motion", value: "reduce" }],
  });

  const failures = [];
  const captures = [];

  for (const route of ROUTES) {
    for (const viewport of route.viewports) {
      const url = `${baseUrl}${route.path}`;
      const result = await verifyRoute(page, route, viewport, url, outputDir);
      failures.push(...result.failures);
      captures.push(result.screenshotPath);
    }
  }

  console.log(`Visual QA screenshots written to ${outputDir}`);
  for (const screenshotPath of captures) {
    console.log(`- ${screenshotPath}`);
  }

  if (failures.length > 0) {
    for (const failure of failures) {
      console.error(`error: ${failure}`);
    }
    process.exitCode = 1;
  }
} finally {
  if (page) {
    await page.close().catch(() => {});
  }
  if (chrome && !chrome.killed) {
    chrome.kill("SIGTERM");
  }
}

function parseArgs(rawArgs) {
  const parsed = {};
  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    switch (arg) {
      case "--url":
        parsed.url = rawArgs[++index];
        break;
      case "--output-dir":
        parsed.outputDir = rawArgs[++index];
        break;
      case "--chrome-path":
        parsed.chromePath = rawArgs[++index];
        break;
      case "-h":
      case "--help":
        parsed.help = true;
        break;
      default:
        fail(`Unknown argument: ${arg}`);
    }
  }
  return parsed;
}

function findChromePath() {
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
  ];
  return candidates.find((candidate) => fileExists(candidate));
}

async function verifyRoute(cdp, route, viewport, url, outputDir) {
  await cdp.send("Emulation.setDeviceMetricsOverride", {
    width: viewport.width,
    height: viewport.height,
    deviceScaleFactor: 1,
    mobile: viewport.width < 600,
  });
  await cdp.send("Page.navigate", { url });
  await waitForDocumentReady(cdp);
  await waitForImages(cdp);
  await delay(900);

  const checkResult = await evaluate(cdp, buildVisualCheckExpression(route, viewport), true);
  const anchorResult = route.homeChecks && viewport.width >= 768
    ? await evaluate(cdp, buildAnchorCheckExpression(), true)
    : { failures: [] };

  const screenshotPath = await captureScreenshot(cdp, route, viewport, outputDir);
  const failures = [
    ...checkResult.failures,
    ...anchorResult.failures,
  ].map((failure) => `${route.name} ${viewport.name}: ${failure}`);

  return { failures, screenshotPath };
}

function buildVisualCheckExpression(route, viewport) {
  return `(() => {
    const route = ${JSON.stringify(route)};
    const viewport = ${JSON.stringify(viewport)};
    const failures = [];
    const text = document.body?.innerText ?? "";

    for (const expected of route.expectedText) {
      if (!text.includes(expected)) {
        failures.push("missing expected text: " + expected);
      }
    }

    const scrollWidth = Math.max(
      document.documentElement.scrollWidth,
      document.body ? document.body.scrollWidth : 0
    );
    if (scrollWidth > window.innerWidth + 2) {
      failures.push("document has horizontal overflow: " + scrollWidth + "px > " + window.innerWidth + "px");
    }

    const clipped = findClippedText();
    if (clipped.length > 0) {
      failures.push("text clipping candidates: " + clipped.slice(0, 6).join(" | "));
    }

    const lowContrast = findColorContrastFailures();
    if (lowContrast.length > 0) {
      failures.push("color contrast failures: " + lowContrast.slice(0, 8).join(" | "));
    }

    if (route.homeChecks) {
      const nav = document.querySelector("nav");
      const h1 = document.querySelector("h1");
      if (nav && h1) {
        const navRect = nav.getBoundingClientRect();
        const h1Rect = h1.getBoundingClientRect();
        if (navRect.bottom > h1Rect.top - 4) {
          failures.push("fixed nav overlaps hero headline");
        }
      }

      const labels = ["Claude Code", "Codex", "Hermes Agent", "OpenClaw", "Cursor"];
      const labelRects = labels.map((label) => {
        const element = smallestTextElement(label);
        if (!element) {
          failures.push("missing visible agent label: " + label);
          return null;
        }
        const rect = element.getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) {
          failures.push("agent label has no visible box: " + label);
        }
        if (element.scrollWidth > element.clientWidth + 4) {
          failures.push("agent label clips horizontally: " + label);
        }
        return { label, rect };
      }).filter(Boolean);

      for (let i = 0; i < labelRects.length; i += 1) {
        for (let j = i + 1; j < labelRects.length; j += 1) {
          const first = labelRects[i];
          const second = labelRects[j];
          const overlapX = Math.max(0, Math.min(first.rect.right, second.rect.right) - Math.max(first.rect.left, second.rect.left));
          const overlapY = Math.max(0, Math.min(first.rect.bottom, second.rect.bottom) - Math.max(first.rect.top, second.rect.top));
          if (overlapX * overlapY > 1) {
            failures.push("agent labels overlap: " + first.label + " and " + second.label);
          }
        }
      }

      const openClaw = labelRects.find((item) => item.label === "OpenClaw");
      const cursor = labelRects.find((item) => item.label === "Cursor");
      if (openClaw && cursor && Math.abs(openClaw.rect.top - cursor.rect.top) < 8) {
        const gap = cursor.rect.left - openClaw.rect.right;
        if (gap < 8) {
          failures.push("OpenClaw crowds Cursor: " + Math.round(gap) + "px gap");
        }
      }

      const hermesImage = Array.from(document.images).find((img) => img.currentSrc.includes("/hermes-agent.png"));
      if (!hermesImage || !hermesImage.complete || hermesImage.naturalWidth <= 0) {
        failures.push("Hermes Agent local image is not loaded");
      }

      const openClawImage = Array.from(document.images).find((img) => img.currentSrc.includes("/openclaw.svg"));
      if (!openClawImage || !openClawImage.complete || openClawImage.naturalWidth <= 0) {
        failures.push("OpenClaw local image is not loaded");
      }

      for (const href of ["/auth?intent=download", "#how-it-works", "/privacy", "/terms"]) {
        if (!document.querySelector(\`a[href="\${href}"]\`)) {
          failures.push("missing expected link href: " + href);
        }
      }
    }

    return { failures, width: viewport.width, height: viewport.height };

    function visibleElement(element) {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== "none"
        && style.visibility !== "hidden"
        && Number(style.opacity) !== 0
        && rect.width > 0
        && rect.height > 0;
    }

    function smallestTextElement(label) {
      const matches = Array.from(document.querySelectorAll("body *"))
        .filter((element) => visibleElement(element))
        .filter((element) => (element.textContent ?? "").trim() === label)
        .sort((a, b) => {
          const ar = a.getBoundingClientRect();
          const br = b.getBoundingClientRect();
          return (ar.width * ar.height) - (br.width * br.height);
        });
      return matches[0] ?? null;
    }

    function findClippedText() {
      const candidates = Array.from(document.querySelectorAll("h1,h2,h3,p,a,button,label,li,input"));
      return candidates
        .filter((element) => visibleElement(element))
        .filter((element) => !(element.classList && element.classList.contains("skip-link")))
        .filter((element) => ((element.innerText || element.value || element.textContent || "").trim().length > 1))
        .filter((element) => {
          const style = window.getComputedStyle(element);
          const horizontalClip = element.scrollWidth > element.clientWidth + 4
            && style.overflowX !== "visible";
          const verticalClip = element.scrollHeight > element.clientHeight + 6
            && style.overflowY !== "visible";
          return horizontalClip || verticalClip;
        })
        .map((element) => {
          const text = (element.innerText || element.value || element.textContent || "").trim().replace(/\\s+/g, " ").slice(0, 80);
          return element.tagName.toLowerCase() + ": " + text;
        });
    }

    function findColorContrastFailures() {
      const candidates = Array.from(document.querySelectorAll("h1,h2,h3,p,a,button,label,li,input,span,div"));
      return candidates
        .filter((element) => visibleElement(element))
        .filter((element) => !element.disabled && !(element.classList && element.classList.contains("skip-link")))
        .filter((element) => directText(element).length > 1)
        .map((element) => {
          const style = window.getComputedStyle(element);
          const foreground = parseColor(textColor(element, style));
          const background = effectiveBackground(element);
          if (!foreground || !background) {
            return null;
          }
          const ratio = contrastRatio(foreground, background);
          const required = isLargeText(style) ? 3 : 4.5;
          if (ratio >= required) {
            return null;
          }
          const text = directText(element).replace(/\\s+/g, " ").slice(0, 56);
          return element.tagName.toLowerCase()
            + " \\"" + text + "\\" "
            + ratio.toFixed(2) + ":1 < " + required.toFixed(1) + ":1";
        })
        .filter(Boolean);
    }

    function directText(element) {
      if (element instanceof HTMLInputElement) {
        return (element.value || element.placeholder || "").trim();
      }

      let text = "";
      for (const node of element.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
          text += node.textContent || "";
        }
      }
      return text.trim();
    }

    function textColor(element, style) {
      if (element instanceof HTMLInputElement && !element.value && element.placeholder) {
        return window.getComputedStyle(element, "::placeholder").color;
      }

      return style.color;
    }

    function effectiveBackground(element) {
      const stack = [];
      let current = element;
      while (current) {
        stack.unshift(current);
        current = current.parentElement;
      }

      let color = { r: 0, g: 0, b: 0, a: 1 };
      for (const node of stack) {
        const parsed = parseColor(window.getComputedStyle(node).backgroundColor);
        if (parsed && parsed.a > 0) {
          color = blend(parsed, color);
        }
      }
      return color;
    }

    function parseColor(value) {
      const match = /^rgba?\\(([^)]+)\\)$/.exec(value);
      if (!match) {
        return null;
      }
      const parts = match[1]
        .split(",")
        .map((part) => part.trim())
        .map((part) => part.endsWith("%") ? (Number(part.slice(0, -1)) * 255 / 100) : Number(part));
      if (parts.length < 3 || parts.some((part) => Number.isNaN(part))) {
        return null;
      }
      return {
        r: clamp(parts[0], 0, 255),
        g: clamp(parts[1], 0, 255),
        b: clamp(parts[2], 0, 255),
        a: clamp(parts[3] ?? 1, 0, 1),
      };
    }

    function blend(foreground, background) {
      const alpha = foreground.a + background.a * (1 - foreground.a);
      if (alpha === 0) {
        return { r: 0, g: 0, b: 0, a: 0 };
      }
      return {
        r: ((foreground.r * foreground.a) + (background.r * background.a * (1 - foreground.a))) / alpha,
        g: ((foreground.g * foreground.a) + (background.g * background.a * (1 - foreground.a))) / alpha,
        b: ((foreground.b * foreground.a) + (background.b * background.a * (1 - foreground.a))) / alpha,
        a: alpha,
      };
    }

    function contrastRatio(first, second) {
      const lighter = Math.max(relativeLuminance(first), relativeLuminance(second));
      const darker = Math.min(relativeLuminance(first), relativeLuminance(second));
      return (lighter + 0.05) / (darker + 0.05);
    }

    function relativeLuminance(color) {
      const channels = [color.r, color.g, color.b].map((value) => {
        const normalized = value / 255;
        return normalized <= 0.03928
          ? normalized / 12.92
          : Math.pow((normalized + 0.055) / 1.055, 2.4);
      });
      return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2]);
    }

    function isLargeText(style) {
      const fontSize = Number.parseFloat(style.fontSize);
      const fontWeight = Number.parseInt(style.fontWeight, 10);
      return fontSize >= 24 || (fontSize >= 18.66 && fontWeight >= 600);
    }

    function clamp(value, min, max) {
      return Math.min(max, Math.max(min, value));
    }
  })()`;
}

function buildAnchorCheckExpression() {
  return `(async () => {
    const failures = [];
    for (const id of ["pain", "how-it-works", "features", "trust"]) {
      const target = document.getElementById(id);
      if (!target) {
        failures.push("missing anchor target: #" + id);
        continue;
      }
      window.scrollTo(0, 0);
      await new Promise((resolve) => requestAnimationFrame(resolve));
      target.scrollIntoView();
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      const top = target.getBoundingClientRect().top;
      if (top < -1 || top > 320) {
        failures.push("anchor #" + id + " lands at " + Math.round(top) + "px from top");
      }
    }
    window.scrollTo(0, 0);
    return { failures };
  })()`;
}

async function captureScreenshot(cdp, route, viewport, outputDir) {
  const dimensions = await evaluate(cdp, `(() => ({
    width: Math.ceil(Math.max(document.documentElement.scrollWidth, document.body.scrollWidth, window.innerWidth)),
    height: Math.ceil(Math.max(document.documentElement.scrollHeight, document.body.scrollHeight, window.innerHeight))
  }))()`);
  const width = Math.max(dimensions.width, viewport.width);
  const height = Math.min(Math.max(dimensions.height, viewport.height), 12000);
  const screenshot = await cdp.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width, height, scale: 1 },
  });
  const filePath = join(outputDir, `${route.name}-${viewport.name}.png`);
  const image = Buffer.from(screenshot.data, "base64");
  if (image.length < 5000) {
    throw new Error(`Screenshot looks too small for ${route.name} ${viewport.name}: ${image.length} bytes`);
  }
  writeFileSync(filePath, image);
  return filePath;
}

async function waitForDocumentReady(cdp) {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    const state = await evaluate(cdp, "document.readyState");
    if (state === "complete") {
      return;
    }
    await delay(100);
  }
  throw new Error("Timed out waiting for document.readyState=complete");
}

async function waitForImages(cdp) {
  await evaluate(cdp, `Promise.race([
    Promise.all(Array.from(document.images).map((image) => {
      if (image.complete) return true;
      return new Promise((resolve) => {
        image.onload = () => resolve(true);
        image.onerror = () => resolve(true);
      });
    })),
    new Promise((resolve) => setTimeout(resolve, 5000))
  ]).then(() => true)`, true);
}

async function evaluate(cdp, expression, awaitPromise = false) {
  const response = await cdp.send("Runtime.evaluate", {
    expression,
    awaitPromise,
    returnByValue: true,
  });
  if (response.exceptionDetails) {
    throw new Error(response.exceptionDetails.text ?? "Runtime.evaluate failed");
  }
  return response.result?.value;
}

async function waitForDebugger(port, stderr) {
  const versionUrl = `http://127.0.0.1:${port}/json/version`;
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const response = await fetch(versionUrl);
      if (response.ok) {
        const data = await response.json();
        return data.webSocketDebuggerUrl;
      }
    } catch {
      await delay(100);
    }
  }
  throw new Error(`Timed out waiting for Chrome debugger. Chrome stderr:\n${stderr}`);
}

async function createTarget(port) {
  const targetUrl = `http://127.0.0.1:${port}/json/new?${encodeURIComponent("about:blank")}`;
  let response = await fetch(targetUrl, { method: "PUT" });
  if (!response.ok) {
    response = await fetch(targetUrl);
  }
  if (!response.ok) {
    throw new Error(`Unable to create Chrome target: ${response.status}`);
  }
  return await response.json();
}

function fileExists(path) {
  return Boolean(path && existsSync(path));
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}
