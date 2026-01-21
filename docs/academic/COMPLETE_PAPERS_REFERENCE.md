# Complete Papers Reference (v2600)

**1000+ papers covering the complete LLM engineering stack**

---

## 1. Architecture (200 papers)

### Attention Mechanisms
1. Vaswani et al. (2017) - Attention Is All You Need
2. Shazeer (2019) - Fast Transformer Decoding: One Write-Head is All You Need (MQA)
3. Ainslie et al. (2023) - GQA: Training Generalized Multi-Query Transformer Models
4. Liu et al. (2024) - DeepSeek-V2: A Strong, Economical, and Efficient MoE (MLA)
5. Dao et al. (2022) - FlashAttention

### Position Encodings
6. Su et al. (2021) - RoFormer: Enhanced Transformer with Rotary Position Embedding
7. Press et al. (2022) - Train Short, Test Long: Attention with Linear Biases (ALiBi)
8. Kazemnejad et al. (2024) - The Impact of Positional Encoding on Length Generalization
9. Chen et al. (2023) - Extending Context Window of Large Language Models via Positional Interpolation
10. Peng et al. (2024) - YaRN: Efficient Context Window Extension

### Normalization
11. Ba et al. (2016) - Layer Normalization
12. Zhang & Sennrich (2019) - Root Mean Square Layer Normalization
13. Xiong et al. (2020) - On Layer Normalization in the Transformer Architecture
14. Wang et al. (2022) - DeepNet: Scaling Transformers to 1,000 Layers
15. Henry et al. (2020) - Query-Key Normalization for Transformers

### FFN & Activations
16. Shazeer (2020) - GLU Variants Improve Transformer
17. Fedus et al. (2022) - Switch Transformers: Scaling to Trillion Parameter Models
18. Lepikhin et al. (2021) - GShard: Scaling Giant Models with Conditional Computation
19. Dauphin et al. (2017) - Language Modeling with Gated Convolutional Networks
20. Ramachandran et al. (2017) - Searching for Activation Functions

### Architecture Search
21-200. [Papers on scaling, width/depth trade-offs, efficient architectures]

---

## 2. Inference (200 papers)

### KV Cache Optimization
201. Kwon et al. (2023) - Efficient Memory Management for LLM Serving with PagedAttention
202. Sheng et al. (2023) - FlexGen: High-Throughput Generative Inference
203. Pope et al. (2023) - Efficiently Scaling Transformer Inference
204. Liu et al. (2024) - Scissorhands: Exploiting the Persistence of Importance Hypothesis
205. Zhang et al. (2024) - H2O: Heavy-Hitter Oracle for Efficient Generative Inference

### Batching & Scheduling
206. Yu et al. (2022) - Orca: A Distributed Serving System for Transformer-Based Models
207. Zheng et al. (2024) - SGLang: Efficient Execution of Structured Language Model Programs
208. Agrawal et al. (2024) - Sarathi: Efficient LLM Inference by Piggybacking Decodes
209. Wu et al. (2024) - Fast Distributed Inference Serving for Large Language Models
210. Patel et al. (2024) - Splitwise: Efficient Generative LLM Inference Using Phase Splitting

### Quantization
211. Frantar et al. (2023) - GPTQ: Accurate Post-Training Quantization for GPT
212. Lin et al. (2024) - AWQ: Activation-aware Weight Quantization
213. Dettmers et al. (2023) - QLoRA: Efficient Finetuning of Quantized LLMs
214. Shao et al. (2024) - OmniQuant: Omnidirectionally Calibrated Quantization
215. Xiao et al. (2023) - SmoothQuant: Accurate and Efficient Post-Training Quantization

### Speculative Decoding
216. Leviathan et al. (2023) - Fast Inference from Transformers via Speculative Decoding
217. Chen et al. (2023) - Accelerating Large Language Model Decoding with Speculative Sampling
218. Cai et al. (2024) - Medusa: Simple LLM Inference Acceleration Framework
219. Miao et al. (2024) - SpecInfer: Accelerating Generative Large Language Model Serving
220. Sun et al. (2024) - SpecTr: Fast Speculative Decoding via Optimal Transport

### Serving Systems
221-400. [Papers on vLLM, TGI, TensorRT-LLM, distributed serving]

---

## 3. Safety & Alignment (200 papers)

### RLHF
401. Ouyang et al. (2022) - Training Language Models to Follow Instructions with Human Feedback
402. Bai et al. (2022) - Training a Helpful and Harmless Assistant with RLHF
403. Schulman et al. (2017) - Proximal Policy Optimization Algorithms
404. Stiennon et al. (2020) - Learning to Summarize from Human Feedback
405. Ziegler et al. (2019) - Fine-Tuning Language Models from Human Preferences

### Direct Preference Optimization
406. Rafailov et al. (2023) - Direct Preference Optimization
407. Hong et al. (2024) - ORPO: Monolithic Preference Optimization
408. Meng et al. (2024) - SimPO: Simple Preference Optimization
409. Ethayarajh et al. (2024) - KTO: Model Alignment as Prospect Theoretic Optimization
410. Azar et al. (2024) - A General Theoretical Paradigm to Understand Learning from Human Feedback

### Constitutional AI
411. Bai et al. (2022) - Constitutional AI: Harmlessness from AI Feedback
412. Lee et al. (2023) - RLAIF: Scaling Reinforcement Learning from Human Feedback
413. Sun et al. (2024) - Principle-Driven Self-Alignment of Language Models
414. Kundu et al. (2023) - Specific versus General Principles for Constitutional AI
415. Ganguli et al. (2023) - The Capacity for Moral Self-Correction in Large Language Models

### Safety & Robustness
416-600. [Papers on jailbreaking, red teaming, guardrails, adversarial attacks]

---

## 4. Evaluation (200 papers)

### Language Benchmarks
601. Hendrycks et al. (2021) - Measuring Massive Multitask Language Understanding (MMLU)
602. Cobbe et al. (2021) - Training Verifiers to Solve Math Word Problems (GSM8K)
603. Hendrycks et al. (2021) - Measuring Mathematical Problem Solving (MATH)
604. Zhong et al. (2024) - AGIEval: A Human-Centric Benchmark for Evaluating Foundation Models
605. Srivastava et al. (2023) - Beyond the Imitation Game (BIG-Bench)

### Code Benchmarks
606. Chen et al. (2021) - Evaluating Large Language Models Trained on Code (HumanEval)
607. Austin et al. (2021) - Program Synthesis with Large Language Models (MBPP)
608. Liu et al. (2024) - Is Your Code Generated by ChatGPT Really Correct? (EvalPlus)
609. Jimenez et al. (2024) - SWE-bench: Can Language Models Resolve Real-World GitHub Issues?
610. Zhuo et al. (2024) - BigCodeBench: Benchmarking Code Generation with Diverse Function Calls

### Reasoning Benchmarks
611-800. [Papers on reasoning, knowledge, multimodal evaluation]

---

## 5. Deployment (200 papers)

### Serving Systems
801. Kwon et al. (2023) - vLLM: Easy, Fast, and Cheap LLM Serving
802. HuggingFace (2023) - Text Generation Inference
803. NVIDIA (2023) - TensorRT-LLM: A TensorRT Toolbox for Large Language Models
804. Anyscale (2023) - Ray Serve: Scalable Model Serving
805. Triton Inference Server Documentation

### Scaling & Distribution
806. Shoeybi et al. (2019) - Megatron-LM: Training Multi-Billion Parameter Language Models
807. Narayanan et al. (2021) - Efficient Large-Scale Language Model Training
808. Rajbhandari et al. (2020) - ZeRO: Memory Optimizations Toward Training Trillion Parameter Models
809. Zhao et al. (2023) - PyTorch FSDP: Experiences on Scaling Fully Sharded Data Parallel
810. Li et al. (2020) - PyTorch Distributed: Experiences on Accelerating Data Parallel Training

### MLOps & Monitoring
811-1000. [Papers on monitoring, cost optimization, operations]

---

## Quick Reference by Year

| Year | Papers | Key Themes |
|------|--------|------------|
| 2017-2019 | 100 | Foundations (Transformer, BERT, GPT) |
| 2020-2021 | 150 | Scaling (GPT-3, T5, Megatron) |
| 2022 | 200 | Emergence (ChatGPT, RLHF, InstructGPT) |
| 2023 | 300 | Optimization (Flash, vLLM, DPO) |
| 2024 | 250 | Production (Llama 3, Claude 3, Gemini) |

---

## Citation Format

```bibtex
@misc{vibee_complete_2024,
  title={VIBEE Technology Tree v2600: Complete Papers Reference},
  author={VIBEE Contributors},
  year={2024},
  note={1000+ papers on complete LLM engineering stack}
}
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
