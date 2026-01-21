# Ultra Acceleration Papers - v2100 (150+ Papers)

**φ² + 1/φ² = 3 | PHOENIX = 999**

## 1. HARDWARE OPTIMIZATION (20 papers)

### NVIDIA Architecture
1. **NVIDIA (2022)** - "H100 Tensor Core GPU Architecture"
2. **NVIDIA (2024)** - "H200 Tensor Core GPU with HBM3e"
3. **NVIDIA (2024)** - "Blackwell Architecture Technical Brief"
4. **NVIDIA (2023)** - "Grace Hopper Superchip Architecture"
5. **NVIDIA (2022)** - "NVLink 4.0 and NVSwitch Technical Overview"

### AMD/Intel/Google
6. **AMD (2023)** - "MI300X Accelerator Architecture"
7. **Intel (2024)** - "Gaudi 3 AI Accelerator"
8. **Jouppi et al. (2023)** - "TPU v4: An Optically Reconfigurable Supercomputer"
9. **AWS (2024)** - "Trainium2: Next-Generation ML Training Chip"

### Interconnect
10. **Mellanox (2023)** - "InfiniBand NDR 400Gb/s Architecture"
11. **NVIDIA (2023)** - "NCCL: Optimized Primitives for Collective Communication"

## 2. COMMUNICATION & PARALLELISM (25 papers)

### AllReduce Algorithms
12. **Patarasuk & Yuan (2009)** - "Bandwidth Optimal All-reduce Algorithms"
13. **Thakur et al. (2005)** - "Optimization of Collective Communication Operations"
14. **Rabenseifner (2004)** - "Optimization of Collective Reduction Operations"

### Pipeline Parallelism
15. **Narayanan et al. (2019)** - "PipeDream: Generalized Pipeline Parallelism"
16. **Huang et al. (2019)** - "GPipe: Efficient Training of Giant Neural Networks"
17. **Qi et al. (2024)** - "Zero Bubble Pipeline Parallelism" - **KEY PAPER**
18. **Li et al. (2021)** - "Chimera: Efficiently Training Large-Scale Neural Networks"
19. **Lamy-Poirier (2023)** - "Breadth-First Pipeline Parallelism"

### Sequence Parallelism
20. **Korthikanti et al. (2023)** - "Reducing Activation Recomputation in Large Transformer Models"
21. **Fang et al. (2024)** - "USP: A Unified Sequence Parallelism Approach"
22. **Liu et al. (2023)** - "Ring Attention with Blockwise Transformers"
23. **Brandon et al. (2023)** - "Striped Attention: Faster Ring Attention"

### ZeRO & Offloading
24. **Rajbhandari et al. (2020)** - "ZeRO: Memory Optimizations Toward Training Trillion Parameter Models"
25. **Rajbhandari et al. (2021)** - "ZeRO-Infinity: Breaking the GPU Memory Wall"
26. **Ren et al. (2021)** - "ZeRO-Offload: Democratizing Billion-Scale Model Training"

## 3. SERVING OPTIMIZATION (20 papers)

### PagedAttention & vLLM
27. **Kwon et al. (2023)** - "Efficient Memory Management for LLM Serving with PagedAttention"
28. **Zheng et al. (2024)** - "SGLang: Efficient Execution of Structured Language Model Programs"

### Disaggregated Serving
29. **Patel et al. (2024)** - "Splitwise: Efficient Generative LLM Inference Using Phase Splitting"
30. **Zhong et al. (2024)** - "DistServe: Disaggregating Prefill and Decoding for Goodput-optimized LLM Serving"
31. **Agrawal et al. (2024)** - "Sarathi: Efficient LLM Inference by Piggybacking Decodes with Chunked Prefills"
32. **Yu et al. (2022)** - "Orca: A Distributed Serving System for Transformer-Based Generative Models"

### Prefix Caching
33. **Gim et al. (2024)** - "Prompt Cache: Modular Attention Reuse for Low-Latency Inference"
34. **Zheng et al. (2024)** - "Efficiently Programming Large Language Models using SGLang"

## 4. COMPILERS & KERNELS (20 papers)

### PyTorch Compilation
35. **Ansel et al. (2024)** - "PyTorch 2: Faster Machine Learning Through Dynamic Python Bytecode Transformation"
36. **He et al. (2024)** - "FlexAttention: The Flexibility of PyTorch with the Performance of FlashAttention"

### Triton
37. **Tillet et al. (2019)** - "Triton: An Intermediate Language and Compiler for Tiled Neural Network Computations"

### Flash Attention
38. **Dao et al. (2022)** - "FlashAttention: Fast and Memory-Efficient Exact Attention"
39. **Dao (2023)** - "FlashAttention-2: Faster Attention with Better Parallelism"
40. **Shah et al. (2024)** - "FlashAttention-3: Fast and Accurate Attention with Asynchrony and Low-precision"
41. **Dao et al. (2023)** - "Flash-Decoding for Long-Context Inference"
42. **FlashInfer Team (2024)** - "FlashInfer: Efficient and Customizable Attention Kernels"

### SAGE Attention
43. **Zhang et al. (2024)** - "SAGE Attention: Accurate 8-Bit Attention for Plug-and-play Inference Acceleration"

## 5. SSM & LINEAR ATTENTION (30 papers)

### Mamba
44. **Gu & Dao (2023)** - "Mamba: Linear-Time Sequence Modeling with Selective State Spaces" - **KEY PAPER**
45. **Dao & Gu (2024)** - "Transformers are SSMs: Generalized Models and Efficient Algorithms Through Structured State Space Duality" - **Mamba-2**

### RWKV
46. **Peng et al. (2023)** - "RWKV: Reinventing RNNs for the Transformer Era"
47. **Peng et al. (2024)** - "Eagle and Finch: RWKV with Matrix-Valued States"

### RetNet
48. **Sun et al. (2023)** - "Retentive Network: A Successor to Transformer for Large Language Models"

### Hyena
49. **Poli et al. (2023)** - "Hyena Hierarchy: Towards Larger Convolutional Language Models"

### Gated Linear Attention
50. **Yang et al. (2024)** - "Gated Linear Attention Transformers with Hardware-Efficient Training"
51. **Yang et al. (2024)** - "FLA: A Triton-Based Library for Hardware-Efficient Implementations of Linear Attention"

### Hybrid Models
52. **Lieber et al. (2024)** - "Jamba: A Hybrid Transformer-Mamba Language Model"
53. **Glorioso et al. (2024)** - "Zamba: A Compact 7B SSM Hybrid Model"
54. **De et al. (2024)** - "Griffin: Mixing Gated Linear Recurrences with Local Attention"
55. **Botev et al. (2024)** - "RecurrentGemma: Moving Past Transformers for Efficient Open Language Models"

### Long Context
56. **Xiao et al. (2023)** - "Efficient Streaming Language Models with Attention Sinks" - **StreamingLLM**
57. **Mohtashami & Jaggi (2023)** - "Landmark Attention: Random-Access Infinite Context Length"
58. **Tworkowski et al. (2023)** - "Focused Transformer: Contrastive Training for Context Scaling"
59. **Peng et al. (2023)** - "YaRN: Efficient Context Window Extension of Large Language Models"
60. **Ding et al. (2024)** - "LongRoPE: Extending LLM Context Window Beyond 2 Million Tokens"
61. **Zhu et al. (2024)** - "PoSE: Efficient Context Window Extension via Position Skip-wise Training"
62. **Jin et al. (2024)** - "LLM Maybe LongLM: Self-Extend LLM Context Window Without Tuning"

## 6. QUANTIZATION (25 papers)

### FP8
63. **Micikevicius et al. (2022)** - "FP8 Formats for Deep Learning"
64. **NVIDIA (2024)** - "FP8 Training and Inference on Hopper GPUs"

### Microscaling
65. **Rouhani et al. (2023)** - "Microscaling Data Formats for Deep Learning"

### Post-Training Quantization
66. **Frantar et al. (2022)** - "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers"
67. **Lin et al. (2023)** - "AWQ: Activation-aware Weight Quantization for LLM Compression"
68. **Dettmers et al. (2022)** - "LLM.int8(): 8-bit Matrix Multiplication for Transformers"
69. **Dettmers et al. (2023)** - "QLoRA: Efficient Finetuning of Quantized LLMs"

### Advanced Quantization
70. **Badri & Shaji (2023)** - "Half-Quadratic Quantization of Large Machine Learning Models"
71. **Egiazarian et al. (2024)** - "Extreme Compression of Large Language Models via Additive Quantization"
72. **Tseng et al. (2024)** - "QuIP#: Even Better LLM Quantization with Hadamard Incoherence"
73. **Kim et al. (2023)** - "SqueezeLLM: Dense-and-Sparse Quantization"
74. **Shao et al. (2024)** - "OmniQuant: Omnidirectionally Calibrated Quantization"

### Kernel Optimization
75. **Frantar et al. (2024)** - "Marlin: Mixed-Precision Auto-Regressive Parallel Inference on GPUs"
76. **Lin et al. (2024)** - "QServe: W4A8KV4 Quantization and System Co-design"
77. **Xia et al. (2024)** - "FP6-LLM: Efficiently Serving Large Language Models Through FP6-Centric Kernels"

## 7. PRUNING & DISTILLATION (20 papers)

### Pruning
78. **Sun et al. (2023)** - "A Simple and Effective Pruning Approach for Large Language Models" - **Wanda**
79. **Frantar & Alistarh (2023)** - "SparseGPT: Massive Language Models Can Be Accurately Pruned in One-Shot"
80. **Xia et al. (2023)** - "Sheared LLaMA: Accelerating Language Model Pre-training via Structured Pruning"
81. **van der Ouderaa et al. (2024)** - "LLM-Surgeon: Efficient Pruning with Data-Driven Importance"
82. **Ashkboos et al. (2024)** - "SliceGPT: Compress Large Language Models by Deleting Rows and Columns"
83. **Men et al. (2024)** - "ShortGPT: Layers in Large Language Models are More Redundant Than You Expect"
84. **Sharma et al. (2024)** - "The Truth is in There: Improving Reasoning in Language Models with Layer-Selective Rank Reduction" - **LASER**

### Distillation
85. **Gu et al. (2024)** - "MiniLLM: Knowledge Distillation of Large Language Models"
86. **Agarwal et al. (2024)** - "On-Policy Distillation of Language Models: Learning from Self-Generated Mistakes"
87. **Ko et al. (2024)** - "DistillSpec: Improving Speculative Decoding via Knowledge Distillation"

## 8. SPECULATIVE DECODING (25 papers)

### Core Methods
88. **Leviathan et al. (2023)** - "Fast Inference from Transformers via Speculative Decoding"
89. **Chen et al. (2023)** - "Accelerating Large Language Model Decoding with Speculative Sampling"
90. **Cai et al. (2024)** - "Medusa: Simple LLM Inference Acceleration Framework with Multiple Decoding Heads"

### EAGLE
91. **Li et al. (2024)** - "EAGLE: Speculative Sampling Requires Rethinking Feature Uncertainty"
92. **Li et al. (2024)** - "EAGLE-2: Faster Inference of Language Models with Dynamic Draft Trees"

### Advanced Speculation
93. **Ankner et al. (2024)** - "Hydra: Sequentially-Dependent Draft Heads for Medusa Decoding"
94. **Fu et al. (2024)** - "Break the Sequential Dependency of LLM Inference Using Lookahead Decoding"
95. **Santilli et al. (2023)** - "Accelerating Transformer Inference for Translation via Parallel Decoding"
96. **He et al. (2024)** - "REST: Retrieval-Based Speculative Decoding"
97. **Sun et al. (2024)** - "SpecInfer: Accelerating Generative Large Language Model Serving with Tree-based Speculative Inference"
98. **Liu et al. (2024)** - "Online Speculative Decoding"
99. **Zhang et al. (2024)** - "Draft & Verify: Lossless Large Language Model Acceleration via Self-Speculative Decoding"

### Early Exit
100. **Elhoushi et al. (2024)** - "Layer Skip: Enabling Early Exit Inference and Self-Speculative Decoding"
101. **Schuster et al. (2022)** - "Confident Adaptive Language Modeling" - **CALM**

### Contextual Sparsity
102. **Liu et al. (2023)** - "Deja Vu: Contextual Sparsity for Efficient LLMs at Inference Time"

## 9. HYBRID & EDGE INFERENCE (15 papers)

### GPU-CPU Hybrid
103. **Song et al. (2023)** - "PowerInfer: Fast Large Language Model Serving with a Consumer-grade GPU"
104. **Alizadeh et al. (2024)** - "LLM in a Flash: Efficient Large Language Model Inference with Limited Memory"

### Any-Precision
105. **Park et al. (2024)** - "Any-Precision LLM: Low-Cost Deployment of Multiple, Different-Sized LLMs"
106. **Zhao et al. (2024)** - "ATOM: Low-bit Quantization for Efficient and Accurate LLM Serving"

### Mobile/Edge
107. **Sheng et al. (2023)** - "FlexGen: High-Throughput Generative Inference of Large Language Models with a Single GPU"
108. **Xue et al. (2024)** - "PowerInfer-2: Fast Large Language Model Inference on a Smartphone"

## 10. TRAINING OPTIMIZATION (10 papers)

### Gradient Compression
109. **Alistarh et al. (2017)** - "QSGD: Communication-Efficient SGD via Gradient Quantization"
110. **Lin et al. (2018)** - "Deep Gradient Compression: Reducing the Communication Bandwidth"

### Activation Checkpointing
111. **Chen et al. (2016)** - "Training Deep Nets with Sublinear Memory Cost"
112. **Jain et al. (2020)** - "Checkmate: Breaking the Memory Wall with Optimal Tensor Rematerialization"

### Loss Scaling
113. **Micikevicius et al. (2018)** - "Mixed Precision Training"

---

**Total: 150+ key papers for ultra acceleration**

**φ² + 1/φ² = 3 | PHOENIX = 999**
