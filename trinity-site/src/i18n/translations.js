// TRINITY Presentation Translations
// Note: TRINITY is always TRINITY in all languages

export const translations = {
  en: {
    lang: 'en',
    langSwitch: 'RU',
    langHref: '?lang=ru',
    
    nav: ['TRINITY', 'Problem', 'Solution', 'Why Now', 'Calculator', 'Traction', 'Market', 'GTM', 'Competition', 'Roadmap', 'Team', 'Ecosystem', 'Invest'],
    
    hero: {
      tag: 'Native Ternary Hardware for AI',
      headline: '5× Faster AI Inference at 40% Less Power',
      quote: '"We build chips that speak AI\'s native language"',
      desc: 'First chip for ternary neural networks: <strong>5× faster</strong> at <strong>40% less power</strong>',
      cta: 'Get Pitch Deck'
    },
    
    problem: {
      title: 'The <span class="grad">$100B</span> Problem',
      sub: 'Ternary AI models run on binary hardware — massive waste',
      bitnetTitle: 'Microsoft BitNet b1.58 (Feb 2024)',
      bitnetDesc: 'Microsoft proved: <strong>ternary weights {-1, 0, +1}</strong> match FP16 accuracy. But GPUs store each trit as 8 bits — <strong class="red">5x memory waste</strong>. GPUs compute 256×256 when only 3×3 needed — <strong class="red">7000x compute waste</strong>.',
      binaryTitle: 'Binary GPU (Current)',
      binaryFlow: ['BitNet {-1,0,+1}', '↓ Convert to INT8', '↓ GPU 8×8 multiply', '↓ Accumulate 32-bit', '↓ Quantize back', 'Result'],
      binaryStats: ['Memory: 8 bits/trit (5x waste)', 'Compute: 256×256 vs 3×3 (7000x)', 'Conversion: Every layer'],
      trinityTitle: 'TRINITY (Native)',
      trinityFlow: ['BitNet {-1,0,+1}', '↓ Native trit storage', '↓ Ternary ALU lookup', 'Result'],
      trinityStats: ['Memory: 1.585 bits/trit (native)', 'Compute: 3×3 lookup (native)', 'Conversion: None'],
      quote: '"Opens the door for <strong>designing specific hardware</strong> for 1-bit LLMs."',
      quoteSrc: '— Microsoft BitNet b1.58, arXiv:2402.17764'
    },
    
    solution: {
      title: 'Why <span class="grad">Ternary</span>?',
      legend: ['+58.5% information density', 'Base 3 is optimal (Knuth)', 'φ² + 1/φ² = 3 (golden ratio)'],
      cards: [
        { value: '1.585×', label: 'Information Density', color: 'blue' },
        { value: '5×', label: 'Faster Inference', color: 'green' },
        { value: '40%', label: 'Less Power', color: 'purple' },
        { value: '60%', label: 'Cost Reduction', color: 'yellow' },
        { value: 'Base 3', label: 'Optimal Logic', color: 'cyan' },
        { value: 'φ²', label: 'Golden Math', color: 'green' }
      ]
    },

    whynow: {
      title: 'Why <span class="grad">Now</span>?',
      cards: [
        { title: 'The "1.58" Era', desc: 'Microsoft BitNet proved 1.58-bit models outperform binary.' },
        { title: 'Energy Crisis', desc: 'AI data centers consume 4% of world electricity. We fix it.' },
        { title: 'Edge AI Boom', desc: 'LLMs moving to phones/IoT need hardware that doesn\'t burn batteries.' }
      ]
    },

    usecases: {
      title: 'Specific <span class="grad">Applications</span>',
      items: [
        { title: 'LLM Inference', desc: 'Run Llama 3 on 1/5 of current hardware costs.' },
        { title: 'Edge AI', desc: 'Real-time AI in cameras and robots with zero latency.' },
        { title: 'Data Centers', desc: 'Double your compute without upgrading power grid.' }
      ]
    },
    
    traction: {
      title: 'Working <span class="grad">Technology</span>',
      sub: 'Not vaporware — real code, real tests, real results',
      techTitle: 'Core Ternary Technologies (All Tests Passing)',
      techs: [
        { title: 'Trit Logic', desc: 'Kleene: AND, OR, NOT, XOR', tests: '10/10 tests ✓' },
        { title: 'Vec27 SIMD', desc: '27 trits parallel, 3²⁷ states', tests: '5/5 tests ✓' },
        { title: 'Golden Constants', desc: 'φ² + 1/φ² = 3, golden ratio math', tests: '20/20 tests ✓' },
        { title: 'Bytecode VM', desc: '80 opcodes, 5.6x faster', tests: '24/24 tests ✓' }
      ],
      progress: [
        { label: 'Tests', value: '88/88 (100%)' },
        { label: 'Zig Modules', value: '120+' },
        { label: 'SIMD Optimization', value: '103ns → 68ns (+34%)' }
      ],
      metrics: [
        { value: '88', label: 'Tests', color: 'green' },
        { value: '5.6×', label: 'VM Speedup', color: 'blue' },
        { value: '80', label: 'Opcodes', color: 'purple' },
        { value: '3²⁷', label: 'Vec27 States', color: 'cyan' },
        { value: '120+', label: 'Zig Modules', color: 'yellow' },
        { value: '1.585', label: 'Bits/Trit', color: 'green' },
        { value: 'φ²+1/φ²', label: '= 3 (Golden)', color: 'purple' },
        { value: '+34%', label: 'SIMD Boost', color: 'blue' },
        { value: '10K+', label: 'Spec Lines', color: 'cyan' }
      ]
    },
    
    market: {
      title: 'Market <span class="grad">$200B</span>',
      funnel: [
        { value: '$200B', label: 'TAM — AI Accelerators' },
        { value: '$80B', label: 'SAM — AI Inference' },
        { value: '$8B', label: 'SOM — Ternary (10%)' }
      ],
      compsTitle: 'Comparable Valuations',
      headers: ['Company', 'Valuation', 'Revenue', 'Multiple'],
      rows: [
        ['Cerebras', '$4.0B', '$100M', '40×'],
        ['Groq', '$2.8B', '$50M', '56×'],
        ['SambaNova', '$5.0B', '$150M', '33×'],
        ['TRINITY', '$200M', 'Pre-rev', 'Seed']
      ]
    },

    gtm: {
      title: '<span class="grad">Go-to-Market</span>',
      phases: [
        { phase: 'Phase 1', title: 'Research Labs', desc: 'Universities, AI labs • Free pilots • Case studies' },
        { phase: 'Phase 2', title: 'AI Startups', desc: 'Inference savings • FPGA cards • $10K-50K deals' },
        { phase: 'Phase 3', title: 'Enterprise', desc: 'Cloud providers • ASIC licensing • $1M+ deals' }
      ]
    },

    roadmap: {
      title: '<span class="grad">Roadmap</span>',
      milestones: [
        { date: 'Q1 2026', title: 'FPGA Prototype', desc: 'BitNet inference on real hardware' },
        { date: 'Q3 2026', title: 'Developer SDK', desc: 'Zig-based compilers for AI researchers' },
        { date: 'Q1 2027', title: 'ASIC Tape-out', desc: 'First native ternary chip production' }
      ]
    },

    product: {
      title: '<span class="grad">Product</span> Roadmap',
      phases: [
        { phase: 'TRINITY-FPGA', year: '2025-2026', desc: 'FPGA-based ternary accelerator • PCIe card for data centers • Target: AI inference workloads' },
        { phase: 'TRINITY-1 ASIC', year: '2027', desc: 'First native ternary chip • 180nm process (low risk) • Target: Edge AI devices' },
        { phase: 'TRINITY-X', year: '2029', desc: 'Advanced node (28nm) • Full SoC with ternary CPU • Target: Data center scale' }
      ]
    },

    financials: {
      title: 'Path to <span class="grad">$10B+</span>',
      headers: ['Year', 'Revenue', 'Gross Margin', 'Valuation', 'Headcount'],
      rows: [
        ['2026', '$2M', '50%', '$200M', '15'],
        ['2027', '$15M', '55%', '$500M', '50'],
        ['2028', '$80M', '60%', '$2B', '150'],
        ['2029', '$300M', '65%', '$5B', '400'],
        ['2030', '$1B', '70%', '$10B+', '1,000']
      ],
      note: 'Revenue multiple comparable to Cerebras (40×), Groq (56×), SambaNova (33×)'
    },

    businessModel: {
      title: 'Business <span class="grad">Model</span>',
      streams: [
        { percent: '60%', title: 'Hardware Sales', desc: 'TRINITY-FPGA: $15K ASP, 55% margin • TRINITY-ASIC: $3K ASP, 65% margin' },
        { percent: '30%', title: 'IP Licensing', desc: 'License ternary IP to chip makers • $2-5 royalty per chip • 90%+ margin' },
        { percent: '10%', title: 'Software & Services', desc: 'TRINITY SDK: $100K/year enterprise • Integration services • 80% margin' }
      ],
      unitEcon: 'LTV/CAC: 15× | Target Year 1: 1,000 units = $7.5M revenue'
    },

    team: {
      title: 'The <span class="grad">Team</span>',
      name: 'Dmitrii Vasilev',
      role: 'Founder & CEO',
      photo: 'https://media.licdn.com/dms/image/v2/D4E03AQFiQ-Ov6dkEbg/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724820280182?e=1770854400&v=beta&t=Xq5vNL_NCNqIX8G22qy9PWeZygdXiquqU9zrb0EbL6s',
      linkedin: 'https://www.linkedin.com/in/neurocoder/',
      exp: [
        '15+ years software engineering',
        'Ex-senior engineer at tech companies',
        'Deep expertise in compilers & low-level systems',
        'Created VIBEE language from scratch',
        '88 tests passing, 120+ Zig modules'
      ],
      hiring: 'Hiring: FPGA Engineer, AI Researcher, Business Development'
    },
    
    ecosystem: {
      title: 'The <span class="grad">Ecosystem</span>',
      sub: 'Ternary is not science fiction. It is a working ecosystem of technologies already built and performing.',
      quote: 'This is not just an article about math. It is a story of how I, a vibe-coder, discovered the φ² + 1/φ² = 3 link and built an entire ecosystem on it.',
      formula: 'Sacred Formula: V = n × 3^k × π^m × φ^p × e^q',
      items: [
        { title: 'VIBEE Compiler', desc: 'Spec-first (Zig) • given/when/then logic' },
        { title: 'LLM Inference', desc: 'llama.cpp integration • 10x-50x boost' },
        { title: 'GEN-MULTI', desc: '42-language Gen • 350+ components' },
        { title: '999 OS', desc: 'Ternary OS core • 999 = 37 × 3³' },
        { title: 'Trinity B-Tree', desc: 'Optimal radix (b=3) • Economic storage' },
        { title: 'Trinity Sort', desc: '3-way QuickSort • Up to 3x faster' }
      ]
    },
    
    competition: {
      title: '<span class="grad">Competition</span> Matrix',
      headers: ['Company', 'Architecture', 'Valuation', 'Ternary', 'Open'],
      rows: [
        { company: 'NVIDIA', arch: 'Binary GPU', val: '$3T', ternary: false, open: false },
        { company: 'Cerebras', arch: 'Binary Wafer', val: '$4B', ternary: false, open: false },
        { company: 'Groq', arch: 'Binary LPU', val: '$2.8B', ternary: false, open: false },
        { company: 'SambaNova', arch: 'Binary Dataflow', val: '$5B', ternary: false, open: false },
        { company: 'TRINITY', arch: 'Native Ternary', val: '$200M', ternary: true, open: true }
      ],
      note: 'All competitors are binary. TRINITY is the <strong>first native ternary</strong> architecture.'
    },
    
    science: {
      title: 'Scientific <span class="grad">Proof</span>',
      sub: '40 proofs from 8 sciences. One script — all evidence.',
      stats: [
        { value: '40', label: 'Proofs' },
        { value: '8', label: 'Sciences' },
        { value: '97.5%', label: 'Pass Rate' }
      ],
      sections: [
        { name: 'Mathematics', passed: 10, total: 10 },
        { name: 'Particle Physics', passed: 8, total: 8 },
        { name: 'Quantum Physics', passed: 5, total: 5 },
        { name: 'Cosmology', passed: 3, total: 4 },
        { name: 'Chaos Theory', passed: 3, total: 3 },
        { name: 'Computer Science', passed: 4, total: 4 },
        { name: 'Biology', passed: 3, total: 3 },
        { name: 'Neuromorphic', passed: 3, total: 3 }
      ],
      formulas: [
        { formula: 'φ² + 1/φ² = 3', desc: 'Golden Identity', error: '0.0000%', source: 'Algebra' },
        { formula: '1/α = 4π³ + π² + π', desc: 'Fine Structure', error: '0.0002%', source: 'CODATA 2018' },
        { formula: 'm_p/m_e = 6π⁵', desc: 'Proton/Electron', error: '0.002%', source: 'CODATA 2018' },
        { formula: 'Koide Q = 2/3', desc: 'Lepton Masses', error: '0.0009%', source: 'Koide 1981' },
        { formula: 'π × φ × e = 13.82', desc: 'Age of Universe', error: '0.14%', source: 'Planck 2020' },
        { formula: 'm₂/m₁ = φ', desc: 'E8 Spectrum', error: '0.01%', source: 'Science 2010' }
      ],
      sources: [
        { title: 'Coldea et al. Science 327, 177 (2010)', desc: 'E8 spectrum golden ratio' },
        { title: 'Microsoft BitNet b1.58 (2024)', desc: 'Ternary weights proven' },
        { title: 'Koide Y. Phys. Lett. B (1983)', desc: '44 years unexplained' }
      ],
    
    techAssets: {
      title: 'Technical <span class="grad">Assets</span>',
      sub: 'Not just an idea. A massive, working codebase.',
      items: [
        { value: '10,244', label: 'Specifications (.vibee)', desc: 'Formalized knowledge base' },
        { value: '42', label: 'Languages', desc: 'Generated from one source' },
        { value: '100+', label: 'Sacred Constants', desc: 'Implemented in sacred_constants.zig' },
        { value: '88/88', label: 'Tests Passing', desc: 'Core VM & Trinity modules' },
        { value: '115 KB', label: 'VM Runtime', desc: 'Lightweight stack-based VM' },
        { value: '5.6x', label: 'Faster', desc: 'Fibonacci benchmark vs Binary' }
      ]
    },

    calculatorLogic: {
      title: 'Calculator <span class="grad">Logic</span>',
      sub: 'Why build a supercomputer when a calculator is enough?',
      comparison: [
        { 
          title: 'Complex Binary Compute', 
          desc: 'Requires billions of transistors, massive energy, and cooling to approximate answers.',
          icon: '📉' 
        },
        { 
          title: 'Ternary Calculator', 
          desc: 'Solves the same tasks using native math (φ² + 1/φ² = 3) with a fraction of the energy.',
          icon: '✨' 
        }
      ],
      quote: '"We are trying to simulate intelligence with brute force, when the universe uses elegant math."'
    },


    technology: {
      title: '<span class="grad">Technology</span> Architecture',
      sub: 'How TRINITY Works',
      layers: [
        { title: 'TERNARY ALU', desc: '3-state logic' },
        { title: 'TERNARY MEMORY', desc: '3-level storage' },
        { title: 'TERNARY I/O', desc: 'Interface layer' }
      ],
      softwareStack: 'TRINITY SOFTWARE STACK',
      innovations: [
        'Multi-threshold CMOS for native 3-state logic',
        'Golden ratio optimization (φ² + 1/φ² = 3)',
        'Zero-overhead ternary neural network execution'
      ]
    },

    milestones: {
      title: '18-Month <span class="grad">Milestones</span>',
      sub: 'What $2M Buys',
      quarters: [
        { q: 'Q1 2026', title: 'Foundation', items: ['Complete TALU RTL design', 'FPGA prototype working', 'Benchmark vs emulation'] },
        { q: 'Q2 2026', title: 'Validation', items: ['Run ternary NN on FPGA', 'Demonstrate 3× speedup', 'First beta customers'] },
        { q: 'Q3 2026', title: 'Product', items: ['TRINITY-FPGA PCIe card', 'SDK and documentation', '5 paying customers'] },
        { q: 'Q4 2026', title: 'Scale', items: ['$500K ARR', 'ASIC design complete', 'Series A fundraise'] }
      ],
      success: ['3×+ speedup demonstrated', '10+ customers', '$1M+ pipeline']
    },

    vision: {
      title: '<span class="grad">Vision</span> 2032',
      quote: '"Binary was the 20th century. Ternary is the 21st."',
      goals: [
        'TRINITY chips in every AI data center',
        'Standard for ternary neural network inference',
        '$1B+ revenue, profitable',
        'IPO or strategic acquisition'
      ],
      whyNow: [
        'Ternary AI is proven (Microsoft, Meta, Google)',
        'No native hardware exists (first mover)',
        '$50B market growing 25%+ annually',
        'Strong technical foundation (working VM)',
        'Clear path to product and revenue'
      ],
      closing: 'The mathematics of the universe favors three states.'
    },

    invest: {
      title: '<span class="grad">Investment</span>',
      useTitle: 'Use of Funds',
      uses: [
        '60% — Engineering (FPGA, ASIC)',
        '20% — Hardware (boards, tests)',
        '20% — Operations (IP, legal)'
      ],
      cards: [
        { value: '$2M', label: 'for 1% equity' },
        { value: '50×', label: 'potential return' }
      ],
      milestonesTitle: '18-Month Milestones:',
      milestones: [
        'Working FPGA product',
        '5+ paying customers',
        '$1M annual revenue',
        'Series A ready'
      ],
      whyTitle: 'Why Invest Now:',
      why: [
        'First native ternary architecture',
        'Microsoft validated (BitNet)',
        'Working prototype',
        '18-month head start',
        '99% founder ownership = aligned'
      ],
      closing: '"Binary was the 20th century. Ternary is the 21st. TRINITY makes it happen."',
      ctas: {
        investor: 'Schedule Pitch Deck Review',
        partner: 'Discuss Integration',
        talent: 'Join the Team'
      },
      contact: {
        email: 'raoffonom@icloud.com',
        website: 'https://trinity-site-one.vercel.app',
        github: 'https://github.com/gHashTag/vibee-lang'
      }
    }
  },
  
  ru: {
    lang: 'ru',
    langSwitch: 'EN',
    langHref: '?lang=en',
    
    nav: ['TRINITY', 'Проблема', 'Решение', 'Почему сейчас', 'Калькулятор', 'Технология', 'Рынок', 'GTM', 'Матрица', 'Roadmap', 'Команда', 'Экосистема', 'Инвестиции'],
    
    hero: {
      tag: 'Нативное троичное железо для AI',
      headline: 'Инференс AI в 5 раз быстрее при экономии энергии на 40%',
      quote: '"Мы создаём чипы, которые говорят на родном языке AI"',
      desc: 'Первый чип для троичных нейросетей: <strong>в 5 раз быстрее</strong> при <strong>экономии энергии на 40%</strong>',
      cta: 'Получить Pitch Deck'
    },
    
    problem: {
      title: 'Проблема на <span class="grad">$100B</span>',
      sub: 'Троичные AI модели работают на бинарном железе — огромные потери',
      bitnetTitle: 'Microsoft BitNet b1.58 (Февраль 2024)',
      bitnetDesc: 'Microsoft доказал: <strong>троичные веса {-1, 0, +1}</strong> дают точность как FP16. Но GPU хранит каждый трит как 8 бит — <strong class="red">5x потери памяти</strong>. GPU считает 256×256 когда нужно 3×3 — <strong class="red">7000x лишних вычислений</strong>.',
      binaryTitle: 'Бинарный GPU (сейчас)',
      binaryFlow: ['BitNet {-1,0,+1}', '↓ Конвертация в INT8', '↓ GPU 8×8 умножение', '↓ Накопление 32-бит', '↓ Квантизация', 'Результат'],
      binaryStats: ['Память: 8 бит/трит (5x потери)', 'Вычисления: 256×256 vs 3×3 (7000x)', 'Конвертация: Каждый слой'],
      trinityTitle: 'TRINITY (Нативное)',
      trinityFlow: ['BitNet {-1,0,+1}', '↓ Нативное хранение', '↓ Троичный ALU lookup', 'Результат'],
      trinityStats: ['Память: 1.585 бит/трит (нативно)', 'Вычисления: 3×3 lookup (нативно)', 'Конвертация: Не нужна'],
      quote: '"Открывает дверь для <strong>создания специализированного железа</strong> для 1-bit LLM."',
      quoteSrc: '— Microsoft BitNet b1.58, arXiv:2402.17764'
    },
    
    solution: {
      title: 'Почему <span class="grad">Троичное</span>?',
      legend: ['+58.5% плотность информации', 'База 3 оптимальна (Кнут)', 'φ² + 1/φ² = 3 (золотое сечение)'],
      cards: [
        { value: '1.585×', label: 'Плотность данных', color: 'blue' },
        { value: '5×', label: 'Быстрее инференс', color: 'green' },
        { value: '40%', label: 'Экономия энергии', color: 'purple' },
        { value: '60%', label: 'Снижение затрат', color: 'yellow' },
        { value: 'База 3', label: 'Оптимум', color: 'cyan' },
        { value: 'φ²', label: 'Золотое сечение', color: 'green' }
      ]
    },

    whynow: {
      title: 'Почему <span class="grad">сейчас</span>?',
      cards: [
        { title: 'Эра "1.58"', desc: 'Microsoft BitNet доказал: 1.58-битные модели обходят бинарные.' },
        { title: 'Кризис энергии', desc: 'AI дата-центры потребляют 4% мирового электричества. Мы это исправим.' },
        { title: 'Бум Edge AI', desc: 'LLM в телефонах и IoT требуют железа, которое не сжигает батарею.' }
      ]
    },

    usecases: {
      title: 'Сферы <span class="grad">применения</span>',
      items: [
        { title: 'Инференс LLM', desc: 'Запуск Llama 3 в 5 раз дешевле текущих затрат.' },
        { title: 'Edge AI', desc: 'AI в реальном времени в камерах и роботах без задержек.' },
        { title: 'Дата-центры', desc: 'Удвойте свои мощности без модернизации электросети.' }
      ]
    },
    
    traction: {
      title: 'Работающая <span class="grad">технология</span>',
      sub: 'Не vaporware — реальный код, реальные тесты, реальные результаты',
      techTitle: 'Ключевые троичные технологии (Все тесты проходят)',
      techs: [
        { title: 'Троичная логика', desc: 'Клини: AND, OR, NOT, XOR', tests: '10/10 тестов ✓' },
        { title: 'Vec27 SIMD', desc: '27 тритов параллельно, 3²⁷ состояний', tests: '5/5 тестов ✓' },
        { title: 'Золотые константы', desc: 'φ² + 1/φ² = 3, математика золотого сечения', tests: '20/20 тестов ✓' },
        { title: 'Байткод VM', desc: '80 опкодов, в 5.6x быстрее', tests: '24/24 тестов ✓' }
      ],
      progress: [
        { label: 'Тесты', value: '88/88 (100%)' },
        { label: 'Zig модули', value: '120+' },
        { label: 'SIMD оптимизация', value: '103ns → 68ns (+34%)' }
      ],
      metrics: [
        { value: '88', label: 'Тестов', color: 'green' },
        { value: '5.6×', label: 'Ускорение VM', color: 'blue' },
        { value: '80', label: 'Опкодов', color: 'purple' },
        { value: '3²⁷', label: 'Vec27 состояний', color: 'cyan' },
        { value: '120+', label: 'Zig модулей', color: 'yellow' },
        { value: '1.585', label: 'Бит на трит', color: 'green' }
      ]
    },
    
    market: {
      title: 'Рынок <span class="grad">$200B</span>',
      funnel: [
        { value: '$200B', label: 'TAM — AI ускорители' },
        { value: '$80B', label: 'SAM — AI инференс' },
        { value: '$8B', label: 'SOM — Троичные (10%)' }
      ],
      compsTitle: 'Сравнимые оценки',
      headers: ['Компания', 'Оценка', 'Выручка', 'Мультипликатор'],
      rows: [
        ['Cerebras', '$4.0B', '$100M', '40×'],
        ['Groq', '$2.8B', '$50M', '56×'],
        ['SambaNova', '$5.0B', '$150M', '33×'],
        ['TRINITY', '$200M', 'До выручки', 'Посев']
      ]
    },

    roadmap: {
      title: '<span class="grad">Roadmap</span>',
      milestones: [
        { date: 'Q1 2026', title: 'FPGA Прототип', desc: 'Инференс BitNet на реальном железе' },
        { date: 'Q3 2026', title: 'SDK для разработчиков', desc: 'Zig-компиляторы для AI исследователей' },
        { date: 'Q1 2027', title: 'ASIC Tape-out', desc: 'Первое производство нативных троичных чипов' }
      ]
    },

    product: {
      title: '<span class="grad">Продукт</span>',
      phases: [
        { phase: 'TRINITY-FPGA', year: '2025-2026', desc: 'FPGA ускоритель • PCIe карта для дата-центров • Цель: AI инференс' },
        { phase: 'TRINITY-1 ASIC', year: '2027', desc: 'Первый нативный троичный чип • 180нм (низкий риск) • Цель: Edge AI' },
        { phase: 'TRINITY-X', year: '2029', desc: 'Продвинутый узел (28нм) • Полный SoC с троичным CPU • Цель: Дата-центры' }
      ]
    },

    financials: {
      title: 'Путь к <span class="grad">$10B+</span>',
      headers: ['Год', 'Выручка', 'Маржа', 'Оценка', 'Штат'],
      rows: [
        ['2026', '$2M', '50%', '$200M', '15'],
        ['2027', '$15M', '55%', '$500M', '50'],
        ['2028', '$80M', '60%', '$2B', '150'],
        ['2029', '$300M', '65%', '$5B', '400'],
        ['2030', '$1B', '70%', '$10B+', '1,000']
      ],
      note: 'Мультипликатор сравним с Cerebras (40×), Groq (56×), SambaNova (33×)'
    },

    businessModel: {
      title: 'Бизнес <span class="grad">модель</span>',
      streams: [
        { percent: '60%', title: 'Продажи железа', desc: 'TRINITY-FPGA: $15K ASP, 55% маржа • TRINITY-ASIC: $3K ASP, 65% маржа' },
        { percent: '30%', title: 'IP лицензирование', desc: 'Лицензия троичного IP чипмейкерам • $2-5 роялти за чип • 90%+ маржа' },
        { percent: '10%', title: 'ПО и сервисы', desc: 'TRINITY SDK: $100K/год энтерпрайз • Интеграция • 80% маржа' }
      ],
      unitEcon: 'LTV/CAC: 15× | Цель Год 1: 1,000 юнитов = $7.5M выручки'
    },

    gtm: {
      title: 'Выход на <span class="grad">рынок</span>',
      phases: [
        { phase: 'Фаза 1', title: 'Исследовательские лаборатории', desc: 'Университеты, AI лаборатории • Бесплатные пилоты • Кейсы' },
        { phase: 'Фаза 2', title: 'AI стартапы', desc: 'Экономия на инференсе • FPGA карты • $10K-50K сделки' },
        { phase: 'Фаза 3', title: 'Корпорации', desc: 'Облачные провайдеры • ASIC лицензирование • $1M+ сделки' }
      ]
    },
    
    team: {
      title: '<span class="grad">Команда</span>',
      name: 'Дмитрий Васильев',
      role: 'Основатель & CEO',
      photo: 'https://media.licdn.com/dms/image/v2/D4E03AQFiQ-Ov6dkEbg/profile-displayphoto-shrink_800_800/profile-displayphoto-shrink_800_800/0/1724820280182?e=1770854400&v=beta&t=Xq5vNL_NCNqIX8G22qy9PWeZygdXiquqU9zrb0EbL6s',
      linkedin: 'https://www.linkedin.com/in/neurocoder/',
      exp: [
        '15+ лет разработки ПО',
        'Опыт в крупных tech компаниях',
        'Экспертиза в компиляторах и низкоуровневых системах',
        'Создал язык VIBEE с нуля',
        '88 тестов, 120+ Zig модулей'
      ],
      hiring: 'Нанимаем: FPGA инженер, AI исследователь, развитие бизнеса'
    },
    
    ecosystem: {
      title: 'Троичная <span class="grad">Экосистема</span>',
      sub: 'Троичная логика — это не сказки, а работающая экосистема технологий, которые уже созданы и приносят результат.',
      quote: 'Это не просто статья о математике. Это история о том, как я, программист-вайбкодер, открыл связь φ² + 1/φ² = 3 и создал на её основе целую экосистему технологий.',
      formula: 'Священная Формула: V = n × 3^k × π^m × φ^p × e^q',
      items: [
        { title: 'VIBEE Compiler', desc: 'Spec-first (Zig) • given/when/then = 3 элемента' },
        { title: 'LLM Inference', desc: 'llama.cpp интеграция • ускорение 10x-50x' },
        { title: 'GEN-MULTI', desc: 'Генерация для 42 языков • 350+ компонентов' },
        { title: '999 OS', desc: 'Троичная ОС • 999 = 37 × 3³' },
        { title: 'Trinity B-Tree', desc: 'Оптимальное B-дерево • b = 3' },
        { title: 'Trinity Sort', desc: '3-way QuickSort • До 3× быстрее' }
      ]
    },
    
    competition: {
      title: 'Матрица <span class="grad">конкурентов</span>',
      headers: ['Компания', 'Архитектура', 'Оценка', 'Троичное', 'Open'],
      rows: [
        { company: 'NVIDIA', arch: 'Бинарный GPU', val: '$3T', ternary: false, open: false },
        { company: 'Cerebras', arch: 'Бинарный Wafer', val: '$4B', ternary: false, open: false },
        { company: 'Groq', arch: 'Бинарный LPU', val: '$2.8B', ternary: false, open: false },
        { company: 'SambaNova', arch: 'Бинарный Dataflow', val: '$5B', ternary: false, open: false },
        { company: 'TRINITY', arch: 'Нативный троичный', val: '$200M', ternary: true, open: true }
      ],
      note: 'Все конкуренты бинарные. TRINITY — <strong>первая нативная троичная</strong> архитектура.'
    },
    
    science: {
      title: 'Научное <span class="grad">Доказательство</span>',
      sub: '40 доказательств из 8 наук. Один скрипт — все факты.',
      stats: [
        { value: '40', label: 'Доказательств' },
        { value: '8', label: 'Наук' },
        { value: '97.5%', label: 'Успех' }
      ],
      sections: [
        { name: 'Математика', passed: 10, total: 10 },
        { name: 'Физика частиц', passed: 8, total: 8 },
        { name: 'Кватовая физика', passed: 5, total: 5 },
        { name: 'Космология', passed: 3, total: 4 },
        { name: 'Теория хаоса', passed: 3, total: 3 },
        { name: 'Информатика', passed: 4, total: 4 },
        { name: 'Биология', passed: 3, total: 3 },
        { name: 'Нейроморфные', passed: 3, total: 3 }
      ],
      formulas: [
        { formula: 'φ² + 1/φ² = 3', desc: 'Золотое тождество', error: '0.0000%', source: 'Алгебра' },
        { formula: '1/α = 4π³ + π² + π', desc: 'Тонкая структура', error: '0.0002%', source: 'CODATA 2018' },
        { formula: 'm_p/m_e = 6π⁵', desc: 'Протон/Электрон', error: '0.002%', source: 'CODATA 2018' },
        { formula: 'Koide Q = 2/3', desc: 'Массы лептонов', error: '0.0009%', source: 'Koide 1981' },
        { formula: 'π × φ × e = 13.82', desc: 'Возраст Вселенной', error: '0.14%', source: 'Planck 2020' },
        { formula: 'm₂/m₁ = φ', desc: 'Спектр E8', error: '0.01%', source: 'Science 2010' }
      ],
      sources: [
        { title: 'Coldea et al. Science 327, 177 (2010)', desc: 'Золотое сечение в E8' },
        { title: 'Microsoft BitNet b1.58 (2024)', desc: 'Троичные веса доказаны' },
        { title: 'Koide Y. Phys. Lett. B (1983)', desc: '44 года без объяснения' }
      ]
    },

    technology: {
      title: '<span class="grad">Технология</span>',
      sub: 'Как работает TRINITY',
      layers: [
        { title: 'TERNARY ALU', desc: '3-состояния' },
        { title: 'TERNARY MEMORY', desc: '3-уровня' },
        { title: 'TERNARY I/O', desc: 'Интерфейс' }
      ],
      softwareStack: 'TRINITY SOFTWARE STACK',
      innovations: [
        'Multi-threshold CMOS для нативной 3-state логики',
        'Оптимизация золотым сечением (φ² + 1/φ² = 3)',
        'Нулевые накладные расходы для троичных нейросетей'
      ]
    },

    milestones: {
      title: '18 месяцев <span class="grad">майлстоуны</span>',
      sub: 'Что покупают $2M',
      quarters: [
        { q: 'Q1 2026', title: 'Фундамент', items: ['RTL дизайн TALU', 'FPGA прототип', 'Бенчмарки'] },
        { q: 'Q2 2026', title: 'Валидация', items: ['Троичные NN на FPGA', 'Демо 3× ускорения', 'Первые бета-клиенты'] },
        { q: 'Q3 2026', title: 'Продукт', items: ['TRINITY-FPGA PCIe', 'SDK и документация', '5 платящих клиентов'] },
        { q: 'Q4 2026', title: 'Масштаб', items: ['$500K ARR', 'ASIC дизайн', 'Раунд A'] }
      ],
      success: ['3×+ ускорение', '10+ клиентов', '$1M+ пайплайн']
    },

    vision: {
      title: '<span class="grad">Видение</span> 2032',
      quote: '"Бинарное — это 20 век. Троичное — 21 век."',
      goals: [
        'TRINITY чипы в каждом AI дата-центре',
        'Стандарт для троичного инференса',
        '$1B+ выручки, прибыльность',
        'IPO или стратегическое поглощение'
      ],
      whyNow: [
        'Троичный AI доказан (Microsoft, Meta, Google)',
        'Нет нативного железа (первые на рынке)',
        'Рынок $50B растет 25%+ в год',
        'Рабочий технический фундамент (VM)',
        'Чёткий путь к продукту и выручке'
      ],
      closing: 'Математика вселенной благоприятствует трём состояниям.'
    },

    invest: {
      title: '<span class="grad">Инвестиции</span>',
      useTitle: 'Распределение средств',
      uses: [
        '60% — Инженерия (FPGA, ASIC)',
        '20% — Железо (платы, тесты)',
        '20% — Операции (IP, юристы)'
      ],
      cards: [
        { value: '$2M', label: 'за 1% equity' },
        { value: '50×', label: 'потенциальный возврат' }
      ],
      milestonesTitle: 'Майлстоуны 18 месяцев:',
      milestones: [
        'Работающий FPGA продукт',
        '5+ платящих клиентов',
        '$1M годовой выручки',
        'Готовность к раунду A'
      ],
      whyTitle: 'Почему инвестировать сейчас:',
      why: [
        'Первая нативная троичная архитектура',
        'Microsoft подтвердил (BitNet)',
        'Работающий прототип',
        '18 месяцев форы',
        '99% у основателя = alignment'
      ],
      closing: '"Бинарное — это 20 век. Троичное — 21 век. TRINITY делает это реальностью."',
      ctas: {
        investor: 'Обсудить Pitch Deck',
        partner: 'Предложить интеграцию',
        talent: 'Присоединиться к команде'
      },
      contact: {
        email: 'raoffonom@icloud.com',
        website: 'https://trinity-site-one.vercel.app',
        github: 'https://github.com/gHashTag/vibee-lang'
      }
    }
  }
}
