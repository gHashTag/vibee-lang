# 🤖 VIBEE SWE Agent Chatbot

Beautiful, modern chatbot UI for VIBEE SWE Agent with AI-powered code generation.

## ✨ Features

- 🎨 **Modern UI** - Beautiful gradient design with glassmorphism
- 💬 **Real-time Chat** - Smooth animations and streaming responses
- 🔮 **VIBEE DSL** - Syntax highlighting for VIBEE code
- 📋 **Copy & Apply** - One-click code copying and application
- ⚡ **Fast** - Built with React 18 + Vite
- 🎯 **Type-safe** - Full TypeScript support
- 🌙 **Dark Mode** - Eye-friendly dark theme

## 🚀 Quick Start

### Installation

```bash
cd chatbot
npm install
```

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### Build

```bash
npm run build
npm run preview
```

## 📦 Tech Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool
- **TailwindCSS** - Styling
- **Framer Motion** - Animations
- **Zustand** - State management
- **React Markdown** - Markdown rendering
- **Prism.js** - Syntax highlighting
- **Lucide React** - Icons

## 🎨 UI Components

### ChatMessage
Displays user and agent messages with:
- Avatar icons
- Timestamp
- Copy button
- Markdown support
- Code highlighting

### CodeBlock
Renders code with:
- VIBEE DSL syntax highlighting
- Copy button
- Apply button (for VIBEE code)
- Language indicator

### App
Main application with:
- Header with status
- Scrollable chat area
- Input box with send button
- Example prompts
- Loading indicators

## 🔮 VIBEE DSL Support

The chatbot has built-in syntax highlighting for VIBEE DSL:

```vibee
@tool factorial(n: int) -> Result(int, str)
  @doc "Calculate factorial"
  @auto_log

  CASE n OF
    n IF n < 0 -> Error("Negative input")
    0 -> Ok(1)
    _ -> Ok(n * factorial(n - 1))
  END
```

Highlights:
- `@tool`, `@doc`, `@auto_log` decorators
- `LET`, `CASE`, `OF`, `IF`, `THEN`, `ELSE`, `END` keywords
- `int`, `str`, `Result`, `Option` types
- `->`, `<-`, `++` operators

## 🎯 Usage Examples

### Generate Factorial Function
```
User: Generate factorial function in VIBEE DSL
Agent: [Generates VIBEE code with @tool, CASE OF, etc.]
```

### Create HTTP Client
```
User: Create HTTP client in VIBEE DSL
Agent: [Generates VIBEE HTTP client code]
```

### Refactor Code
```
User: Refactor this code to use pattern matching
Agent: [Refactors to VIBEE DSL with CASE OF]
```

## 🔧 Configuration

### Environment Variables

Create `.env` file:

```env
VITE_API_URL=http://localhost:8080
VITE_WS_URL=ws://localhost:8080/ws
```

### Customization

**Colors** - Edit `tailwind.config.js`:
```js
colors: {
  vibee: {
    purple: '#a855f7',
    dark: '#0f172a',
  },
}
```

**Animations** - Edit `framer-motion` variants in components

## 📱 Responsive Design

- ✅ Desktop (1920x1080+)
- ✅ Laptop (1366x768+)
- ✅ Tablet (768x1024+)
- ✅ Mobile (375x667+)

## ⌨️ Keyboard Shortcuts

- `Enter` - Send message
- `Shift + Enter` - New line
- `Ctrl/Cmd + K` - Clear chat (coming soon)
- `Ctrl/Cmd + /` - Show shortcuts (coming soon)

## 🔌 API Integration

### WebSocket (Real-time)

```typescript
const ws = new WebSocket('ws://localhost:8080/ws');

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  addMessage(message);
};

ws.send(JSON.stringify({
  type: 'generate_code',
  prompt: 'Generate factorial function',
}));
```

### REST API (Fallback)

```typescript
const response = await fetch('http://localhost:8080/api/generate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ prompt: 'Generate factorial function' }),
});

const data = await response.json();
```

## 🧪 Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Coverage
npm run test:coverage
```

## 📊 Performance

- **First Load**: < 1s
- **Time to Interactive**: < 2s
- **Bundle Size**: ~150KB (gzipped)
- **Lighthouse Score**: 95+

## 🚀 Deployment

### Vercel

```bash
npm run build
vercel deploy
```

### Netlify

```bash
npm run build
netlify deploy --prod
```

### Docker

```bash
docker build -t swe-agent-chatbot .
docker run -p 3000:3000 swe-agent-chatbot
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

## 📄 License

MIT License - see LICENSE file

## 🙏 Acknowledgments

- **VIBEE Framework** - AI agent framework
- **Claude 3.5 Sonnet** - LLM for code generation
- **React Team** - Amazing UI library
- **Tailwind Labs** - Beautiful styling system

---

**Made with 💜 by VIBEE Team**
