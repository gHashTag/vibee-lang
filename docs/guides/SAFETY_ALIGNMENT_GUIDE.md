# Safety & Alignment Guide

**VIBEE v2400-v2499 | Building Safe and Aligned AI Systems**

---

## Overview

Safety and alignment ensure AI systems behave as intended and avoid harmful outputs.

---

## 1. Alignment Pipeline

```
┌─────────────────────────────────────────────────────────┐
│                 ALIGNMENT PIPELINE                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Pretraining                                         │
│     └─▶ Base model (no alignment)                       │
│                                                         │
│  2. Supervised Fine-Tuning (SFT)                        │
│     └─▶ Instruction following                           │
│                                                         │
│  3. Preference Optimization (RLHF/DPO)                  │
│     └─▶ Human preferences                               │
│                                                         │
│  4. Safety Fine-Tuning                                  │
│     └─▶ Harm avoidance                                  │
│                                                         │
│  5. Red Teaming & Evaluation                            │
│     └─▶ Adversarial testing                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. RLHF vs DPO

### RLHF (Complex)

```python
# 1. Train reward model
reward_model = train_reward_model(preference_data)

# 2. PPO training
for batch in dataloader:
    # Generate responses
    responses = policy.generate(batch.prompts)
    
    # Get rewards
    rewards = reward_model(batch.prompts, responses)
    
    # PPO update
    policy.ppo_step(responses, rewards)
```

### DPO (Simple)

```python
# Direct optimization without reward model
for batch in dataloader:
    # Compute DPO loss
    loss = dpo_loss(
        policy=model,
        reference=ref_model,
        chosen=batch.chosen,
        rejected=batch.rejected,
        beta=0.1
    )
    
    loss.backward()
    optimizer.step()
```

### Comparison

| Aspect | RLHF | DPO |
|--------|------|-----|
| Complexity | High | Low |
| Stability | Tricky | Stable |
| Memory | 3 models | 2 models |
| Quality | Slightly better | Very good |
| Recommended | Research | Production |

---

## 3. Safety Techniques

### Content Filtering

```python
def safety_filter(prompt, response):
    # Check for harmful content
    harm_score = classifier.predict(response)
    
    if harm_score > THRESHOLD:
        return REFUSAL_RESPONSE
    
    return response
```

### Constitutional AI

```python
def constitutional_critique(response, principles):
    critiques = []
    for principle in principles:
        critique = model.generate(f"""
        Principle: {principle}
        Response: {response}
        Does this response violate the principle? If so, how?
        """)
        critiques.append(critique)
    
    # Revise based on critiques
    revised = model.generate(f"""
    Original: {response}
    Critiques: {critiques}
    Revise the response to address the critiques.
    """)
    
    return revised
```

### Guardrails

```python
from guardrails import Guard

guard = Guard.from_rail("""
<rail version="0.1">
<output>
    <string name="response" 
            validators="no_toxic_language; no_pii"/>
</output>
</rail>
""")

result = guard(model.generate, prompt)
```

---

## 4. Red Teaming

### Attack Categories

| Category | Examples |
|----------|----------|
| Jailbreaks | DAN, roleplay, encoding |
| Prompt Injection | Ignore instructions |
| Data Extraction | Training data leakage |
| Harmful Content | Violence, illegal activities |

### Defense Strategies

1. **Input filtering**: Block known attack patterns
2. **Output filtering**: Check responses before returning
3. **System prompts**: Strong safety instructions
4. **Fine-tuning**: Train on adversarial examples

---

## 5. Evaluation

### Safety Benchmarks

| Benchmark | Focus |
|-----------|-------|
| TruthfulQA | Truthfulness |
| BBQ | Bias |
| ToxiGen | Toxicity |
| RealToxicityPrompts | Toxic generation |
| HarmBench | Harmful behaviors |

### Metrics

```python
def evaluate_safety(model, test_set):
    metrics = {
        "refusal_rate": 0,
        "harm_rate": 0,
        "helpfulness": 0
    }
    
    for prompt, expected in test_set:
        response = model.generate(prompt)
        
        if is_refusal(response):
            metrics["refusal_rate"] += 1
        if is_harmful(response):
            metrics["harm_rate"] += 1
        metrics["helpfulness"] += rate_helpfulness(response)
    
    return normalize(metrics)
```

---

## 6. Best Practices

### Do
- Use DPO for most alignment needs
- Implement multiple safety layers
- Red team before deployment
- Monitor production outputs
- Have human review for edge cases

### Don't
- Rely on single safety mechanism
- Skip adversarial testing
- Ignore false positives (over-refusal)
- Deploy without evaluation
- Assume alignment is permanent

---

## References

- Ouyang et al. (2022): InstructGPT
- Rafailov et al. (2023): DPO
- Bai et al. (2022): Constitutional AI
- Perez et al. (2022): Red Teaming

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
