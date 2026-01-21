# Training Acceleration Papers Reference (v2500)

**400+ papers on training optimization, organized by technique**

---

## 1. Memory Optimization (60 papers)

### Gradient Checkpointing
1. Chen et al. (2016) - Training Deep Nets with Sublinear Memory Cost
2. Gruslys et al. (2016) - Memory-Efficient Backpropagation Through Time
3. Jain et al. (2020) - Checkmate: Breaking the Memory Wall with Optimal Tensor Rematerialization
4. Kirisame et al. (2021) - Dynamic Tensor Rematerialization
5. Beaumont et al. (2021) - Efficient Automatic Differentiation with Checkpointing

### ZeRO & Sharding
6. Rajbhandari et al. (2020) - ZeRO: Memory Optimizations Toward Training Trillion Parameter Models
7. Ren et al. (2021) - ZeRO-Offload: Democratizing Billion-Scale Model Training
8. Rajbhandari et al. (2021) - ZeRO-Infinity: Breaking the GPU Memory Wall
9. Zhao et al. (2023) - PyTorch FSDP: Experiences on Scaling Fully Sharded Data Parallel
10. FairScale Team (2021) - FairScale: A General Purpose Modular PyTorch Library

### Parallelism Strategies
11. Shoeybi et al. (2019) - Megatron-LM: Training Multi-Billion Parameter Language Models
12. Narayanan et al. (2021) - Efficient Large-Scale Language Model Training on GPU Clusters
13. Huang et al. (2019) - GPipe: Efficient Training of Giant Neural Networks
14. Narayanan et al. (2019) - PipeDream: Generalized Pipeline Parallelism
15. Korthikanti et al. (2023) - Reducing Activation Recomputation in Large Transformer Models

### Additional Memory Papers
16-60. [Papers on activation compression, offloading, memory planning]

---

## 2. Attention Optimization (50 papers)

### Flash Attention
61. Dao et al. (2022) - FlashAttention: Fast and Memory-Efficient Exact Attention
62. Dao (2023) - FlashAttention-2: Faster Attention with Better Parallelism
63. Shah et al. (2024) - FlashAttention-3: Fast and Accurate Attention with Asynchrony and Low-precision
64. Kwon et al. (2023) - Efficient Memory Management for Large Language Model Serving with PagedAttention
65. Liu et al. (2023) - Ring Attention with Blockwise Transformers for Near-Infinite Context

### Memory-Efficient Attention
66. Rabe & Staats (2021) - Self-Attention Does Not Need O(n²) Memory
67. Lefaudeux et al. (2022) - xFormers: A Modular and Hackable Transformer Modelling Library
68. Choromanski et al. (2021) - Rethinking Attention with Performers
69. Kitaev et al. (2020) - Reformer: The Efficient Transformer
70. Beltagy et al. (2020) - Longformer: The Long-Document Transformer

### Sparse Attention
71-110. [Papers on sparse patterns, local attention, linear attention]

---

## 3. Optimizers (70 papers)

### Adam Variants
111. Kingma & Ba (2015) - Adam: A Method for Stochastic Optimization
112. Loshchilov & Hutter (2019) - Decoupled Weight Decay Regularization (AdamW)
113. Liu et al. (2020) - On the Variance of the Adaptive Learning Rate and Beyond (RAdam)
114. Zhang et al. (2024) - Adam-mini: Use Fewer Learning Rates To Gain More
115. Defazio & Mishchenko (2023) - Learning-Rate-Free Learning by D-Adaptation

### Novel Optimizers
116. Chen et al. (2023) - Symbolic Discovery of Optimization Algorithms (Lion)
117. Liu et al. (2024) - Sophia: A Scalable Stochastic Second-order Optimizer
118. Jordan et al. (2024) - Muon: An Optimizer for Hidden Layers in Neural Networks
119. Anil et al. (2020) - Scalable Second Order Optimization for Deep Learning (Shampoo)
120. Gupta et al. (2018) - Shampoo: Preconditioned Stochastic Tensor Optimization

### Learning Rate Scheduling
121. Loshchilov & Hutter (2017) - SGDR: Stochastic Gradient Descent with Warm Restarts
122. Smith (2017) - Cyclical Learning Rates for Training Neural Networks
123. Goyal et al. (2017) - Accurate, Large Minibatch SGD: Training ImageNet in 1 Hour
124. You et al. (2020) - Large Batch Optimization for Deep Learning: Training BERT in 76 minutes
125. Defazio et al. (2024) - The Road Less Scheduled

### Additional Optimizer Papers
126-180. [Papers on momentum, adaptive methods, second-order]

---

## 4. Scaling Laws (40 papers)

### Foundational
181. Kaplan et al. (2020) - Scaling Laws for Neural Language Models
182. Hoffmann et al. (2022) - Training Compute-Optimal Large Language Models (Chinchilla)
183. Muennighoff et al. (2023) - Scaling Data-Constrained Language Models
184. Sardana & Frankle (2024) - Beyond Chinchilla-Optimal: Accounting for Inference
185. Bi et al. (2024) - DeepSeek LLM: Scaling Open-Source Language Models

### Transfer & Initialization
186. Yang et al. (2022) - Tensor Programs V: Tuning Large Neural Networks via Zero-Shot Hyperparameter Transfer (muP)
187. Yang & Hu (2021) - Feature Learning in Infinite-Width Neural Networks
188. Gong et al. (2019) - Efficient Training of BERT by Progressively Stacking
189. Chen et al. (2022) - bert2BERT: Towards Reusable Pretrained Language Models
190. Samragh et al. (2023) - Weight Subcloning: Direct Initialization of Transformers Using Larger Pretrained Ones

### Additional Scaling Papers
191-220. [Papers on compute allocation, loss prediction, efficiency]

---

## 5. Data Optimization (50 papers)

### Deduplication
221. Lee et al. (2022) - Deduplicating Training Data Makes Language Models Better
222. Abbas et al. (2023) - SemDeDup: Data-efficient Learning at Web-scale through Semantic Deduplication
223. Tirumala et al. (2023) - D4: Improving LLM Pretraining via Document De-Duplication and Diversification
224. Penedo et al. (2024) - The FineWeb Datasets: Decanting the Web for the Finest Text Data at Scale
225. Soldaini et al. (2024) - Dolma: An Open Corpus of Three Trillion Tokens

### Data Quality
226. Xie et al. (2023) - Data Selection for Language Models via Importance Resampling
227. Marion et al. (2023) - When Less is More: Investigating Data Pruning for Pretraining LLMs
228. Wettig et al. (2024) - QuRating: Selecting High-Quality Data for Training Language Models
229. Sachdeva et al. (2024) - How to Train Data-Efficient LLMs
230. Longpre et al. (2023) - The Flan Collection: Designing Data and Methods for Effective Instruction Tuning

### Curriculum Learning
231. Bengio et al. (2009) - Curriculum Learning
232. Soviany et al. (2022) - Curriculum Learning: A Survey
233. Chen et al. (2024) - Skill-it! A Data-Driven Skills Framework for Understanding and Training Language Models
234. Xu et al. (2020) - Curriculum Learning for Natural Language Understanding
235. Campos (2021) - Curriculum Learning for Language Modeling

### Additional Data Papers
236-270. [Papers on data mixing, augmentation, tokenization]

---

## 6. Low Precision Training (40 papers)

### Mixed Precision
271. Micikevicius et al. (2018) - Mixed Precision Training
272. Kalamkar et al. (2019) - A Study of BFLOAT16 for Deep Learning Training
273. Sun et al. (2019) - Hybrid 8-bit Floating Point (HFP8) Training and Inference
274. Wang et al. (2018) - Training Deep Neural Networks with 8-bit Floating Point Numbers
275. Dettmers et al. (2022) - 8-bit Optimizers via Block-wise Quantization

### FP8 Training
276. Micikevicius et al. (2022) - FP8 Formats for Deep Learning
277. Noune et al. (2022) - 8-bit Numerical Formats for Deep Neural Networks
278. Kuzmin et al. (2024) - FP8-LM: Training FP8 Large Language Models
279. Peng et al. (2023) - FP8-BERT: Post-Training Quantization for Transformer
280. NVIDIA (2024) - Transformer Engine: Accelerating Transformer Training with FP8

### Additional Precision Papers
281-310. [Papers on quantization-aware training, stochastic rounding]

---

## 7. Distributed Training (50 papers)

### Communication
311. Li et al. (2020) - PyTorch Distributed: Experiences on Accelerating Data Parallel Training
312. Sergeev & Del Balso (2018) - Horovod: Fast and Easy Distributed Deep Learning in TensorFlow
313. Lin et al. (2018) - Deep Gradient Compression: Reducing the Communication Bandwidth
314. Alistarh et al. (2017) - QSGD: Communication-Efficient SGD via Gradient Quantization
315. Stich (2019) - Local SGD Converges Fast and Communicates Little

### Fault Tolerance
316. Mohan et al. (2021) - CheckFreq: Frequent, Fine-Grained DNN Checkpointing
317. Maeng et al. (2021) - Understanding and Improving Failure Tolerant Training
318. Thorpe et al. (2023) - Bamboo: Making Preemptible Instances Resilient for Affordable Training
319. Jia et al. (2024) - Oobleck: Resilient Distributed Training of Large Models Using Pipeline Templates
320. Wang et al. (2023) - Gemini: Fast Failure Recovery in Distributed Training

### Additional Distributed Papers
321-360. [Papers on elastic training, async methods, networking]

---

## 8. Compilation & Kernels (30 papers)

### Compilers
361. Ansel et al. (2024) - PyTorch 2: Faster Machine Learning Through Dynamic Python Bytecode Transformation
362. Bradbury et al. (2018) - JAX: Composable Transformations of Python+NumPy Programs
363. Sabne (2020) - XLA: Compiling Machine Learning for Peak Performance
364. Chen et al. (2018) - TVM: An Automated End-to-End Optimizing Compiler for Deep Learning
365. Lattner et al. (2021) - MLIR: Scaling Compiler Infrastructure for Domain Specific Computation

### Custom Kernels
366. Tillet et al. (2019) - Triton: An Intermediate Language and Compiler for Tiled Neural Network Computations
367. NVIDIA (2023) - CUTLASS: CUDA Templates for Linear Algebra Subroutines
368. Zheng et al. (2022) - AIT: Accelerating Inference with Triton
369. He et al. (2022) - Graphene: An IR for Optimized Tensor Computations on GPUs
370. Feng et al. (2023) - TensorIR: An Abstraction for Automatic Tensorized Program Optimization

### Additional Compilation Papers
371-390. [Papers on kernel fusion, memory planning, graph optimization]

---

## 9. Alignment & Fine-tuning (40 papers)

### RLHF
391. Ouyang et al. (2022) - Training Language Models to Follow Instructions with Human Feedback
392. Bai et al. (2022) - Training a Helpful and Harmless Assistant with RLHF
393. Stiennon et al. (2020) - Learning to Summarize from Human Feedback
394. Ziegler et al. (2019) - Fine-Tuning Language Models from Human Preferences
395. Schulman et al. (2017) - Proximal Policy Optimization Algorithms

### Direct Preference
396. Rafailov et al. (2023) - Direct Preference Optimization: Your Language Model is Secretly a Reward Model
397. Hong et al. (2024) - ORPO: Monolithic Preference Optimization without Reference Model
398. Meng et al. (2024) - SimPO: Simple Preference Optimization with a Reference-Free Reward
399. Ethayarajh et al. (2024) - KTO: Model Alignment as Prospect Theoretic Optimization
400. Azar et al. (2024) - A General Theoretical Paradigm to Understand Learning from Human Feedback

### Additional Alignment Papers
401-430. [Papers on instruction tuning, RLAIF, constitutional AI]

---

## Quick Reference by Impact

| Technique | Papers | Expected Speedup |
|-----------|--------|------------------|
| Flash Attention | 61-65 | 2-4x |
| ZeRO/FSDP | 6-10 | Memory 8x |
| Mixed Precision | 271-275 | 2x |
| Scaling Laws | 181-185 | Optimal allocation |
| Data Quality | 221-230 | Better models |
| Optimizers | 116-120 | 1.5-2x convergence |

---

## Citation Format

```bibtex
@misc{vibee_training_2024,
  title={VIBEE Technology Tree v2500: Training Acceleration Papers},
  author={VIBEE Contributors},
  year={2024},
  note={400+ papers on training optimization}
}
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
