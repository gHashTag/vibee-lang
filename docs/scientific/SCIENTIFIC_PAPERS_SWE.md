# Scientific Papers: SWE Agents & Autonomous Coding

**φ² + 1/φ² = 3 | PHOENIX = 999**

---

## Core Papers

### 1. SWE-Agent (Princeton, 2024)
**"SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering"**
- Authors: John Yang, Carlos E. Jimenez, et al.
- arXiv: 2405.15793
- Key: Agent-Computer Interface (ACI) design
- Results: 12.5% on SWE-bench (SOTA at release)

### 2. Devin (Cognition AI, 2024)
**"Introducing Devin, the first AI software engineer"**
- Company: Cognition AI
- Key: Long-horizon task completion
- Results: 13.86% on SWE-bench

### 3. OpenHands (All Hands AI, 2024)
**"OpenHands: An Open Platform for AI Software Developers as Generalist Agents"**
- Authors: Xingyao Wang, et al.
- arXiv: 2407.16741
- Key: Open-source alternative to Devin
- Results: Competitive with closed-source

### 4. AutoCodeRover (NUS, 2024)
**"AutoCodeRover: Autonomous Program Improvement"**
- Authors: Yuntong Zhang, et al.
- arXiv: 2404.05427
- Key: Context retrieval + patch generation
- Results: 19% on SWE-bench lite

### 5. Agentless (UIUC, 2024)
**"Agentless: Demystifying LLM-based Software Engineering Agents"**
- Authors: Chunqiu Steven Xia, et al.
- arXiv: 2407.01489
- Key: No agent loop, direct localization + repair
- Results: 27% on SWE-bench lite

---

## Reasoning Patterns

### 6. ReAct (Google, 2022)
**"ReAct: Synergizing Reasoning and Acting in Language Models"**
- Authors: Shunyu Yao, et al.
- arXiv: 2210.03629
- Key: Interleaved reasoning + action
- Impact: Foundation for agent architectures

### 7. Chain-of-Thought (Google, 2022)
**"Chain-of-Thought Prompting Elicits Reasoning in Large Language Models"**
- Authors: Jason Wei, et al.
- arXiv: 2201.11903
- Key: Step-by-step reasoning
- Impact: 2-3x improvement on reasoning tasks

### 8. Tree-of-Thought (Princeton, 2023)
**"Tree of Thoughts: Deliberate Problem Solving with Large Language Models"**
- Authors: Shunyu Yao, et al.
- arXiv: 2305.10601
- Key: Exploration of reasoning paths
- Impact: Better for complex planning

### 9. Self-Refine (CMU, 2023)
**"Self-Refine: Iterative Refinement with Self-Feedback"**
- Authors: Aman Madaan, et al.
- arXiv: 2303.17651
- Key: Iterative self-improvement
- Impact: 20% improvement on code generation

---

## Code Generation

### 10. Codex (OpenAI, 2021)
**"Evaluating Large Language Models Trained on Code"**
- Authors: Mark Chen, et al.
- arXiv: 2107.03374
- Key: HumanEval benchmark
- Results: 28.8% pass@1

### 11. AlphaCode (DeepMind, 2022)
**"Competition-Level Code Generation with AlphaCode"**
- Authors: Yujia Li, et al.
- arXiv: 2203.07814
- Key: Competitive programming
- Results: Top 54% on Codeforces

### 12. CodeLlama (Meta, 2023)
**"Code Llama: Open Foundation Models for Code"**
- Authors: Baptiste Rozière, et al.
- arXiv: 2308.12950
- Key: Open-source code LLM
- Results: 53.7% on HumanEval

### 13. StarCoder (BigCode, 2023)
**"StarCoder: may the source be with you!"**
- Authors: Raymond Li, et al.
- arXiv: 2305.06161
- Key: 15.5B params, 80+ languages
- Results: 40.8% on HumanEval

---

## Benchmarks

### 14. SWE-bench (Princeton, 2024)
**"SWE-bench: Can Language Models Resolve Real-World GitHub Issues?"**
- Authors: Carlos E. Jimenez, et al.
- arXiv: 2310.06770
- Key: 2,294 real GitHub issues
- Baseline: GPT-4 1.74%

### 15. HumanEval (OpenAI, 2021)
**"Evaluating Large Language Models Trained on Code"**
- 164 hand-written problems
- Focus: Function completion
- SOTA: GPT-4 67%

### 16. MBPP (Google, 2021)
**"Program Synthesis with Large Language Models"**
- Authors: Jacob Austin, et al.
- arXiv: 2108.07732
- 974 crowd-sourced problems
- SOTA: GPT-4 ~80%

---

## Agent Architectures

### 17. AutoGPT (2023)
**"Auto-GPT: An Autonomous GPT-4 Experiment"**
- GitHub: Significant-Gravitas/Auto-GPT
- Key: Goal-driven autonomous agent
- Impact: Popularized AI agents

### 18. BabyAGI (2023)
**"Task-driven Autonomous Agent"**
- Author: Yohei Nakajima
- Key: Task creation + prioritization
- Impact: Simple but effective loop

### 19. Voyager (NVIDIA, 2023)
**"Voyager: An Open-Ended Embodied Agent with Large Language Models"**
- Authors: Guanzhi Wang, et al.
- arXiv: 2305.16291
- Key: Lifelong learning in Minecraft
- Impact: Skill library concept

---

## Tool Use

### 20. Toolformer (Meta, 2023)
**"Toolformer: Language Models Can Teach Themselves to Use Tools"**
- Authors: Timo Schick, et al.
- arXiv: 2302.04761
- Key: Self-supervised tool learning

### 21. Gorilla (Berkeley, 2023)
**"Gorilla: Large Language Model Connected with Massive APIs"**
- Authors: Shishir G. Patil, et al.
- arXiv: 2305.15334
- Key: API call generation

---

## Memory & Context

### 22. MemGPT (Berkeley, 2023)
**"MemGPT: Towards LLMs as Operating Systems"**
- Authors: Charles Packer, et al.
- arXiv: 2310.08560
- Key: Virtual context management

### 23. Reflexion (Northeastern, 2023)
**"Reflexion: Language Agents with Verbal Reinforcement Learning"**
- Authors: Noah Shinn, et al.
- arXiv: 2303.11366
- Key: Learning from failures

---

## Sacred Formula Connection

```
V = n × 3^k × π^m × φ^p

SWE-Agent Architecture:
- 3 core loops (Plan, Execute, Verify)
- φ-ratio task decomposition
- π-cycle iteration
- 999 = 37 × 3³ (PHOENIX pattern)

φ² + 1/φ² = 3 ✓ VERIFIED
```

---

## Technology Tree Dependencies

```
ReAct (2022)
    ↓
Chain-of-Thought (2022)
    ↓
Tree-of-Thought (2023)
    ↓
SWE-Agent (2024)
    ↓
IGLA SWE Agent (2026)
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
