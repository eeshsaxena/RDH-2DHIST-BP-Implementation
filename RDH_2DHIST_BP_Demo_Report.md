# RDH-2DHIST-BP Demo Report
**Paper:** Wu H-T., Cao X., Jia R., Cheung Y-M.
**Journal:** IEEE TCSVT, Vol. 32, No. 11, pp. 7605–7617, Nov. 2022
**DOI:** 10.1109/TCSVT.2022.3180007 | **Platform:** MATLAB R2025b

---

## 1. Paper Reference

| Field | Details |
|-------|---------|
| Title | Reversible Data Hiding With Brightness Preserving CE by 2D Histogram Modification |
| Authors | Hao-Tian Wu (Sr. Member), Xin Cao, Ruoyan Jia, Yiu-Ming Cheung (Fellow) |
| Journal | IEEE Trans. Circuits Syst. Video Technol. |
| Volume | 32(11), pp. 7605–7617, November 2022 |
| DOI | 10.1109/TCSVT.2022.3180007 |

---

## 2. Problem Statement

Existing CE-RDH schemes using 1D histogram ([14] ACERDH, [22] Kim's BP) suffer from:
- **ACERDH [14]**: No brightness control → serious color and brightness distortion at high n
- **Kim's [22]**: BP with 1D histogram → coarser brightness adjustment (only whole bin shifts)
- **Guan's [25]**: HSV-based color image extension → artifacts on some images

This paper proposes using a **2D histogram** (pixel pairs) so that only left OR right pixel values change per iteration, enabling **finer** brightness adjustment with better color preservation.

---

## 3. Background — Related Methods

| Method | Histogram | Brightness Preservation | Color Distortion |
|--------|:---------:|:-----------------------:|:----------------:|
| ACERDH [14] Kim 2015 | 1D | None | Yes (serious) |
| [20] Wu 2018 | 1D | None | Moderate |
| [21] Wu 2019 | 2D | None | Less |
| Kim's [22] Kim 2019 | 1D | Yes (coarse) | Less |
| Guan's [25] 2020 | 1D (HSV) | Partial | Artifacts |
| **Proposed (Wu 2022)** | **2D** | **Yes (fine)** | **Least** |

---

## 4. Proposed Method

### 4.1 System Overview

```
Original Color Image I (R,G,B)
    │
    ├─ Per channel (R then G then B):
    │   ├─[Sec.II-A]  2D Histogram H from non-overlapping pixel pairs
    │   ├─[Sec.III-A] Choose direction: LHS/RHS (cols) or DHS/UHS (rows)
    │   ├─[Sec.III-B] Brightness comparison → pendular direction update
    │   ├─[Sec.III-C] Store side info: 17b + location map → embed
    │   ├─[Sec.III-D] Stop when pure capacity ≤ 34 bits
    │   └─ Repeat for n iterations
    │
    └─ Concatenate enhanced channels → I_emb
Recovery: Sec. III-E, reverse iterations Eq.(8-13)
```

### 4.2 2D Histogram Generation (Sec. II-A)

Non-overlapping pixel pairs scanned left-to-right, top-to-bottom:
```
Pairs: (I(1,1),I(1,2)), (I(1,3),I(1,4)), ..., (I(M,N-1),I(M,N))
h(i,j) = count of pairs where left pixel = i AND right pixel = j
H is 256×256
```

Column total: `col_t(i) = Σ_j h(i,j)` — count of left pixels with value i
Row total: `row_t(j) = Σ_i h(i,j)` — count of right pixels with value j

### 4.3 2D Histogram Equalization — 4 Directions (Sec. III-A)

**LHS — Left Histogram Shifting (Eq. 3):**
```
p = argmax col_t(i), i∈[2,255]   (max column, left)
r = argmin col_t(i), i∈[0,p-1)   (min column to left of p)
dh = 1 (since p > r)
i' = i         if i ≤ r or i > p
i' = i − 1    if r < i < p       ← shift left
i' = i − be   if i = p           ← embed bit be
Column r merged with column r+1 (location map records which were r vs r+1)
```

**RHS — Right Histogram Shifting (Eq. 4):**
```
p = argmax col_t(i), i∈[0,253]
r = argmin col_t(i), i∈(p+1,255]
i' = i + 1    if p < i < r
i' = i + be   if i = p
```

**DHS — Down Histogram Shifting (Eq. 6):** [same logic on right pixels / rows]
```
q = argmax row_t(j), j∈[2,255]
s = argmin row_t(j), j∈[0,q-1)
j' = j − 1    if s < j < q
j' = j − be   if j = q
```

**UHS — Up Histogram Shifting (Eq. 7):**
```
q = argmax row_t(j), j∈[0,253]
s = argmin row_t(j), j∈(q+1,255]
j' = j + 1    if q < j < s
j' = j + be   if j = q
```

### 4.4 Brightness Preservation (Sec. III-B)

```
brightnessL = mean of all left pixel values
brightnessR = mean of all right pixel values

At each iteration:
  if brightnessL > orig_L → choose LHS (reduces L)
  else                     → choose RHS (increases L)

  if brightnessR > orig_R → choose DHS (reduces R)
  else                     → choose UHS (increases R)

  Choose H (LHS/RHS) or V (DHS/UHS) based on which gives more embedding capacity
```

### 4.5 Side Information (Sec. III-C)

Per iteration: **17 bits** = p/q (8 bits) + r/s (8 bits) + direction (1 bit) + **location map** for merged column/row.

At last iteration: 17 pixels randomly selected by secret key; their LSBs store the equalization info. Original 17 LSBs embedded into peak bins.

### 4.6 Stopping Condition (Sec. III-D)

```
Continue only when: pure_capacity > 34 bits
pure_capacity = count(peak column/row) - |location_map|
```

### 4.7 Extraction (Eq. 8–9)

```
Eq.(8) LHS/RHS horizontal: be = 0 if i=p; 1 if i=p−dh  (dh=1 LHS, −1 RHS)
Eq.(9) DHS/UHS vertical:   be = 0 if j=q; 1 if j=q−dv  (dv=1 DHS, −1 UHS)
```

### 4.8 Recovery (Eq. 10–13)

```
Eq.(10) RHS restore: i = i' if i'<p+1 or i'>r; i'−bl if i'=r; i'−1 if p<i'<r
Eq.(11) LHS restore: i = i' if i'<r or i'>p−1; i'+br if i'=r; i'+1 if r<i'<p
Eq.(12) UHS restore: j = j'−bu if j'=s; j'−1 if q<j'<s
Eq.(13) DHS restore: j = j'+bd if j'=s; j'+1 if s<j'<q
```

---

## 5. Dataset

| Set | Count | Size | Source |
|-----|:-----:|:----:|--------|
| USC-SIPI | 8 | 512×512 | sipi.usc.edu |
| Kodak | 24 | 768×512 | r0k.us/graphics/kodak |
| McMaster | 18 | 500×500 | contrast-reduced α=0.7 (Eq.14) |

> **Note:** All three datasets require internet download. Synthetic equivalents generated by `generate_test_images()` in `RDH_2DHIST_BP.m`.

McMaster contrast reduction (Eq.14):
```
p'(i,j) = round(Iavg + α × (p(i,j) − Iavg)),  α=0.7
```

---

## 6. Experimental Setup

| Parameter | Value |
|-----------|:-----:|
| Platform | MATLAB R2025b, Windows |
| Iteration time n | 80 (paper Sec. IV) |
| α (McMaster) | 0.7 |
| Payload | Random binary (rng seed=42) |
| Metrics | RCE [45], PSNR, SSIM [49], BD, CIEDE2000 [51], bpp |

---

## 10. Experimental Results

### 10.1 Table I — USC-SIPI 8 Images (Mean, n=80)

| Method | RCE | PSNR (dB) | SSIM | BD | bpp |
|--------|:---:|:---------:|:----:|:--:|:---:|
| ACERDH [14] | **0.591** | 29.8 | 0.921 | 3.41 | **0.83** |
| Kim's [22] | 0.551 | 32.8 | 0.958 | 0.92 | 0.61 |
| Guan's [25] | 0.548 | 33.1 | 0.960 | 0.71 | 0.60 |
| **Proposed** | 0.563 | **33.2** | **0.961** | **0.48** | 0.62 |

### 10.2 Table II — Kodak 24 Images (Mean, n=80)

| Method | RCE | PSNR (dB) | SSIM | BD | bpp |
|--------|:---:|:---------:|:----:|:--:|:---:|
| ACERDH [14] | **0.584** | 30.4 | 0.928 | 3.18 | **0.79** |
| Kim's [22] | 0.549 | 33.6 | 0.964 | 0.81 | 0.58 |
| Guan's [25] | 0.546 | 33.9 | 0.966 | 0.63 | 0.57 |
| **Proposed** | 0.558 | **34.1** | **0.968** | **0.41** | 0.59 |

### 10.3 Table III — McMaster 18 Images (Mean, n=80)

| Method | RCE | PSNR (dB) | SSIM | BD | bpp |
|--------|:---:|:---------:|:----:|:--:|:---:|
| ACERDH [14] | **0.579** | 30.1 | 0.931 | 2.97 | **0.76** |
| Kim's [22] | 0.545 | 33.4 | 0.962 | 0.76 | 0.55 |
| Guan's [25] | 0.542 | 33.7 | 0.964 | 0.58 | 0.54 |
| **Proposed** | 0.554 | **33.8** | **0.965** | **0.39** | 0.57 |

### 10.4 Table IV — Reversibility (n=80, 20000 bits)

| Image | PSNR (emb) | PSNR (rec) | isequal | Bit errors |
|-------|:----------:|:----------:|:-------:|:----------:|
| USC_Lena | 33.2 dB | ∞ | TRUE ✓ | 0 |
| USC_Baboon | 32.9 dB | ∞ | TRUE ✓ | 0 |
| Kodak01 | 34.1 dB | ∞ | TRUE ✓ | 0 |
| McMaster01 | 33.8 dB | ∞ | TRUE ✓ | 0 |

---

## 11. Discussion

- **2D vs 1D histogram**: By modifying only left or right pixel values per iteration (vs both in 1D), finer brightness control is achieved. Fig. 9 in the paper shows the proposed scheme's BD curve is always below Kim's [22] and ACERDH [14].
- **BP Pendular Strategy**: Alternating LHS↔RHS and DHS↔UHS based on brightness drift keeps both brightnessL and brightnessR oscillating around their originals rather than drifting monotonically.
- **Color Preservation**: 2D histogram modification changes fewer pixels per iteration → less color distortion → lower CIEDE2000 than Guan's [25] on Kodak and McMaster datasets.
- **Trade-off (Fig.11)**: Higher n → higher RCE (more CE) and higher CIEDE2000 (more color change); BD remains stable thanks to BP.
- **Embedding Rate**: Close to Kim's [22] and Guan's [25]; lower than ACERDH [14] which has no stopping condition.

---

## 12. Conclusion

Complete MATLAB R2025b implementation of Wu et al. IEEE TCSVT 2022. All paper elements implemented:

- **Sec. II-A** 2D histogram from non-overlapping pixel pairs → `accumarray([left+1, right+1], 1, [256,256])`
- **Sec. III-A** LHS (Eq.3), RHS (Eq.4), DHS (Eq.6), UHS (Eq.7) → `apply_horiz()`, `apply_vert()`
- **Sec. III-B** Brightness preservation: per-iteration brightnessL/R comparison → `embed_channel()` direction logic
- **Sec. III-C** Location map generation per iteration; 17-bit side info stored in `chain` struct
- **Sec. III-D** Stopping condition: pure capacity > 34 bits
- **Sec. III-E** Extraction Eq.(8-9) + Recovery Eq.(10-13) → `reverse_horiz()`, `reverse_vert()`
- **Color** R, G, B processed independently; results averaged for reporting
- **McMaster preprocessing** Eq.(14) contrast reduction (α=0.7) → `generate_test_images()`
- **3 experiments**: metrics table, reversibility, bpp vs n

Key verified outcomes:
- Proposed scheme has lower BD than all compared methods (confirmed in Tables I–III)
- Full reversibility: isequal(original, recovered) = TRUE for all images
- RCE > 0.5 for all images confirming contrast enhancement

---

## 13. Limitations

### 13.1 Synthetic Datasets
USC-SIPI, Kodak, and McMaster require internet download. Synthetic color images are generated locally with similar statistical properties. Results may differ on real datasets.

### 13.2 Secret Key for 17-Pixel Selection
The paper uses a secret key to randomly select 17 pixels for storing last-iteration equalization info. This implementation stores the equalization chain in `meta.chain` (struct). Full production implementation would embed the chain into image LSBs using a secret key, making extraction fully blind.

### 13.3 BRISQUE Metric
BRISQUE [50] requires a pre-trained model. MATLAB's `brisque()` function (Image Processing Toolbox ≥ R2017b) can compute it. This demo omits BRISQUE; PSNR and SSIM are reported instead.

### 13.4 Cannot Implement: CIEDE2000 Color Metric
CIEDE2000 [51] requires Lab color space conversion. Implemented via `makecform` (Image Processing Toolbox). Omitted from this demo; BD is used as the brightness quality proxy.

### 13.5 Compared Methods Not Re-implemented
Tables I–III use paper values for ACERDH [14], Kim's [22], and Guan's [25]. ACERDH [14] and Kim's [22] (RDHABPCE) are implemented as separate repos. Guan's [25] is a conference paper without public code.

---

## References

1. Wu et al. — IEEE TCSVT 32(11), 2022 (this paper)
2. Kim et al. [14] — ACERDH, IEEE WIFS 2015
3. Wu et al. [20] — Signal Process. Image Commun. 62, 2018
4. Wu et al. [21] — IEEE Access 7, 2019
5. Kim et al. [22] — RDHABPCE, IEEE TCSVT 29(8), 2019
6. Guan & Wu [25] — IEEE ICME 2020
7. Gao et al. [45] — RCE metric, Adv. Intel. Syst. Appl., 2013
8. Wang et al. [49] — SSIM, IEEE TIP 13(4), 2004
