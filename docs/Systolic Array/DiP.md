## Motivation
The DiP approach was introduced to address the **scalability, utilization, and synchronization overheads** inherent in conventional weight-stationary systolic arrays.  
As stated in the paper, traditional WS designs rely on **input/output synchronization FIFOs**, which incur **area, power, energy, and latency penalties**, and lead to **low PE utilization due to diagonal wave activation**.

---
## Description
DiP is a **Diagonal-Input, Permutated Weight-Stationary systolic array** for matrix multiplication acceleration.

> “The proposed architecture eliminates the input/output synchronization FIFOs required by state-of-the-art weight stationary systolic arrays by adopting diagonal input movement and weight permutation.”

Weights remain stationary inside the array, while:
- **Inputs propagate diagonally across PE rows**
- **Partial sums accumulate vertically**

A **memory-level permutation of the weight matrix** ensures correct alignment between inputs and weights without requiring FIFOs.

> [!NOTE]
 Adapted from this paper:  https://arxiv.org/pdf/2412.09709

---
## Data Flow
Each PE:
- Receives a **diagonally propagated input**
- Holds a **stationary (permuted) weight**
- Accumulates **partial sums vertically**

At the systolic array level:
- Inputs move diagonally from one PE row to the next
- Boundary PEs are diagonally connected to maintain continuous input flow
- Weights are **pre-permuted** by shifting and rotating each column by its column index
- Partial sums flow vertically and exit naturally without output synchronization

This dataflow **removes the need for input/output FIFOs**, while enabling **early and uniform PE activation** across the array.

<img width="1158" height="548" alt="Pasted image" src="https://github.com/user-attachments/assets/ef703bd8-c83d-44a5-8fa9-c1b22b9e5de5" />


## Constraints on Input
As implied in the implementation description, a preprocessing of shifting and rotating each column of the kernel is needed.
This has added some complexity to the process of delivering data to the SA.

<img width="1536" height="1024" alt="dip" src="https://github.com/user-attachments/assets/92098be1-a430-447a-aa83-be11d353c3ff" />

---
## Performane Matrices
**According to the paper’s analytical model for an N×N array:**
By eliminating synchronization FIFOs:
- Register overhead is reduced
- PE utilization increases significantly
- Throughput and energy efficiency scale better with array size

At 64×64, DiP achieves:
- **1.49×** throughput improvement
- Up to 2.02× energy efficiency per area
---
## References
- DiP: A Scalable, Energy-Efficient Systolic Array for Matrix Multiplication Acceleration
Paper Link: https://arxiv.org/pdf/2412.09709

