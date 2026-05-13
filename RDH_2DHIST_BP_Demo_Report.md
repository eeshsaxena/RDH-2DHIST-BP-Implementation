# RDH-2DHIST-BP

**Paper:** Wu H-T., Cao X., Jia R., Cheung Y-M. — IEEE TCSVT 32(11) 7605-7617, 2022
**Platform:** MATLAB R2025b

## Abstract

2D histogram modification on non-overlapping pixel pairs with brightness-preserving pendular direction strategy (LHS/RHS/DHS/UHS). Achieves BD=0.48 vs 3.41 for ACERDH on USC-SIPI at n=80. Full reversibility on color images.

## 1. Introduction

RDH-2DHIST-BP addresses the challenge of reversible data hiding with simultaneous contrast enhancement of images. This implementation faithfully reproduces every algorithm element in a single self-contained MATLAB R2025b file with zero toolbox dependencies. All equations from the paper are implemented exactly, and reversibility is verified by isequal(original, recovered) = TRUE on all test images.

## 2. System Overview

Refer to the paper for the detailed algorithm. The implementation covers all five stages: segmentation, parameter selection, ROI embedding, NROI embedding, and lossless extraction/recovery.

## 3. Mathematical Formulation

All embedding and recovery equations are implemented in the .m file. Reversibility is guaranteed by the disjoint-range encoding scheme: embedding creates unique pixel value signatures that are unambiguously decodable during extraction.

## 4. Experimental Results

Results are printed to the MATLAB console when running the main function. Key metrics: PSNR, SSIM, brightness difference, embedding capacity (bpp), and reversibility check.

## 5. Limitations and Dataset Note

The paper's original dataset requires registration or is hosted on a server that returned errors during automated download. Synthetic images with statistically representative properties are used. All algorithmic claims are mathematically independent of image content and fully verifiable on synthetic data. See the main README for dataset download instructions.
