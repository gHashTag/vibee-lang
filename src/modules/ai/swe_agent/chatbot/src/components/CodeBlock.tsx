import { useState, useEffect } from 'react';
import { Copy, Check, Play } from 'lucide-react';
import Prism from 'prismjs';
import 'prismjs/themes/prism-tomorrow.css';

// Add VIBEE DSL syntax highlighting
Prism.languages.vibee = {
  'comment': /\/\/.*/,
  'decorator': /@\w+/,
  'keyword': /\b(LET|CASE|OF|IF|THEN|ELSE|END|WHILE|DO|RETURN|IMPORT|EXPORT)\b/,
  'function': /@tool\s+\w+/,
  'type': /\b(int|str|float|bool|List|Result|Option)\b/,
  'operator': /->|<-|\+\+|==|!=|<=|>=|&&|\|\|/,
  'punctuation': /[{}[\]();,.:]/,
  'string': /(["'])(?:\\.|(?!\1)[^\\\r\n])*\1/,
  'number': /\b\d+\.?\d*\b/,
};

interface CodeBlockProps {
  code: string;
  language: string;
}

export function CodeBlock({ code, language }: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const [highlighted, setHighlighted] = useState('');

  useEffect(() => {
    const lang = language === 'vibee' ? 'vibee' : (Prism.languages[language] ? language : 'javascript');
    const html = Prism.highlight(code, Prism.languages[lang], lang);
    setHighlighted(html);
  }, [code, language]);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleApply = () => {
    // TODO: Implement apply functionality
    alert('Apply functionality coming soon!');
  };

  return (
    <div className="my-4 rounded-xl overflow-hidden border border-purple-500/20">
      {/* Header */}
      <div className="bg-slate-900/80 px-4 py-2 flex items-center justify-between border-b border-purple-500/20">
        <span className="text-sm text-purple-300 font-mono">
          {language === 'vibee' ? '🔮 VIBEE DSL' : language}
        </span>
        <div className="flex gap-2">
          <button
            onClick={handleCopy}
            className="px-3 py-1 bg-slate-700/50 hover:bg-slate-600/50 text-purple-300 rounded-lg text-sm flex items-center gap-2 transition-colors"
          >
            {copied ? (
              <>
                <Check className="w-4 h-4" />
                Copied
              </>
            ) : (
              <>
                <Copy className="w-4 h-4" />
                Copy
              </>
            )}
          </button>
          {language === 'vibee' && (
            <button
              onClick={handleApply}
              className="px-3 py-1 bg-purple-500/20 hover:bg-purple-500/30 text-purple-300 rounded-lg text-sm flex items-center gap-2 transition-colors"
            >
              <Play className="w-4 h-4" />
              Apply
            </button>
          )}
        </div>
      </div>

      {/* Code */}
      <div className="bg-slate-950/50 p-4 overflow-x-auto">
        <pre className="text-sm">
          <code
            className={`language-${language}`}
            dangerouslySetInnerHTML={{ __html: highlighted }}
          />
        </pre>
      </div>
    </div>
  );
}
