# 📋 QEC Quick Reference Card

**Для Trinity OS разработчиков**

---

## 🎯 TOP 5 PAPERS ДЛЯ TRINITY OS

| # | Paper | Ключевой результат | Применимость |
|---|-------|-------------------|--------------|
| 1 | **arXiv:2601.10206** | 5-qubit код ОПТИМАЛЕН для open systems | ⭐⭐⭐⭐⭐ |
| 2 | **arXiv:2601.09921** | Neural decoder <1μs на TPU v6e | ⭐⭐⭐⭐⭐ |
| 3 | **arXiv:2601.10461** | Erasure conversion 2x threshold | ⭐⭐⭐⭐ |
| 4 | **arXiv:2512.07737** | AlphaQubit 2 real-time decoding | ⭐⭐⭐⭐ |
| 5 | **arXiv:2601.08824** | LDPC girth-8 breakthrough | ⭐⭐⭐ |

---

## 🔧 5-QUBIT CODE [[5,1,3]] STABILIZERS

```
S₁ = XZZXI
S₂ = IXZZX  
S₃ = XIXZZ
S₄ = ZXIXZ
```

**Logical operators:**
```
X_L = XXXXX
Z_L = ZZZZZ
```

---

## 📊 THRESHOLD COMPARISON

| Code | Threshold | Qubits | Best For |
|------|-----------|--------|----------|
| 5-qubit | ~1% | 5 | Open systems, thermal noise |
| Surface | ~1% | O(d²) | Large-scale, 2D connectivity |
| XZZX | ~0.5% | O(d²) | Biased noise |
| Steane | ~0.1% | 7 | Transversal gates |
| LDPC | ~4% | Variable | High rate, low overhead |

---

## ⚡ DECODER LATENCY TARGETS

| Decoder | Latency | Distance | Hardware |
|---------|---------|----------|----------|
| Neural (SOTA) | <1μs | d≤25 | TPU v6e |
| AlphaQubit 2 | <1μs | d≤11 | Commercial |
| Union-Find | ~10μs | d≤21 | FPGA |
| MWPM | ~100μs | d≤15 | CPU |

---

## 🚀 TRINITY OS IMPLEMENTATION CHECKLIST

- [ ] Implement real stabilizer measurements
- [ ] Add syndrome extraction circuit
- [ ] Integrate lookup table decoder
- [ ] Add neural decoder option
- [ ] Implement fidelity monitoring
- [ ] Add temperature-aware scheduling
- [ ] Test with thermal noise model

---

## 📚 FULL REPORT

See: `/docs/research/QEC_RESEARCH_2024_2026.md`

---

**φ² + 1/φ² = 3**
