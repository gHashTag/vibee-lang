# Data Efficiency Guide

**VIBEE v2120-v2129 | Maximizing Data Quality and Throughput**

---

## Overview

Data quality and loading efficiency are often overlooked bottlenecks. This guide covers techniques to improve both.

---

## 1. Data Quality Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│              DATA QUALITY PIPELINE                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Raw Web Data (100TB)                                   │
│         │                                               │
│         ▼                                               │
│  ┌─────────────────┐                                   │
│  │ 1. Deduplication│  Remove exact/near duplicates     │
│  │    (-30-50%)    │  MinHash, SimHash, exact match    │
│  └────────┬────────┘                                   │
│           │                                             │
│           ▼                                             │
│  ┌─────────────────┐                                   │
│  │ 2. Filtering    │  Quality scores, language detect  │
│  │    (-40-60%)    │  Perplexity, classifier scores   │
│  └────────┬────────┘                                   │
│           │                                             │
│           ▼                                             │
│  ┌─────────────────┐                                   │
│  │ 3. Domain Mix   │  Balance domains/sources          │
│  │                 │  Code, books, web, academic       │
│  └────────┬────────┘                                   │
│           │                                             │
│           ▼                                             │
│  ┌─────────────────┐                                   │
│  │ 4. Curriculum   │  Order by difficulty              │
│  │                 │  Easy → Hard progression          │
│  └────────┬────────┘                                   │
│           │                                             │
│           ▼                                             │
│  High-Quality Dataset (5-15TB)                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Deduplication

### Exact Deduplication

```python
import hashlib

def exact_dedup(documents):
    seen = set()
    unique = []
    for doc in documents:
        hash_val = hashlib.md5(doc.encode()).hexdigest()
        if hash_val not in seen:
            seen.add(hash_val)
            unique.append(doc)
    return unique
```

### MinHash (Near-Duplicate)

```python
from datasketch import MinHash, MinHashLSH

def minhash_dedup(documents, threshold=0.8):
    lsh = MinHashLSH(threshold=threshold, num_perm=128)
    unique = []
    
    for i, doc in enumerate(documents):
        mh = MinHash(num_perm=128)
        for word in doc.split():
            mh.update(word.encode())
        
        # Check for duplicates
        result = lsh.query(mh)
        if not result:
            lsh.insert(str(i), mh)
            unique.append(doc)
    
    return unique
```

### Impact

- 30-50% data reduction
- Better model quality (less memorization)
- Faster training (less redundant data)

---

## 3. Quality Filtering

### Perplexity Filtering

```python
def filter_by_perplexity(documents, model, max_ppl=1000):
    """Remove documents with very high perplexity."""
    filtered = []
    for doc in documents:
        ppl = model.perplexity(doc)
        if ppl < max_ppl:
            filtered.append(doc)
    return filtered
```

### Classifier-Based Filtering

```python
# Train classifier on high-quality vs low-quality
def quality_score(document, classifier):
    return classifier.predict_proba([document])[0][1]

def filter_by_quality(documents, classifier, threshold=0.5):
    return [d for d in documents if quality_score(d, classifier) > threshold]
```

### Heuristic Filters

```python
def heuristic_filter(doc):
    # Length filter
    if len(doc) < 100 or len(doc) > 100000:
        return False
    
    # Repetition filter
    words = doc.split()
    if len(set(words)) / len(words) < 0.1:
        return False
    
    # Special character ratio
    special = sum(1 for c in doc if not c.isalnum() and not c.isspace())
    if special / len(doc) > 0.3:
        return False
    
    return True
```

---

## 4. Domain Mixing

### Typical Mix (Llama-style)

```python
domain_weights = {
    "web": 0.67,           # CommonCrawl, C4
    "code": 0.08,          # GitHub, StackOverflow
    "books": 0.05,         # Books3, Gutenberg
    "academic": 0.05,      # ArXiv, PubMed
    "wikipedia": 0.05,     # Wikipedia
    "conversations": 0.05, # Reddit, forums
    "other": 0.05          # News, etc.
}
```

### Dynamic Mixing

```python
def sample_batch(datasets, weights, batch_size):
    """Sample from multiple datasets according to weights."""
    samples = []
    for dataset, weight in zip(datasets, weights):
        n = int(batch_size * weight)
        samples.extend(dataset.sample(n))
    random.shuffle(samples)
    return samples[:batch_size]
```

---

## 5. Curriculum Learning

### Difficulty Metrics

```python
def compute_difficulty(document, model):
    """Estimate document difficulty."""
    # Perplexity-based
    ppl = model.perplexity(document)
    
    # Length-based
    length = len(document.split())
    
    # Vocabulary complexity
    unique_ratio = len(set(document.split())) / len(document.split())
    
    return ppl * (1 + length / 1000) * unique_ratio
```

### Curriculum Schedule

```python
def curriculum_sampler(dataset, step, total_steps):
    """Sample easier documents early, harder later."""
    # Sort by difficulty
    sorted_data = sorted(dataset, key=lambda x: x['difficulty'])
    
    # Progress through curriculum
    progress = step / total_steps
    max_idx = int(len(sorted_data) * (0.5 + 0.5 * progress))
    
    return random.choice(sorted_data[:max_idx])
```

---

## 6. Sequence Packing

### Problem

```
Without packing:
[tokens...][PAD][PAD][PAD]  # Wasted compute
[tokens......][PAD][PAD]
[tokens.][PAD][PAD][PAD][PAD]
```

### Solution

```python
def pack_sequences(sequences, max_length):
    """Pack multiple sequences into one."""
    packed = []
    current = []
    current_len = 0
    
    for seq in sequences:
        if current_len + len(seq) + 1 <= max_length:  # +1 for separator
            current.extend(seq)
            current.append(SEP_TOKEN)
            current_len += len(seq) + 1
        else:
            packed.append(current)
            current = seq + [SEP_TOKEN]
            current_len = len(seq) + 1
    
    return packed
```

### Impact

- 20-30% speedup
- Better GPU utilization
- No wasted compute on padding

---

## 7. Data Loading Optimization

### Prefetching

```python
from torch.utils.data import DataLoader

loader = DataLoader(
    dataset,
    batch_size=32,
    num_workers=8,        # Parallel loading
    prefetch_factor=2,    # Prefetch 2 batches per worker
    pin_memory=True,      # Faster GPU transfer
    persistent_workers=True,  # Keep workers alive
)
```

### Streaming Dataset

```python
from datasets import load_dataset

# Stream from disk/network, don't load all into memory
dataset = load_dataset(
    "path/to/data",
    streaming=True,
    split="train"
)

for batch in dataset.iter(batch_size=32):
    # Process batch
    pass
```

### Memory Mapping

```python
import numpy as np

# Memory-map large files
data = np.memmap("data.bin", dtype=np.int32, mode='r')

# Access without loading entire file
batch = data[start:end]
```

---

## 8. Tokenizer Optimization

### Vocabulary Size

```
Smaller vocab (32K):
+ Faster softmax
+ Less memory
- More tokens per text

Larger vocab (128K):
+ Fewer tokens
+ Better compression
- Slower softmax
- More memory
```

### Byte-Level BPE

```python
from tokenizers import Tokenizer, models, trainers

tokenizer = Tokenizer(models.BPE())
trainer = trainers.BpeTrainer(
    vocab_size=32000,
    min_frequency=2,
    special_tokens=["<pad>", "<unk>", "<s>", "</s>"]
)
tokenizer.train(files, trainer)
```

---

## 9. Best Practices Checklist

- [ ] Deduplicate at document and paragraph level
- [ ] Filter by quality score (perplexity, classifier)
- [ ] Balance domain proportions
- [ ] Use sequence packing
- [ ] Enable prefetching (num_workers > 0)
- [ ] Use memory mapping for large datasets
- [ ] Consider curriculum learning for long training

---

## References

- Lee et al. (2022): Deduplicating Training Data
- Penedo et al. (2024): FineWeb
- Bengio et al. (2009): Curriculum Learning
- Krell et al. (2022): Efficient Sequence Packing

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
