# Evaluation & Benchmarks Guide

**VIBEE v2500-v2599 | Measuring Model Capabilities**

---

## Overview

Proper evaluation is essential for understanding model capabilities and limitations.

---

## 1. Benchmark Categories

```
┌─────────────────────────────────────────────────────────┐
│                 EVALUATION TAXONOMY                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Knowledge          Reasoning         Code              │
│  ├─ MMLU            ├─ GSM8K          ├─ HumanEval     │
│  ├─ TriviaQA        ├─ MATH           ├─ MBPP          │
│  ├─ NaturalQuestions├─ ARC            ├─ SWE-bench     │
│  └─ WebQuestions    └─ HellaSwag      └─ BigCodeBench  │
│                                                         │
│  Language           Safety            Multimodal        │
│  ├─ WinoGrande      ├─ TruthfulQA     ├─ VQA          │
│  ├─ LAMBADA         ├─ BBQ            ├─ COCO         │
│  ├─ BoolQ           ├─ ToxiGen        ├─ TextVQA      │
│  └─ PIQA            └─ RealToxicity   └─ DocVQA       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Key Benchmarks

### MMLU (Knowledge)

```python
# 57 subjects, 14K questions
# Tests: World knowledge, reasoning

example = {
    "question": "What is the capital of France?",
    "choices": ["London", "Paris", "Berlin", "Madrid"],
    "answer": "B"
}

# Evaluation
accuracy = correct / total
```

### GSM8K (Math Reasoning)

```python
# 8.5K grade school math problems
# Tests: Multi-step reasoning

example = {
    "question": "If John has 5 apples and buys 3 more, how many does he have?",
    "answer": "8"
}

# Evaluation: Exact match on final answer
```

### HumanEval (Code)

```python
# 164 programming problems
# Tests: Code generation

example = {
    "prompt": "def add(a, b):\n    '''Add two numbers'''",
    "test": "assert add(1, 2) == 3"
}

# Evaluation: pass@k (k attempts)
pass_at_1 = problems_solved / total
```

### MT-Bench (Conversation)

```python
# 80 multi-turn conversations
# Tests: Instruction following, conversation

# Evaluation: GPT-4 as judge (1-10 scale)
score = gpt4_judge(response)
```

---

## 3. Evaluation Framework

### lm-evaluation-harness

```bash
# Install
pip install lm-eval

# Run evaluation
lm_eval --model hf \
    --model_args pretrained=meta-llama/Llama-2-7b-hf \
    --tasks mmlu,gsm8k,humaneval \
    --batch_size 8 \
    --output_path results/
```

### Custom Evaluation

```python
from lm_eval import evaluator, tasks

results = evaluator.simple_evaluate(
    model="hf",
    model_args="pretrained=my-model",
    tasks=["mmlu", "gsm8k"],
    num_fewshot=5,
    batch_size=8
)

print(results["results"])
```

---

## 4. Metrics

### Accuracy Metrics

| Metric | Use Case |
|--------|----------|
| Accuracy | Classification |
| Exact Match | QA, Math |
| F1 Score | Extraction |
| BLEU/ROUGE | Generation |
| pass@k | Code |

### Efficiency Metrics

| Metric | Formula |
|--------|---------|
| Throughput | tokens/second |
| Latency | time to first token |
| Memory | peak GPU memory |
| Cost | $/1M tokens |

---

## 5. Leaderboards

### Open LLM Leaderboard

| Model | MMLU | GSM8K | HumanEval | Average |
|-------|------|-------|-----------|---------|
| GPT-4 | 86.4 | 92.0 | 67.0 | 81.8 |
| Claude 3 | 86.8 | 95.0 | 84.9 | 88.9 |
| Llama 3 70B | 82.0 | 93.0 | 81.7 | 85.6 |
| Mistral Large | 81.2 | 91.2 | 45.1 | 72.5 |

### Chatbot Arena

- ELO-based ranking
- Human preference votes
- Blind A/B testing

---

## 6. Best Practices

### Evaluation Design

1. **Use multiple benchmarks**: No single benchmark captures everything
2. **Report confidence intervals**: Results vary with random seeds
3. **Control for contamination**: Check for benchmark data in training
4. **Use held-out test sets**: Don't tune on evaluation data

### Common Pitfalls

- **Overfitting to benchmarks**: High scores, poor real-world performance
- **Cherry-picking**: Only reporting favorable results
- **Prompt sensitivity**: Results vary with prompt format
- **Contamination**: Training on test data

---

## 7. Evaluation Checklist

### Before Release
- [ ] MMLU (knowledge)
- [ ] GSM8K/MATH (reasoning)
- [ ] HumanEval (code)
- [ ] MT-Bench (conversation)
- [ ] TruthfulQA (safety)

### For Production
- [ ] Latency benchmarks
- [ ] Throughput benchmarks
- [ ] Cost analysis
- [ ] A/B testing with users

---

## References

- Hendrycks et al. (2021): MMLU
- Cobbe et al. (2021): GSM8K
- Chen et al. (2021): HumanEval
- Zheng et al. (2023): MT-Bench

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
