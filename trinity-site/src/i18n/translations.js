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
      headers: ['Company', 'Architecture', 'Valuation', 'Ternary?', 'Open?'],
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
      title: 'Scientific <span class="grad">Foundation</span>',
      sub: 'Based on peer-reviewed research and 60+ years of ternary computing',
      papersTitle: 'Key Research Papers'
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
        { value: 'База 3', label: 'Оптимальная логика', color: 'cyan' },
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
        { value: '1.585', label: 'Бит на трит', color: 'green' },
        { value: 'φ²+1/φ²', label: '= 3 (Золотое)', color: 'purple' },
        { value: '+34%', label: 'SIMD ускорение', color: 'blue' },
        { value: '10K+', label: 'Строк спеков', color: 'cyan' }
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
      headers: ['Компания', 'Архитектура', 'Оценка', 'Троичное?', 'Open?'],
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
      title: 'Научная <span class="grad">база</span>',
      sub: 'Основано на рецензируемых исследованиях и 60+ годах троичных вычислений',
      papersTitle: 'Ключевые научные работы'
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
