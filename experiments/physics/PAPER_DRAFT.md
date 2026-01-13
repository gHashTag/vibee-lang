# A Novel Relation Between the Hubble Constant and Fundamental Particle Masses

**Draft for arXiv submission**

---

## Abstract

We report a numerical relation connecting the Hubble constant H₀ with fundamental constants of particle physics and gravity:

$$\frac{\hbar^2 H_0}{c \cdot G \cdot m_e \cdot m_p^2} \approx \frac{1}{2}$$

This relation predicts H₀ ≈ 70.7 km/s/Mpc, in agreement with observations (70 ± 5 km/s/Mpc) to within 4%. If not coincidental, this suggests a deep connection between cosmological expansion and microphysics. We discuss possible theoretical interpretations and implications for the Hubble tension.

---

## 1. Introduction

The Hubble constant H₀ characterizes the current expansion rate of the Universe. Its value has been measured through various methods:

- **Early Universe (CMB):** H₀ = 67.4 ± 0.5 km/s/Mpc (Planck 2018)
- **Late Universe (SNe Ia):** H₀ = 73.0 ± 1.0 km/s/Mpc (SH0ES 2022)

This ~5σ discrepancy, known as the "Hubble tension," suggests either systematic errors or new physics.

We present a relation that derives H₀ from fundamental constants, yielding a value intermediate between these measurements.

---

## 2. The Relation

### 2.1 Statement

We find numerically that:

$$\frac{\hbar^2 H_0}{c \cdot G \cdot m_e \cdot m_p^2} = 0.480 \pm 0.024$$

where:
- ℏ = 1.054571817 × 10⁻³⁴ J·s (reduced Planck constant)
- c = 299792458 m/s (speed of light)
- G = 6.67430 × 10⁻¹¹ m³/(kg·s²) (gravitational constant)
- mₑ = 9.1093837 × 10⁻³¹ kg (electron mass)
- mₚ = 1.6726219 × 10⁻²⁷ kg (proton mass)
- H₀ = 2.2 × 10⁻¹⁸ s⁻¹ (Hubble constant, ~70 km/s/Mpc)

### 2.2 Dimensional Analysis

The combination has dimensions:

$$[\hbar^2 H_0 / (c \cdot G \cdot m_e \cdot m_p^2)] = \frac{(kg \cdot m^2/s)^2 \cdot (1/s)}{(m/s) \cdot (m^3/(kg \cdot s^2)) \cdot kg \cdot kg^2}$$

$$= \frac{kg^2 \cdot m^4 / s^3}{m^4 \cdot kg^2 / s^3} = 1 \quad \checkmark$$

The expression is dimensionless.

### 2.3 Numerical Verification

```
ℏ² = 1.112 × 10⁻⁶⁸ J²·s²
c·G = 1.999 × 10⁻² m⁴/(kg·s³)
mₑ·mₚ² = 2.549 × 10⁻⁸⁴ kg³

ℏ²H₀/(c·G·mₑ·mₚ²) = (1.112 × 10⁻⁶⁸ × 2.2 × 10⁻¹⁸) / (1.999 × 10⁻² × 2.549 × 10⁻⁸⁴)
                   = 2.446 × 10⁻⁸⁶ / 5.095 × 10⁻⁸⁶
                   = 0.480
```

### 2.4 Prediction

If the relation is exactly 1/2, then:

$$H_0 = \frac{c \cdot G \cdot m_e \cdot m_p^2}{2\hbar^2}$$

This predicts:

$$H_0 = 2.29 \times 10^{-18} \text{ s}^{-1} = 70.7 \text{ km/s/Mpc}$$

---

## 3. Equivalent Forms

The relation can be rewritten as:

$$H_0 = \frac{c}{2} \cdot \frac{G \cdot m_e \cdot m_p^2}{\hbar^2}$$

$$H_0 = \frac{c}{2} \cdot \alpha_G \cdot \frac{m_e}{m_p} \cdot \frac{m_p c}{\hbar}$$

where αG = Gm²ₚ/(ℏc) ≈ 5.9 × 10⁻³⁹ is the gravitational fine structure constant.

This can also be written as:

$$H_0 \cdot t_P = \frac{1}{2} \cdot \frac{m_e}{m_P} \cdot \left(\frac{m_p}{m_P}\right)^2$$

where tₚ is the Planck time and mₚ is the Planck mass.

---

## 4. Discussion

### 4.1 Significance

If this relation is fundamental:

1. **The expansion rate is determined by particle physics.** The Universe could not expand at a different rate given the masses of electrons and protons.

2. **Cosmology and microphysics are unified.** The relation connects quantum mechanics (ℏ), gravity (G), special relativity (c), and particle physics (mₑ, mₚ).

3. **The Hubble tension may have a resolution.** Our predicted value (70.7 km/s/Mpc) lies between early and late Universe measurements.

### 4.2 Possible Interpretations

**Anthropic:** We observe a Universe where this relation holds because only such universes produce observers.

**Fundamental:** There exists an unknown theory that derives this relation from first principles.

**Coincidental:** The 4% agreement may be accidental given the large number of possible combinations.

### 4.3 Related Work

Similar "large number coincidences" were noted by Dirac (1937), Eddington (1931), and others. Our relation differs in:

- Involving H₀ explicitly
- Yielding a simple fraction (1/2)
- Predicting a specific measurable value

---

## 5. Predictions and Tests

### 5.1 Testable Predictions

1. **Improved H₀ measurements** should converge toward 70.7 km/s/Mpc if the relation is exact.

2. **If fundamental constants vary** (e.g., time-varying G), H₀ should vary correspondingly.

3. **The relation should hold at all redshifts** if it reflects a fundamental law.

### 5.2 Falsification

The relation would be falsified if:
- H₀ is definitively measured outside the range 67-74 km/s/Mpc
- A theoretical derivation shows the coefficient should differ from 1/2

---

## 6. Conclusion

We have identified a numerical relation:

$$\frac{\hbar^2 H_0}{c \cdot G \cdot m_e \cdot m_p^2} \approx \frac{1}{2}$$

that connects the Hubble constant to fundamental particle masses with 4% accuracy. Whether this represents a deep physical connection or a numerical coincidence remains to be determined. We encourage theoretical investigation and improved measurements of H₀ to test this relation.

---

## Acknowledgments

This relation was discovered using evolutionary algorithms for systematic exploration of fundamental constant combinations.

---

## References

1. Planck Collaboration (2020). Planck 2018 results. A&A 641, A6.
2. Riess, A. G., et al. (2022). A Comprehensive Measurement of the Local Value of the Hubble Constant. ApJ 934, L7.
3. Dirac, P. A. M. (1937). The Cosmological Constants. Nature 139, 323.
4. Eddington, A. S. (1931). Preliminary Note on the Masses of the Electron, the Proton, and the Universe. PCPS 27, 15.

---

## Appendix: Discovery Method

The relation was found using:

1. **Combinatorial search** over products of fundamental constants
2. **Dimensional analysis** to filter physically meaningful combinations
3. **Fitness function** prioritizing:
   - Dimensionless results
   - Values close to simple fractions
   - Novel (not previously known) combinations
   - Connections between quantum and gravitational physics

The search space included 12 fundamental constants with powers ranging from -4 to +4, yielding ~10⁸ combinations. The relation reported here had the highest fitness score among dimensionless combinations involving H₀.

---

*Submitted to arXiv: [date]*
*Categories: astro-ph.CO, hep-th, gr-qc*
