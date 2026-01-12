import { useState, useEffect } from 'react';
import { Send, Sparkles, Code2, FileCode, Zap, MessageSquare, AlertCircle } from 'lucide-react';
import { ChatMessage } from './components/ChatMessage';
import { CodeBlock } from './components/CodeBlock';
import { useChatStore } from './store/chatStore';
import { motion, AnimatePresence } from 'framer-motion';
import { sendAgentRequest, checkBackendHealth, type AgentMode } from './api/agent';

export default function App() {
  const [input, setInput] = useState('');
  const [mode, setMode] = useState<AgentMode>('agent');
  const [backendOnline, setBackendOnline] = useState<boolean | null>(null);
  const { messages, addMessage, isLoading, setLoading } = useChatStore();

  // Check backend health on mount
  useEffect(() => {
    checkBackendHealth().then(setBackendOnline);
  }, []);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    // Add user message
    addMessage({
      role: 'user',
      content: input,
      timestamp: new Date(),
    });

    const userInput = input;
    setInput('');
    setLoading(true);

    try {
      // Call real backend API
      const response = await sendAgentRequest({
        user_input: userInput,
        mode: mode,
        context: {
          project_name: undefined,
          project_type: undefined,
          existing_files: [],
          git_initialized: false,
        },
      });

      // Add agent response
      addMessage({
        role: 'agent',
        content: response.message,
        timestamp: new Date(),
      });
    } catch (error) {
      console.error('Error sending request:', error);
      addMessage({
        role: 'agent',
        content: `❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        timestamp: new Date(),
      });
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex flex-col h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      {/* Header */}
      <header className="bg-slate-800/50 backdrop-blur-lg border-b border-purple-500/20 px-6 py-4">
        <div className="flex items-center justify-between max-w-6xl mx-auto">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-purple-500/20 rounded-lg">
              <Sparkles className="w-6 h-6 text-purple-400" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-white">VIBEE SWE Agent</h1>
              <p className="text-sm text-purple-300">AI-Powered Code Generation</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            {/* Mode Toggle */}
            <div className="flex bg-slate-700/50 rounded-lg p-1">
              <button
                onClick={() => setMode('chat')}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-all flex items-center gap-2 ${
                  mode === 'chat'
                    ? 'bg-purple-500 text-white'
                    : 'text-purple-300 hover:text-white'
                }`}
              >
                <MessageSquare className="w-4 h-4" />
                Chat
              </button>
              <button
                onClick={() => setMode('agent')}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-all flex items-center gap-2 ${
                  mode === 'agent'
                    ? 'bg-purple-500 text-white'
                    : 'text-purple-300 hover:text-white'
                }`}
              >
                <Zap className="w-4 h-4" />
                Agent
              </button>
            </div>
            {backendOnline === null ? (
              <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-sm font-medium">
                ● Checking...
              </span>
            ) : backendOnline ? (
              <span className="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-sm font-medium">
                ● Online
              </span>
            ) : (
              <span className="px-3 py-1 bg-orange-500/20 text-orange-400 rounded-full text-sm font-medium flex items-center gap-1">
                <AlertCircle className="w-3 h-3" />
                Mock Mode
              </span>
            )}
          </div>
        </div>
      </header>

      {/* Chat Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-8">
        <div className="max-w-4xl mx-auto space-y-6">
          {messages.length === 0 ? (
            <div className="text-center py-20">
              <div className="inline-block p-4 bg-purple-500/10 rounded-2xl mb-4">
                <Code2 className="w-16 h-16 text-purple-400" />
              </div>
              <h2 className="text-2xl font-bold text-white mb-2">
                Welcome to VIBEE SWE Agent
              </h2>
              <p className="text-purple-300 mb-2">
                {mode === 'agent' 
                  ? '🚀 Agent Mode: Creates real projects and writes code to files'
                  : '💬 Chat Mode: Answers questions without changing code'
                }
              </p>
              <p className="text-purple-400/70 text-sm mb-8">
                {mode === 'agent'
                  ? 'Try: "Create a todo app with React and Express"'
                  : 'Try: "Explain how VIBEE DSL works"'
                }
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-2xl mx-auto">
                {mode === 'agent' ? (
                  <>
                    <ExamplePrompt
                      icon={<Zap className="w-5 h-5" />}
                      text="Create todo app with React"
                      onClick={() => setInput('Create a todo app with React frontend and Express backend')}
                    />
                    <ExamplePrompt
                      icon={<Code2 className="w-5 h-5" />}
                      text="Build REST API"
                      onClick={() => setInput('Create a REST API with Express and TypeScript')}
                    />
                  </>
                ) : (
                  <>
                    <ExamplePrompt
                      icon={<FileCode className="w-5 h-5" />}
                      text="Explain VIBEE DSL"
                      onClick={() => setInput('Explain how VIBEE DSL works')}
                    />
                    <ExamplePrompt
                      icon={<Code2 className="w-5 h-5" />}
                      text="Best practices"
                      onClick={() => setInput('What are VIBEE DSL best practices?')}
                    />
                  </>
                )}
              </div>
            </div>
          ) : (
            <AnimatePresence>
              {messages.map((message, index) => (
                <ChatMessage key={index} message={message} />
              ))}
            </AnimatePresence>
          )}

          {isLoading && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-center gap-3 text-purple-300"
            >
              <div className="flex gap-1">
                <span className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                <span className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                <span className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
              </div>
              <span>
                {mode === 'agent' 
                  ? 'Agent is creating project...' 
                  : 'Agent is thinking...'
                }
              </span>
            </motion.div>
          )}
        </div>
      </div>

      {/* Input Box */}
      <div className="bg-slate-800/50 backdrop-blur-lg border-t border-purple-500/20 px-6 py-4">
        <div className="max-w-4xl mx-auto">
          <div className="flex gap-3">
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder={
                mode === 'agent'
                  ? "Tell agent what project to create (e.g., 'Create a todo app with React')..."
                  : "Ask VIBEE SWE Agent a question..."
              }
              className="flex-1 bg-slate-700/50 text-white placeholder-purple-300/50 rounded-xl px-4 py-3 resize-none focus:outline-none focus:ring-2 focus:ring-purple-500 border border-purple-500/20"
              rows={3}
              disabled={isLoading}
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
              className="px-6 py-3 bg-purple-500 hover:bg-purple-600 disabled:bg-slate-600 disabled:cursor-not-allowed text-white rounded-xl font-medium transition-colors flex items-center gap-2"
            >
              <Send className="w-5 h-5" />
              Send
            </button>
          </div>
          <p className="text-xs text-purple-300/50 mt-2 text-center">
            Press Enter to send, Shift+Enter for new line
          </p>
        </div>
      </div>
    </div>
  );
}

function ExamplePrompt({ icon, text, onClick }: { icon: React.ReactNode; text: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-3 p-4 bg-slate-800/50 hover:bg-slate-700/50 border border-purple-500/20 hover:border-purple-500/40 rounded-xl transition-all text-left group"
    >
      <div className="p-2 bg-purple-500/10 group-hover:bg-purple-500/20 rounded-lg transition-colors">
        {icon}
      </div>
      <span className="text-purple-200 group-hover:text-white transition-colors">
        {text}
      </span>
    </button>
  );
}


