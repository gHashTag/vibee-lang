# Scientific Papers Review

## Core Papers Implemented

### 1. ReAct: Synergizing Reasoning and Acting in Language Models
- **arXiv**: 2210.03629
- **Authors**: Yao et al.
- **Key Insight**: Interleave reasoning traces with actions
- **Results**: +34% on ALFWorld, +10% on WebShop
- **Implementation**: `core_react_loop.vibee`

### 2. Reflexion: Language Agents with Verbal Reinforcement Learning
- **arXiv**: 2303.11366
- **Authors**: Shinn et al.
- **Key Insight**: Learn from linguistic feedback without weight updates
- **Results**: 91% pass@1 on HumanEval (vs 80% GPT-4)
- **Implementation**: `core_reflexion.vibee`

### 3. Tree of Thoughts: Deliberate Problem Solving
- **arXiv**: 2305.10601
- **Authors**: Yao et al.
- **Key Insight**: Explore multiple reasoning paths with backtracking
- **Results**: 4% → 74% on Game of 24
- **Implementation**: `core_tot_search.vibee`

### 4. Self-RAG: Learning to Retrieve, Generate, and Critique
- **arXiv**: 2310.11511
- **Authors**: Asai et al.
- **Key Insight**: Adaptive retrieval with self-reflection tokens
- **Results**: Outperforms ChatGPT on QA, reasoning, fact verification
- **Implementation**: `core_self_rag.vibee`

### 5. JARVIS-1: Open-World Multi-task Agents
- **arXiv**: 2311.05997
- **Authors**: Wang et al.
- **Key Insight**: Memory-augmented multimodal agents
- **Results**: 5x reliability on ObtainDiamondPickaxe
- **Implementation**: `memory_*.vibee`

## Papers to Implement Next

### LATS: Language Agent Tree Search
- **arXiv**: 2310.04406
- **Key Insight**: Monte Carlo Tree Search for language agents
- **Expected Impact**: +20% on complex reasoning tasks

### Voyager: An Open-Ended Embodied Agent
- **arXiv**: 2305.16291
- **Key Insight**: Lifelong learning with skill library
- **Expected Impact**: +50% task generalization

### MemGPT: Towards LLMs as Operating Systems
- **arXiv**: 2310.08560
- **Key Insight**: Virtual context management
- **Expected Impact**: +30% on long-horizon tasks

## Benchmark Papers

### GAIA: A Benchmark for General AI Assistants
- **arXiv**: 2311.12983
- **Levels**: 1 (simple), 2 (medium), 3 (hard)
- **Target**: #1 on leaderboard

### WebArena: A Realistic Web Environment
- **arXiv**: 2307.13854
- **Sites**: Shopping, Reddit, GitLab, Maps, Wikipedia
- **Target**: >50% success rate

## φ² + 1/φ² = 3
