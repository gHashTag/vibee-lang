# Visual Testing Research - PAS Analysis

## Scientific Basis

### Key Papers Analyzed

| Paper | arXiv | Key Contribution | Applicable Pattern |
|-------|-------|------------------|-------------------|
| Moradi et al. 2024 | 2405.00874 | Graph-based UI change detection with YOLOv5 | D&C, MLS |
| LLMShot 2025 | 2507.10062 | VLM for semantic snapshot classification | MLS |
| VISCA 2025 | 2506.04161 | Hierarchical component abstraction, 92% coverage | D&C, PRE |
| DCGen 2024 | 2406.16386 | Divide-and-conquer screenshot analysis | D&C |
| Digital Fingerprinting 2024 | 2408.14155 | Perceptual hashing survey | HSH, PRE |

## PAS Predictions for VIBEE EYES

### Current State (v1)
- Static JS syntax analysis: O(n)
- Module definition checking: O(m)
- No visual verification

### Predicted Improvements

| Capability | Current | Predicted | Confidence | Timeline |
|------------|---------|-----------|------------|----------|
| Visual Regression | None | pHash-based, 95% accuracy | 90% | Implemented |
| Canvas Verification | None | Automated screenshot diff | 85% | 1 week |
| Semantic Analysis | None | VLM classification | 65% | 2-3 months |
| Component Detection | None | YOLO-based UI parsing | 70% | 3-6 months |

## Implemented Techniques

### 1. Perceptual Hashing (arXiv:2408.14155)

```
Algorithm: Average Hash (aHash) + Difference Hash (dHash)
Complexity: O(w*h) → O(64) after resize
Use case: Fast visual similarity detection
```

**Implementation:**
1. Resize image to 8x8
2. Convert to grayscale
3. Compute average/gradient
4. Generate 64-bit binary hash
5. Compare via Hamming distance

**Thresholds:**
- Distance < 5: Identical
- Distance < 15: Similar (minor changes)
- Distance > 20: Different

### 2. Structural Hashing

```
Algorithm: Code structure fingerprint
Complexity: O(n) single pass
Use case: Detect structural changes vs cosmetic
```

**Extracts:**
- Module definitions
- Function count
- Variable count
- Line count

### 3. Canvas Operation Analysis

```
Algorithm: Pattern matching for canvas API calls
Complexity: O(n) string search
Use case: Verify rendering code exists
```

**Tracked operations:**
- fillRect, strokeRect
- fillText
- beginPath, arc, lineTo
- drawImage

## Future Research Directions

### Phase 2: Browser Integration

Based on arXiv:2405.00874 (Moradi et al.):
- Integrate headless browser for actual rendering
- Capture canvas state as PNG
- Apply pHash to rendered output

### Phase 3: Semantic Analysis

Based on arXiv:2507.10062 (LLMShot):
- Integrate Vision-Language Model
- Classify UI changes semantically:
  - Layout change
  - Color change
  - Text change
  - Animation state
  - New/removed element

### Phase 4: Component Detection

Based on arXiv:2506.04161 (VISCA):
- Train YOLO model on UI components
- Build component hierarchy graph
- Track component-level changes

## Validation Results

### VIBEE EYES v2 Test Results

```
Tests: 9 passed, 0 failed
Duration: 110ms

New capabilities:
- Visual hash baseline: 76d9fdd9f6500ab7
- Structure hash: 8f487dcc781bae1d
- Canvas operations: 274 total
  - fillText: 114
  - arc: 49
  - beginPath: 40
```

## References

1. Moradi, M., et al. (2024). "Artificial intelligence for context-aware visual change detection in software test automation." arXiv:2405.00874

2. Kaynak, E.B., et al. (2025). "LLMShot: Reducing snapshot testing maintenance via LLMs." arXiv:2507.10062

3. Alian, P., et al. (2025). "VISCA: Inferring Component Abstractions for Automated End-to-End Testing." arXiv:2506.04161

4. Wan, Y., et al. (2024). "Automatically Generating UI Code from Screenshot: A Divide-and-Conquer-Based Approach." arXiv:2406.16386

5. Chen, W., et al. (2024). "Digital Fingerprinting on Multimedia: A Survey." arXiv:2408.14155
