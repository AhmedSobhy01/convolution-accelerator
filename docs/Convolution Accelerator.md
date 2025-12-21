# Convolution Accelerator

This project focuses on designing a hardware accelerator for 2D convolution as part of the CMP3020 – VLSI course. The accelerator is built as a **streaming coprocessor** that works alongside a host system to perform convolution efficiently under tight on-chip memory constraints.

### 1. Where We Started

At first glance, convolution looks straightforward: load the image, load the kernel, compute the output, and store the results. However, an early breakdown of memory requirements showed that this naïve approach would require far more on-chip SRAM than available.

Rather than starting from a finalized architecture, the project evolved through analysis, failed assumptions, design trade-offs, and multiple architectural revisions, closely resembling a real hardware development process.

---

### 2. Project Journey

#### 2.1 Initial Feasibility Analysis

The first major step was understanding whether a straightforward convolution implementation could even fit on-chip.
We performed a full memory breakdown:

- Input image (64 × 64): 4096 bytes
- Kernel (16 × 16): 256 bytes
- Output partial sums (49 × 49 × 32-bit): 9604 bytes
  This resulted in a total of ~13.6 KB.

> The challenge is not only the computation, but how partial results are stored and accumulated.

#### 2.2 Mathematical Insight: Partitioning & Accumulation

To address the memory issue, we revisited the mathematical structure of convolution. Using matrix partitioning principles, we realized that:

- Convolution results can be constructed from partial sums
- These partial sums do not need to exist simultaneously
- As long as partial contributions are accumulated correctly, the final result remains valid

This justified splitting kernels into blocks (folding) and accumulating results incrementally instead of storing full outputs.

#### 2.3 Early Architecture Choice: Output Stationary

We reviewed existing CNN accelerator literature and found that most designs favor Output Stationary (OS) dataflow, mainly because:

- Partial sums stay in place
- Moving 32-bit accumulators is expensive
- OS works well with multiple kernels

> [!NOTE]
> Although Output Stationary (OS) was initially discussed during the early research phase, the final implemented architecture uses a Weight Stationary (WS) dataflow.

This decision was made after considering the nature of the workload and the system constraints. Since the accelerator targets a single kernel applied repeatedly across a large input image, keeping weights fixed inside the Processing Elements minimizes redundant weight movement and simplifies kernel reuse.

#### 2.4 Kernel Folding Problem (K > Array Size)

With a 16 × 16 kernel and an 8 × 8 systolic array, kernel folding became unavoidable.
The kernel was divided into four 8 × 8 sub-kernels, processed in multiple phases:

- Phase A: Top-left kernel block
- Phase B: Top-right
- Phase C: Bottom-left
- Phase D: Bottom-right  
  Each phase produces a **partial contribution** to the output.

#### 2.5 Exploration of Alternative Convolution Mappings

During the early stages of the project, the team explored multiple approaches for mapping convolution onto systolic arrays before converging on the final Weight Stationary design.
These explorations included:

- **SA-101 (naive systolic array mapping)**, used as a correctness and intuition baseline
- **SA-101 (optimized)**, where basic improvements were applied to reduce redundant data movement
- **Diagonal Input Permuted (DiP)** mapping, investigated for improved array utilization and scalability

> [!Note]
> A **TRIM-inspired approach** was considered conceptually, but was not implemented, as its complexity did not align with the project timeline and constraints.

---

> **Note:** This document provides an overview of how the project originated, the exploration process we undertook, and the reasoning behind our final implementation decisions. For detailed implementation specifications and design files, please refer to the **docs** folder, which contains further information on each module.
