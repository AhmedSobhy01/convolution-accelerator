# Convolution Accelerator

A high-performance hardware accelerator for 2D convolution operations, designed as part of the **CMP3020 – VLSI course**. This project implements a streaming coprocessor architecture that efficiently performs convolution operations under tight on-chip memory constraints.

## 📋 Table of Contents

- [Overview](#overview)
- [Project Features](#project-features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Design Specifications](#design-specifications)
- [Documentation](#documentation)
- [Future Work](#future-work)
- [Team Contributions](#team-contributions)

---

## Overview

This project presents a **Weight Stationary (WS) dataflow** architecture optimized for 2D convolution acceleration. Rather than implementing a straightforward convolution approach, the design evolved through rigorous analysis, failed assumptions, and trade-offs—closely resembling a real hardware development process.

### Key Innovation

The accelerator addresses the challenge of limited on-chip memory by:
- Using kernel folding to decompose large kernels (up to 16×16) into smaller blocks (8×8)
- Accumulating partial results across multiple passes
- Employing a split-kernel approach that distributes computation across multiple phases

### Use Case

The accelerator is designed as a streaming coprocessor that:
- Accepts input image and kernel data from external DRAM
- Performs efficient 2D convolution operations
- Returns output results to DRAM
- Works in tight integration with a host system

---

## Project Features

### 🔧 Core Components

- **8×8 Systolic Array** - Parallel processing element array for MAC operations
- **Dual-Port SRAM Architecture** - Concurrent read/write for efficient data movement
  - SRAM0 (64-bit × 1024): Image and kernel storage
  - SRAM1 (32-bit × 4096): Packed partial output buffer
- **DMA-Based Data Loading** - Efficient data movement from external DRAM
- **Split-Kernel Support** - Handles kernels up to 16×16 on 8×8 array
- **Column-Major Output** - Memory-efficient streaming of results
- **Control Unit FSM** - Orchestrates complex multi-phase kernel execution

### 📊 Performance Metrics

| Metric | Value |
|--------|-------|
| Total Power | 0.444 W |
| Core Area | 17,089,700 µm² |
| Core Utilization | 28.3% |
| Array Dimension | 8×8 |
| Max Kernel Size | 16×16 |
| Supported Image Size | Up to 64×64 |

---

## Architecture

### System Overview

<img width="1536" height="1024" alt="ba5d1150-3803-4dfe-b6b3-72ebcee24833" src="https://github.com/user-attachments/assets/5d9de566-03bc-48ea-b410-e893c03fb245" />


### Data Flow Phases

1. **Load Phase**: DRAM image and kernel loaded into SRAM0 via DMA
2. **Kernel Streaming**: 8×8 kernel blocks streamed to systolic array
3. **Convolution**: SA computes partial contributions for each kernel block
4. **Writeback**: Partial results accumulated in SRAM1 using byte-masked writes
5. **Drain Phase**: Final results summed and streamed back to DRAM

### Split-Kernel Approach

For kernels larger than 8×8:
- **Phase A**: Top-left 8×8 kernel block → partial output
- **Phase B**: Top-right 8×8 kernel block → accumulated
- **Phase C**: Bottom-left 8×8 kernel block → accumulated
- **Phase D**: Bottom-right 8×8 kernel block → accumulated

Final output = sum of all partial contributions

---

## Project Structure

```
convolution-accelerator/
├── rtl/                           # RTL Design Files (Verilog)
│   ├── conv_accelerator_top.v     # Top-level module
│   ├── control_unit/              # FSM-based control unit
│   ├── data-loader-agu/           # Data loader and AGU
│   │   ├── src/                   # Core streaming modules
│   │   ├── Python_scripts/        # Helper scripts for memory generation
│   │   └── designs/               # SRAM design files
│   ├── systolic_array/            # Systolic array implementation
│   │   ├── pe.v                   # Processing element
│   │   └── systolic_array.v       # 8×8 array
│   └── tb/                        # Testbenches
│
├── config/                        # Configuration files
│   ├── config.json                # Design parameters
│   └── macro_placement.cfg        # Placement configuration
│
├── docs/                          # Documentation
│
├── scripts/                       # Testing scripts
│
├── test_cases/                    # Test configurations
│   ├── 01 -> 10
│
├── sim/                           # Simulation scripts
```

---

## Getting Started

### Prerequisites

- **Verilog/SystemVerilog** simulator (ModelSim, VCS, etc.)
- **Python 3.x** (for test generation and verification scripts)
- **Make** or equivalent build tool (optional)

### Running Simulations

#### 1. Simulate Individual Components

**Systolic Array Test:**
```bash
cd rtl/systolic_array
vsim -do ../../sim/systolic_array_sim.do
```

**Processing Element Test:**
```bash
cd rtl/systolic_array
vsim -do ../../sim/pe_sim.do
```

**Control Unit Test:**
```bash
cd rtl/control_unit
vsim -do run_tb.do
```

#### 2. Run Full System Tests

```bash
cd scripts
python3 run_all_tests.py
```

This will:
- Load test configurations from `test_cases/`
- Generate stimulus data
- Run full integration simulations
- Compare outputs with golden references

#### 3. Verify Output

```bash
bash scripts/verify.sh
```

---

## Design Specifications

### Top-Level Module: `conv_accelerator_top`

#### Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `ADDR_W` | 10 | SRAM0 word address width (1024 words) |
| `BYTE_ADDR_W` | 13 | Byte address width (8 KB) |
| `KER_BASE_BYTE` | 4096 | Kernel base address in SRAM0 |
| `IMG_BASE_BYTE` | 0 | Image base address in SRAM0 |
| `SRAM1_ADDR_W` | 12 | SRAM1 word address width (4096 words) |
| `SA_DIM` | 8 | Systolic array dimension |
| `SA_INPUT_FILL_TIME` | 8 | SA pipeline fill time |

#### Port Interface

```verilog
// Inputs
input clk                    // System clock
input rst_n                  // Active-low reset
input start                  // Start convolution operation
input [6:0] cfg_N           // Image dimension (N×N)
input [4:0] cfg_K           // Kernel dimension (K×K)
input [7:0] rx_data         // Input data from DRAM
input rx_valid              // Input data valid signal
input tx_ready              // Output ready signal

// Outputs
output done                 // Convolution complete
output rx_ready             // Ready to accept input data
output tx_valid             // Output data valid
output [7:0] tx_data        // Output data to DRAM
```

### Memory Architecture

#### SRAM0 (64-bit × 1024 words)
- Stores full input image and kernel weights
- Dual-port for concurrent reads
- Image stored from address 0
- Kernel stored from address 4096 (configurable)

#### SRAM1 (32-bit × 4096 words)
- Stores packed partial outputs
- 4 bytes per pixel (one byte per kernel phase)
- Byte-masked writes enable atomic lane updates
- No read-modify-write cycles required

### Timing Constraints

| Metric | Value |
|--------|-------|
| Worst Setup Slack | -11.6 ns |
| Total Negative Slack | -1113.27 ns |
| Max Operating Frequency | ~20-30 MHz (after timing closure) |

---
## Key Design Decisions

### Weight Stationary Dataflow

The final architecture employs **Weight Stationary (WS)** rather than Output Stationary (OS) because:
- Kernel is reused across the entire input image
- Keeping weights fixed in PEs minimizes redundant weight movement
- Simplifies kernel loading and reduces data communication
- Well-suited for single-kernel, large-input-image scenarios

### Split-Kernel Approach

For kernels larger than 8×8:
- Decompose into 8×8 sub-kernels
- Process sequentially through multiple phases
- Accumulate partial outputs in SRAM1
- Final results obtained by summing all partial contributions

### Dual-Port SRAM Strategy

- **SRAM0 (64-bit)**: Optimized for unaligned window reads and kernel loading
- **SRAM1 (32-bit)**: Packed output format with byte-lane isolation
- Enables pipelined data movement without pipeline stalls

## Documentation

For detailed information, refer to the documentation files:

- **[Comprehensive_Architecture.md](docs/Comprehensive_Architecture.md)** - Complete system architecture and module descriptions
- **[Convolution Accelerator.md](docs/Convolution%20Accelerator.md)** - Project journey, design decisions, and architectural evolution
- **[Memory Organization.md](docs/Memory%20Organization.md)** - SRAM layout, address generation, and memory mapping
- **[Control Unit.md](docs/Control%20Unit.md)** - FSM design and state transitions
- **[Systolic Array Documentation](docs/Systolic%20Array/)** - Detailed PE and array specifications
- **[Metrics.md](docs/Metrics.md)** - PPA (Power, Performance, Area) results
- **[Team_Contributions.md](docs/Team_Contributions.md)** - Team member roles and module ownership

---
## Future Work
The team is currently looking into 2 other implementations that are excpected to improve the performance metrices even more.

1) DiP Architechured systollic arrays\
Referenced from this paper: https://arxiv.org/pdf/2412.09709 \
current work can be found in this branch: [feat/sa-dip](https://github.com/AhmedSobhy01/convolution-accelerator/tree/feat/sa-dip)\
It basically works by eliminating the input/output synchronization FIFOs required by state-of-the-art weight stationary systolic arrays by adopting diagonal input movement and weight permutation.

<img width="972" height="376" alt="image" src="https://github.com/user-attachments/assets/d5592bb5-2dff-4ace-ac4c-eb53c3a64df5" />


2) A slight timinng adjustment on the current 101 implemetation\
Inspired after reading this article: https://telesens.co/2018/07/30/systolic-architectures \
current work progress can be found in this branch: [feat/sa-101-optimized](https://github.com/AhmedSobhy01/convolution-accelerator/tree/feat/sa-101-optimized)

---
## References

This project implements concepts from CNN accelerator literature, including:
- Systolic array design principles
- Dataflow mapping techniques for convolution
- Memory hierarchy optimization for embedded systems

---
## Team Contributions


<table align="center">
<tr>
  <td align = "center"> 
	<a href = "https://github.com/AhmedSobhy01">
	  <img src = "https://github.com/AhmedSobhy01.png" width = 100>
	  <br />
	  <sub> Ahmed Sobhy </sub>
	</a>
  </td>

  <td align = "center"> 
	<a href = "https://github.com/AhmedAmrNabil">
	  <img src = "https://github.com/AhmedAmrNabil.png" width = 100>
	  <br />
	  <sub> AhmedAmrNabil </sub>
	</a>
  </td>
  
  <td align = "center"> 
	<a href = "https://github.com/ahmedfathy0-0">
	  <img src = "https://github.com/ahmedfathy0-0.png" width = 100>
	  <br />
	  <sub> Ahmed Fathy </sub>
	</a>
  </td>

  <td align = "center"> 
	<a href = "https://github.com/ZiadMontaser">
	  <img src = "https://github.com/ZiadMontaser.png" width = 100>
	  <br />
	  <sub> Ziad Montaser</sub>
	</a>
  </td>
</tr>
</table>

<table align="center">
<tr>

  <td align = "center"> 
	<a href = "https://github.com/Tasneemmohammed0">
	  <img src = "https://github.com/Tasneemmohammed0.png" width = 100>
	  <br />
	  <sub> Tasneem Mohamed </sub>
	</a>
  </td>
  
  <td align = "center"> 
	<a href = "https://github.com/habibayman">
	  <img src = "https://github.com/habibayman.png" width = 100>
	  <br />
	  <sub> Habiba Ayman </sub>
	</a>
  </td>
  <td align = "center"> 
	<a href = "https://github.com/tonynagyy">
	  <img src = "https://github.com/tonynagyy.png" width = 100>
	  <br />
	  <sub> Tony Nagy </sub>
	</a>
  </td>

  <td align = "center"> 
	<a href = "https://github.com/HelanaNady">
	  <img src = "https://github.com/HelanaNady.png" width = 100>
	  <br />
	  <sub> Helana Nady</sub>
	</a>
  </td>
</tr>
</table>


