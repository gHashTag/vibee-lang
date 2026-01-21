# Scientific Papers - v2000 Complete Reference

**φ² + 1/φ² = 3 | PHOENIX = 999**

## 1. DATA QUALITY & PREPROCESSING (40 papers)

### Deduplication & Filtering
1. **Lee et al. (2022)** - "Deduplicating Training Data Makes Language Models Better" - NeurIPS
2. **Penedo et al. (2023)** - "The RefinedWeb Dataset for Falcon LLM" - NeurIPS
3. **Penedo et al. (2024)** - "The FineWeb Datasets: Decanting the Web for the Finest Text Data" - arXiv
4. **Li et al. (2024)** - "DataComp-LM: In Search of the Next Generation of Training Sets" - DCLM
5. **Soldaini et al. (2024)** - "Dolma: An Open Corpus of Three Trillion Tokens" - AI2
6. **Wenzek et al. (2020)** - "CCNet: Extracting High Quality Monolingual Datasets" - LREC
7. **Laurençon et al. (2024)** - "The BigScience ROOTS Corpus" - NeurIPS
8. **Together (2023)** - "RedPajama: An Open Dataset for Training Large Language Models"
9. **Cerebras (2023)** - "SlimPajama: A 627B Token Cleaned and Deduplicated Version"
10. **Azerbayev et al. (2023)** - "Llemma: An Open Language Model for Mathematics" - ProofPile

### Code Data
11. **Lozhkov et al. (2024)** - "StarCoder 2 and The Stack v2" - arXiv
12. **Li et al. (2023)** - "StarCoder: May the Source Be with You!" - arXiv
13. **Kocetkov et al. (2022)** - "The Stack: 3 TB of Permissively Licensed Source Code"

### Synthetic Data
14. **Ben Allal et al. (2024)** - "Cosmopedia: Creating Large-Scale Synthetic Textbooks"
15. **Gunasekar et al. (2023)** - "Textbooks Are All You Need" - Phi-1
16. **Li et al. (2023)** - "Textbooks Are All You Need II: phi-1.5"
17. **Abdin et al. (2024)** - "Phi-3 Technical Report"

### Quality Classification
18. **Xie et al. (2023)** - "Data Selection for Language Models via Importance Resampling"
19. **Wettig et al. (2024)** - "QuRating: Selecting High-Quality Data for Training"
20. **Marion et al. (2023)** - "When Less is More: Investigating Data Pruning"

## 2. INSTRUCTION DATA (25 papers)

### Instruction Generation
21. **Wang et al. (2022)** - "Self-Instruct: Aligning LMs with Self-Generated Instructions"
22. **Xu et al. (2023)** - "WizardLM: Empowering LLMs to Follow Complex Instructions"
23. **Xu et al. (2024)** - "Magpie: Alignment Data Synthesis from Scratch"
24. **Mukherjee et al. (2023)** - "Orca: Progressive Learning from Complex Explanation Traces"
25. **Mitra et al. (2024)** - "Orca 2: Teaching Small Language Models How to Reason"

### Conversation Data
26. **Ding et al. (2023)** - "Enhancing Chat Language Models by Scaling High-quality Data"
27. **Wang et al. (2023)** - "OpenChat: Advancing Open-source Language Models"
28. **Daniele & Suber (2023)** - "Amplify-Instruct: Synthetically Generated Diverse Data"

### Curated Mixtures
29. **Ivison et al. (2023)** - "Camels in a Changing Climate: Enhancing LM Adaptation" - Tulu
30. **Ivison et al. (2024)** - "Unpacking DPO and PPO: Disentangling Best Practices" - Tulu 2
31. **Teknium (2023)** - "OpenHermes 2.5: An Open Dataset of Synthetic Data"
32. **Daniele (2023)** - "Capybara: A Large Language Model for Multi-Turn Conversation"

### Tool Use
33. **Patil et al. (2023)** - "Gorilla: Large Language Model Connected with APIs"
34. **Qin et al. (2023)** - "ToolLLM: Facilitating LLMs to Master 16000+ APIs"
35. **Liu et al. (2023)** - "AgentBench: Evaluating LLMs as Agents"

## 3. TRAINING FRAMEWORKS (30 papers)

### Distributed Training
36. **Shoeybi et al. (2019)** - "Megatron-LM: Training Multi-Billion Parameter Models"
37. **Narayanan et al. (2021)** - "Efficient Large-Scale Language Model Training"
38. **Korthikanti et al. (2023)** - "Reducing Activation Recomputation in Large Transformers"
39. **Rajbhandari et al. (2020)** - "ZeRO: Memory Optimizations Toward Trillion Parameters"
40. **Zhao et al. (2023)** - "PyTorch FSDP: Experiences on Scaling Fully Sharded Data Parallel"

### Efficient Training
41. **Dao et al. (2022)** - "FlashAttention: Fast and Memory-Efficient Exact Attention"
42. **Dao (2023)** - "FlashAttention-2: Faster Attention with Better Parallelism"
43. **Shah et al. (2024)** - "FlashAttention-3: Fast and Accurate Attention"
44. **Liu et al. (2023)** - "Ring Attention with Blockwise Transformers for Near-Infinite Context"
45. **Brandon et al. (2023)** - "Striped Attention: Faster Ring Attention for Causal Transformers"

### Fine-tuning
46. **Hu et al. (2021)** - "LoRA: Low-Rank Adaptation of Large Language Models"
47. **Dettmers et al. (2023)** - "QLoRA: Efficient Finetuning of Quantized LLMs"
48. **Hayou et al. (2024)** - "LoRA+: Efficient Low Rank Adaptation of Large Models"
49. **Liu et al. (2024)** - "DoRA: Weight-Decomposed Low-Rank Adaptation"
50. **Meng et al. (2024)** - "PiSSA: Principal Singular Values and Singular Vectors Adaptation"
51. **Lialin et al. (2023)** - "ReLoRA: High-Rank Training Through Low-Rank Updates"
52. **Kopiczko et al. (2024)** - "VeRA: Vector-based Random Matrix Adaptation"
53. **Zhang et al. (2023)** - "AdaLoRA: Adaptive Budget Allocation for PEFT"
54. **Chen et al. (2023)** - "LongLoRA: Efficient Fine-tuning of Long-Context LLMs"
55. **Zhao et al. (2024)** - "GaLore: Memory-Efficient LLM Training by Gradient Low-Rank"
56. **Pan et al. (2024)** - "LISA: Layerwise Importance Sampling for Memory-Efficient LLM"

## 4. MIXTURE OF EXPERTS (15 papers)

57. **Fedus et al. (2022)** - "Switch Transformers: Scaling to Trillion Parameter Models"
58. **Lepikhin et al. (2020)** - "GShard: Scaling Giant Models with Conditional Computation"
59. **Jiang et al. (2024)** - "Mixtral of Experts" - Mistral AI
60. **DBRX Team (2024)** - "DBRX: A New State-of-the-Art Open LLM" - Databricks
61. **xAI (2024)** - "Grok-1: A Large Language Model"
62. **DeepSeek (2024)** - "DeepSeek-V2: A Strong, Economical, and Efficient MoE"
63. **Qwen Team (2024)** - "Qwen2 Technical Report"
64. **Gale et al. (2023)** - "MegaBlocks: Efficient Sparse Training with Mixture-of-Experts"
65. **Muennighoff et al. (2024)** - "OLMoE: Open Mixture-of-Experts Language Models"

## 5. ALIGNMENT (20 papers)

### Preference Optimization
66. **Rafailov et al. (2023)** - "Direct Preference Optimization: Your LM is Secretly a Reward Model"
67. **Azar et al. (2024)** - "A General Theoretical Paradigm to Understand Learning from Human Feedback"
68. **Ethayarajh et al. (2024)** - "KTO: Model Alignment as Prospect Theoretic Optimization"
69. **Hong et al. (2024)** - "ORPO: Monolithic Preference Optimization without Reference Model"
70. **Meng et al. (2024)** - "SimPO: Simple Preference Optimization with a Reference-Free Reward"
71. **Liu et al. (2024)** - "Statistical Rejection Sampling Improves Preference Optimization"

### Self-Improvement
72. **Chen et al. (2024)** - "Self-Play Fine-Tuning Converts Weak LMs to Strong LMs"
73. **Yuan et al. (2024)** - "Self-Rewarding Language Models"
74. **Lee et al. (2023)** - "RLAIF: Scaling Reinforcement Learning from Human Feedback"
75. **Bai et al. (2022)** - "Constitutional AI: Harmlessness from AI Feedback"

## 6. INFERENCE & QUANTIZATION (25 papers)

### Serving
76. **Kwon et al. (2023)** - "Efficient Memory Management for LLM Serving with PagedAttention"
77. **Zheng et al. (2024)** - "SGLang: Efficient Execution of Structured LM Programs"
78. **NVIDIA (2024)** - "TensorRT-LLM: A TensorRT Toolbox for LLMs"

### Quantization
79. **Frantar et al. (2022)** - "GPTQ: Accurate Post-Training Quantization for GPT"
80. **Lin et al. (2023)** - "AWQ: Activation-aware Weight Quantization for LLM"
81. **Dettmers et al. (2022)** - "LLM.int8(): 8-bit Matrix Multiplication for Transformers"
82. **Badri & Shaji (2023)** - "Half-Quadratic Quantization of Large Machine Learning Models"
83. **Egiazarian et al. (2024)** - "Extreme Compression of Large Language Models via Additive Quantization"
84. **Tseng et al. (2024)** - "QuIP#: Even Better LLM Quantization with Hadamard Incoherence"
85. **Kim et al. (2023)** - "SqueezeLLM: Dense-and-Sparse Quantization"

## 7. EVALUATION (30 papers)

### General
86. **Hendrycks et al. (2020)** - "Measuring Massive Multitask Language Understanding" - MMLU
87. **Zellers et al. (2019)** - "HellaSwag: Can a Machine Really Finish Your Sentence?"
88. **Clark et al. (2018)** - "Think you have Solved Question Answering?" - ARC
89. **Sakaguchi et al. (2020)** - "WinoGrande: An Adversarial Winograd Schema Challenge"
90. **Lin et al. (2022)** - "TruthfulQA: Measuring How Models Mimic Human Falsehoods"

### Math
91. **Cobbe et al. (2021)** - "Training Verifiers to Solve Math Word Problems" - GSM8K
92. **Hendrycks et al. (2021)** - "Measuring Mathematical Problem Solving With the MATH Dataset"
93. **Lightman et al. (2023)** - "Let's Verify Step by Step" - PRM800K

### Code
94. **Chen et al. (2021)** - "Evaluating Large Language Models Trained on Code" - HumanEval
95. **Liu et al. (2023)** - "Is Your Code Generated by ChatGPT Really Correct?" - EvalPlus
96. **Jimenez et al. (2024)** - "SWE-bench: Can Language Models Resolve Real-World GitHub Issues?"
97. **Zhuo et al. (2024)** - "BigCodeBench: Benchmarking Code Generation with Diverse Function Calls"

### Instruction Following
98. **Zheng et al. (2023)** - "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena"
99. **Zhou et al. (2023)** - "Instruction-Following Evaluation for Large Language Models" - IFEval
100. **Li et al. (2024)** - "From Crowdsourced Data to High-Quality Benchmarks" - Arena-Hard

### Advanced
101. **Rein et al. (2023)** - "GPQA: A Graduate-Level Google-Proof Q&A Benchmark"
102. **Sprague et al. (2024)** - "MuSR: Testing the Limits of Chain-of-thought with Multistep Soft Reasoning"
103. **White et al. (2024)** - "LiveBench: A Challenging, Contamination-Free LLM Benchmark"

## 8. SCALING LAWS (10 papers)

104. **Kaplan et al. (2020)** - "Scaling Laws for Neural Language Models"
105. **Hoffmann et al. (2022)** - "Training Compute-Optimal Large Language Models" - Chinchilla
106. **Yang et al. (2022)** - "Tensor Programs V: Tuning Large Neural Networks via Zero-Shot Transfer"
107. **Muennighoff et al. (2023)** - "Scaling Data-Constrained Language Models"
108. **Gadre et al. (2024)** - "Language Models Scale Reliably with Over-Training"

## 9. OPTIMIZERS (10 papers)

109. **Loshchilov & Hutter (2017)** - "Decoupled Weight Decay Regularization" - AdamW
110. **Shazeer & Stern (2018)** - "Adafactor: Adaptive Learning Rates with Sublinear Memory"
111. **Chen et al. (2023)** - "Symbolic Discovery of Optimization Algorithms" - Lion
112. **Liu et al. (2023)** - "Sophia: A Scalable Stochastic Second-order Optimizer"
113. **Defazio et al. (2024)** - "The Road Less Scheduled" - Schedule-Free

---

**Total: 113+ key papers implemented in v2000**

**φ² + 1/φ² = 3 | PHOENIX = 999**
