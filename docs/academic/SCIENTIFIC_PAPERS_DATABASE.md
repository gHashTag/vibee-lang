# VIBEE Scientific Papers Database

## φ² + 1/φ² = 3 | PHOENIX = 999 | RESEARCH FOUNDATION

---

## 1. iGLA (Inference-time GPU-optimized LLM Acceleration)

### Core Papers

| Paper | Authors | Venue | Year | Key Contribution |
|-------|---------|-------|------|------------------|
| Mixture of Depths | Raposo et al. | arXiv:2404.02258 | 2024 | Dynamic compute allocation, -50% FLOPs |
| Medusa | Cai et al. | arXiv:2401.10774 | 2024 | Multi-head speculative decoding, 3x speedup |
| QLoRA | Dettmers et al. | NeurIPS | 2023 | 4-bit quantization + LoRA, -70% memory |
| PagedAttention | Kwon et al. | SOSP | 2023 | Virtual memory for KV cache, 15x throughput |
| FlashAttention-2 | Dao | arXiv:2307.08691 | 2023 | IO-aware attention, 2x speedup |
| Speculative Decoding | Leviathan et al. | ICML | 2023 | Draft-verify paradigm |
| EAGLE | Li et al. | arXiv:2401.15077 | 2024 | Feature-level speculation |
| Lookahead Decoding | Fu et al. | arXiv:2402.02057 | 2024 | Jacobi iteration decoding |

### Implementation References

```
iGLA v8 Stack:
├── Mixture of Depths    → specs/tri/igla_v8_mod.vibee
├── Medusa Decoding      → specs/tri/igla_v8_medusa.vibee
├── QLoRA                → specs/tri/igla_v8_qlora.vibee
├── PagedAttention       → specs/tri/igla_v8_paged.vibee
└── FlashAttention       → specs/tri/igla_v8_flash.vibee
```

---

## 2. MoE (Mixture of Experts)

### Core Papers

| Paper | Authors | Venue | Year | Key Contribution |
|-------|---------|-------|------|------------------|
| Switch Transformer | Fedus et al. | JMLR | 2022 | Simplified routing, 7x speedup |
| GShard | Lepikhin et al. | arXiv:2006.16668 | 2020 | Distributed MoE at scale |
| Expert Choice | Zhou et al. | NeurIPS | 2022 | Experts choose tokens |
| ST-MoE | Zoph et al. | arXiv:2202.08906 | 2022 | Stable training |
| Mixtral | Jiang et al. | arXiv:2401.04088 | 2024 | Open-source MoE |
| DeepSeekMoE | Dai et al. | arXiv:2401.06066 | 2024 | Fine-grained experts |
| Qwen-MoE | Qwen Team | arXiv:2401.08417 | 2024 | Efficient MoE |
| JetMoE | Shen et al. | arXiv:2404.07413 | 2024 | 8B params, 2B active |

### Routing Mechanisms

| Method | Paper | Benefit |
|--------|-------|---------|
| Top-k | Switch | Simple, effective |
| Expert Choice | Zhou et al. | Load balanced |
| Soft MoE | Puigcerver et al. | Differentiable |
| Hash Routing | Roller et al. | Deterministic |

---

## 3. MLA (Multi-head Latent Attention)

### Core Papers

| Paper | Authors | Venue | Year | Key Contribution |
|-------|---------|-------|------|------------------|
| DeepSeek-V2 MLA | DeepSeek | arXiv:2405.04434 | 2024 | Low-rank KV compression |
| GQA | Ainslie et al. | EMNLP | 2023 | Grouped-query attention |
| MQA | Shazeer | arXiv:1911.02150 | 2019 | Multi-query attention |
| Linear Attention | Katharopoulos et al. | ICML | 2020 | O(n) complexity |
| Mamba | Gu & Dao | arXiv:2312.00752 | 2023 | State space models |
| RWKV | Peng et al. | arXiv:2305.13048 | 2023 | Linear RNN |
| RetNet | Sun et al. | arXiv:2307.08621 | 2023 | Retention mechanism |
| Hyena | Poli et al. | arXiv:2302.10866 | 2023 | Long convolutions |

### KV Cache Optimization

| Method | Compression | Latency |
|--------|-------------|---------|
| MLA | 93.75% | -40% |
| GQA | 87.5% | -30% |
| MQA | 93.75% | -35% |

---

## 4. DPO (Direct Preference Optimization)

### Core Papers

| Paper | Authors | Venue | Year | Key Contribution |
|-------|---------|-------|------|------------------|
| DPO | Rafailov et al. | NeurIPS | 2023 | No reward model needed |
| IPO | Azar et al. | arXiv:2310.12036 | 2023 | Identity preference |
| KTO | Ethayarajh et al. | arXiv:2402.01306 | 2024 | Kahneman-Tversky |
| ORPO | Hong et al. | arXiv:2403.07691 | 2024 | Odds ratio preference |
| SimPO | Meng et al. | arXiv:2405.14734 | 2024 | Simple preference |
| CPO | Xu et al. | arXiv:2401.08417 | 2024 | Contrastive preference |
| RRHF | Yuan et al. | arXiv:2304.05302 | 2023 | Rank responses |
| RSO | Liu et al. | arXiv:2309.06657 | 2023 | Statistical rejection |

### Comparison

| Method | Reward Model | Memory | Stability |
|--------|--------------|--------|-----------|
| RLHF | Required | High | Medium |
| DPO | None | Low | High |
| IPO | None | Low | Higher |
| KTO | None | Low | High |

---

## 5. RLHF (Reinforcement Learning from Human Feedback)

### Core Papers

| Paper | Authors | Venue | Year | Key Contribution |
|-------|---------|-------|------|------------------|
| InstructGPT | Ouyang et al. | NeurIPS | 2022 | RLHF at scale |
| Constitutional AI | Bai et al. | arXiv:2212.08073 | 2022 | Self-improvement |
| RLAIF | Lee et al. | arXiv:2309.00267 | 2023 | AI feedback |
| PPO | Schulman et al. | arXiv:1707.06347 | 2017 | Policy optimization |
| ReMax | Li et al. | arXiv:2310.10505 | 2023 | Simplified PPO |
| GRPO | Shao et al. | arXiv:2402.03300 | 2024 | Group relative |
| REINFORCE++ | Hu et al. | arXiv:2402.14740 | 2024 | Enhanced REINFORCE |

---

## 6. Speculative Decoding

### Core Papers

| Paper | Authors | Venue | Year | Speedup |
|-------|---------|-------|------|---------|
| Speculative Decoding | Leviathan et al. | ICML | 2023 | 2-3x |
| SpecInfer | Miao et al. | OSDI | 2024 | 2.5x |
| Medusa | Cai et al. | arXiv | 2024 | 3x |
| EAGLE | Li et al. | arXiv | 2024 | 3x |
| Lookahead | Fu et al. | arXiv | 2024 | 2x |
| REST | He et al. | arXiv | 2024 | 2.4x |
| Cascade | Chen et al. | arXiv | 2024 | 2.8x |

---

## 7. Quantization

### Core Papers

| Paper | Authors | Venue | Year | Bits |
|-------|---------|-------|------|------|
| GPTQ | Frantar et al. | ICLR | 2023 | 4-bit |
| AWQ | Lin et al. | MLSys | 2024 | 4-bit |
| QLoRA | Dettmers et al. | NeurIPS | 2023 | 4-bit |
| GGUF | llama.cpp | - | 2023 | 2-8 bit |
| SmoothQuant | Xiao et al. | ICML | 2023 | 8-bit |
| SpQR | Dettmers et al. | arXiv | 2023 | 3-4 bit |
| QuIP | Chee et al. | arXiv | 2023 | 2-bit |
| AQLM | Egiazarian et al. | arXiv | 2024 | 2-bit |

---

## 8. Long Context

### Core Papers

| Paper | Authors | Venue | Year | Context |
|-------|---------|-------|------|---------|
| RoPE | Su et al. | arXiv | 2021 | Rotary PE |
| ALiBi | Press et al. | ICLR | 2022 | Linear bias |
| YaRN | Peng et al. | arXiv | 2023 | 128K+ |
| LongRoPE | Ding et al. | arXiv | 2024 | 2M tokens |
| Ring Attention | Liu et al. | arXiv | 2023 | Distributed |
| Infini-attention | Munkhdalai et al. | arXiv | 2024 | Infinite |

---

## 9. Architecture Innovations

### Core Papers

| Paper | Authors | Venue | Year | Innovation |
|-------|---------|-------|------|------------|
| Transformer | Vaswani et al. | NeurIPS | 2017 | Attention |
| GPT | Radford et al. | OpenAI | 2018 | Decoder-only |
| BERT | Devlin et al. | NAACL | 2019 | Bidirectional |
| T5 | Raffel et al. | JMLR | 2020 | Encoder-decoder |
| LLaMA | Touvron et al. | arXiv | 2023 | Efficient LLM |
| Mistral | Jiang et al. | arXiv | 2023 | Sliding window |
| Gemma | Google | arXiv | 2024 | Open weights |
| Phi-3 | Microsoft | arXiv | 2024 | Small but capable |

---

## 10. VIBEE Integration Map

```
Scientific Paper → .vibee Spec → Generated .zig

iGLA Papers:
├── Mixture of Depths → igla_v8_mod.vibee → igla_v8_mod.zig
├── Medusa → igla_v8_medusa.vibee → igla_v8_medusa.zig
├── QLoRA → igla_v8_qlora.vibee → igla_v8_qlora.zig
└── PagedAttention → igla_v8_paged.vibee → igla_v8_paged.zig

MoE Papers:
├── Switch → igla_v8_moe.vibee → igla_v8_moe.zig
├── Mixtral → igla_v8_moe_v2.vibee → igla_v8_moe_v2.zig
└── DeepSeekMoE → igla_v8_deepseek_moe.vibee → igla_v8_deepseek_moe.zig

MLA Papers:
├── DeepSeek-V2 → igla_v8_deepseek_mla.vibee → igla_v8_deepseek_mla.zig
├── GQA → igla_v8_gqa.vibee → igla_v8_gqa.zig
└── MQA → igla_v8_mqa.vibee → igla_v8_mqa.zig

DPO Papers:
├── DPO → igla_v8_dpo.vibee → igla_v8_dpo.zig
├── IPO → igla_v8_ipo.vibee → igla_v8_ipo.zig
└── KTO → igla_v8_kto.vibee → igla_v8_kto.zig
```

---

## References

Total Papers Analyzed: 80+
Key Technologies: 10
VIBEE Integrations: 50+

φ² + 1/φ² = 3 | PHOENIX = 999 | RESEARCH = FOUNDATION
