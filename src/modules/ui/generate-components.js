// Generate all 99 original components + 6 comparison components

const components = [];

// Hero
components.push({
  type: "hero",
  id: "hero",
  x: 0,
  y: 0,
  width: 1920,
  height: 700
});

// Sections (15)
const sections = [
  { y: 800, content: "3D Card Effect", size: 48 },
  { y: 1460, content: "Spotlight Cards", size: 48 },
  { y: 2160, content: "Glass Morphism", size: 48 },
  { y: 2960, content: "Text Effects", size: 48 },
  { y: 3760, content: "Interactive Buttons", size: 48 },
  { y: 4560, content: "Input Fields", size: 48 },
  { y: 5160, content: "Progress & Loaders", size: 48 },
  { y: 5960, content: "Badges & Tooltips", size: 48 },
  { y: 6760, content: "Background Effects", size: 48 },
  { y: 7560, content: "Hover Effects", size: 48 },
  { y: 8360, content: "Component Grid", size: 48 },
  { y: 9160, content: "Advanced Features", size: 48 },
  { y: 9960, content: "Performance", size: 48 },
  { y: 10760, content: "Responsive Design", size: 48 },
  { y: 11560, content: "Accessibility", size: 48 }
];

sections.forEach((sec, i) => {
  components.push({
    type: "section",
    id: `sec${i + 1}`,
    x: 160,
    y: sec.y,
    content: sec.content,
    size: sec.size
  });
});

// Descriptions (15)
const descriptions = [
  { y: 870, content: "A card perspective effect, hover over the card to elevate card elements." },
  { y: 1530, content: "Spotlight effect that follows your cursor, creating an immersive experience." },
  { y: 2230, content: "Glassmorphism cards with blur and transparency effects." },
  { y: 3030, content: "Animated text effects with gradients and transitions." },
  { y: 3830, content: "Interactive buttons with hover states and animations." },
  { y: 4630, content: "Styled input fields with focus effects." },
  { y: 5230, content: "Progress bars and loading animations." },
  { y: 6030, content: "Badges and tooltips for additional information." },
  { y: 6830, content: "Animated background effects and patterns." },
  { y: 7630, content: "Cards with hover effects and transformations." },
  { y: 8430, content: "Grid layout with multiple components." },
  { y: 9230, content: "Advanced features and interactions." },
  { y: 10030, content: "Optimized for 60 FPS performance." },
  { y: 10830, content: "Responsive across all screen sizes." },
  { y: 11630, content: "Built with accessibility in mind." }
];

descriptions.forEach((desc, i) => {
  components.push({
    type: "desc",
    id: `desc${i + 1}`,
    x: 160,
    y: desc.y,
    content: desc.content,
    size: 18
  });
});

// 3D Cards (6)
for (let i = 0; i < 6; i++) {
  components.push({
    type: "card3d",
    id: `card${i + 1}`,
    x: 160 + (i % 3) * 620,
    y: 960 + Math.floor(i / 3) * 420,
    width: 580,
    height: 380,
    title: `3D Card ${i + 1}`,
    content: "Hover to see the 3D effect"
  });
}

// Spotlight Cards (5)
for (let i = 0; i < 5; i++) {
  components.push({
    type: "spotlight",
    id: `spot${i + 1}`,
    x: 160 + (i % 3) * 620,
    y: 1620 + Math.floor(i / 3) * 420,
    width: 580,
    height: 380,
    title: `Spotlight ${i + 1}`,
    content: "Move your cursor to see the spotlight"
  });
}

// Glass Cards (7)
for (let i = 0; i < 7; i++) {
  components.push({
    type: "glass",
    id: `glass${i + 1}`,
    x: 160 + (i % 3) * 620,
    y: 2320 + Math.floor(i / 3) * 420,
    width: 580,
    height: 380,
    title: `Glass Card ${i + 1}`,
    content: "Glassmorphism effect"
  });
}

// Text Effects (7)
for (let i = 0; i < 7; i++) {
  components.push({
    type: "textfx",
    id: `textfx${i + 1}`,
    x: 160 + (i % 4) * 460,
    y: 3120 + Math.floor(i / 4) * 300,
    width: 420,
    height: 260,
    text: `Text Effect ${i + 1}`,
    effect: ["gradient", "glow", "shadow", "outline", "wave", "pulse", "shimmer"][i]
  });
}

// Buttons (12)
for (let i = 0; i < 12; i++) {
  components.push({
    type: "button",
    id: `btn${i + 1}`,
    x: 160 + (i % 4) * 460,
    y: 3920 + Math.floor(i / 4) * 180,
    width: 420,
    height: 140,
    text: `Button ${i + 1}`,
    variant: ["primary", "secondary", "outline", "ghost"][i % 4]
  });
}

// Input Fields (3)
for (let i = 0; i < 3; i++) {
  components.push({
    type: "input",
    id: `input${i + 1}`,
    x: 160 + i * 620,
    y: 4720,
    width: 580,
    height: 80,
    placeholder: `Input Field ${i + 1}`,
    label: `Label ${i + 1}`
  });
}

// Progress Bars (3)
for (let i = 0; i < 3; i++) {
  components.push({
    type: "progress",
    id: `progress${i + 1}`,
    x: 160 + i * 620,
    y: 5320,
    width: 580,
    height: 60,
    value: (i + 1) * 30,
    label: `Progress ${(i + 1) * 30}%`
  });
}

// Loaders (6)
for (let i = 0; i < 6; i++) {
  components.push({
    type: "loader",
    id: `loader${i + 1}`,
    x: 160 + (i % 3) * 620,
    y: 5460 + Math.floor(i / 3) * 220,
    width: 580,
    height: 180,
    variant: ["spinner", "dots", "bars", "pulse", "ring", "wave"][i]
  });
}

// Badges (5)
for (let i = 0; i < 5; i++) {
  components.push({
    type: "badge",
    id: `badge${i + 1}`,
    x: 160 + i * 380,
    y: 6120,
    width: 340,
    height: 80,
    text: `Badge ${i + 1}`,
    variant: ["default", "success", "warning", "error", "info"][i]
  });
}

// Tooltips (4)
for (let i = 0; i < 4; i++) {
  components.push({
    type: "tooltip",
    id: `tooltip${i + 1}`,
    x: 160 + i * 480,
    y: 6260,
    width: 440,
    height: 120,
    text: `Hover me ${i + 1}`,
    tooltip: `Tooltip content ${i + 1}`
  });
}

// Background Effects (5)
for (let i = 0; i < 5; i++) {
  components.push({
    type: "bgfx",
    id: `bgfx${i + 1}`,
    x: 160 + (i % 3) * 620,
    y: 6920 + Math.floor(i / 3) * 420,
    width: 580,
    height: 380,
    effect: ["gradient", "particles", "waves", "grid", "noise"][i]
  });
}

// Hover Cards (4)
for (let i = 0; i < 4; i++) {
  components.push({
    type: "hover",
    id: `hover${i + 1}`,
    x: 160 + i * 480,
    y: 7720,
    width: 440,
    height: 320,
    title: `Hover Card ${i + 1}`,
    content: "Hover to see effect"
  });
}

// Comparison Section (6 components)
components.push({
  type: "section",
  id: "comparison-header",
  x: 160,
  y: 8500,
  content: "Why VIBEE UI Stands Out",
  size: 56
});

components.push({
  type: "desc",
  id: "comparison-desc",
  x: 160,
  y: 8580,
  content: "The only Canvas-based UI Kit powered by BEAM with built-in Agent API",
  size: 20
});

// Comparison Cards (4)
const comparisonCards = [
  {
    id: "comp-vibee",
    x: 160,
    title: "VIBEE UI",
    badge: "You Are Here",
    description: "Canvas-based UI Kit with BEAM backend",
    highlight: true,
    features: [
      { text: "100% Canvas Rendering", status: "check" },
      { text: "BEAM/Gleam Backend", status: "check" },
      { text: "Agent API Built-in", status: "check" },
      { text: "60 FPS Performance", status: "check" },
      { text: "99 Components", status: "check" },
      { text: "Fault-Tolerant (OTP)", status: "check" },
      { text: "JSON-Based Definitions", status: "check" },
      { text: "Real-time Analytics", status: "check" }
    ]
  },
  {
    id: "comp-flutter",
    x: 600,
    title: "Flutter",
    description: "Google's UI toolkit",
    highlight: false,
    features: [
      { text: "Canvas Rendering (Skia)", status: "check" },
      { text: "Dart Backend (not BEAM)", status: "cross" },
      { text: "No Agent API", status: "cross" },
      { text: "60-120 FPS", status: "check" },
      { text: "1000+ Components", status: "check" },
      { text: "No Fault-Tolerance", status: "cross" },
      { text: "Widget-Based", status: "warning" },
      { text: "No Built-in Analytics", status: "cross" }
    ]
  },
  {
    id: "comp-react-native",
    x: 1040,
    title: "React Native",
    description: "Facebook's mobile framework",
    highlight: false,
    features: [
      { text: "Native Views (not Canvas)", status: "cross" },
      { text: "JavaScript Backend", status: "cross" },
      { text: "No Agent API", status: "cross" },
      { text: "30-60 FPS (target)", status: "warning" },
      { text: "1000+ Components", status: "check" },
      { text: "No Fault-Tolerance", status: "cross" },
      { text: "JSX-Based", status: "check" },
      { text: "No Built-in Analytics", status: "cross" }
    ]
  },
  {
    id: "comp-pixijs",
    x: 1480,
    title: "PixiJS",
    description: "2D WebGL renderer",
    highlight: false,
    features: [
      { text: "Canvas/WebGL Rendering", status: "check" },
      { text: "No Backend", status: "cross" },
      { text: "No Agent API", status: "cross" },
      { text: "60 FPS", status: "check" },
      { text: "Custom Components", status: "warning" },
      { text: "No Fault-Tolerance", status: "cross" },
      { text: "Code-Based", status: "warning" },
      { text: "No Built-in Analytics", status: "cross" }
    ]
  }
];

comparisonCards.forEach(card => {
  components.push({
    type: "comparison",
    id: card.id,
    x: card.x,
    y: 8650,
    width: 400,
    height: 600,
    title: card.title,
    badge: card.badge,
    description: card.description,
    highlight: card.highlight,
    features: card.features
  });
});

// Footer
components.push({
  type: "footer",
  id: "footer",
  x: 0,
  y: 9400,
  width: 1920,
  height: 200
});

console.log(JSON.stringify(components, null, 2));
