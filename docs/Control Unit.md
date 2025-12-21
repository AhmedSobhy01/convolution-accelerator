# Control Unit Implementation

## Overview

The Control Unit orchestrates the 2D convolution operation on a systolic array architecture. data movement between DRAM, SRAM, and the systolic array.

## State Machine

![[Pasted image 20251221044458.png]]

| State               | Description                                         |
| ------------------- | --------------------------------------------------- |
| `IDLE`              | Waiting for start signal                            |
| `CONFIG`            | Configure data loader with N and K parameters       |
| `LOAD_DATA_TO_SRAM` | Load image and kernel from DRAM to SRAM             |
| `LOAD_K_TO_SA`      | Initiate kernel loading to systolic array           |
| `WAIT_LOAD_K_TO_SA` | Wait for kernel loading completion                  |
| `COMPUTE`           | Process convolution by streaming columns through SA |
| `STORE_OUT`         | Write results to DRAM                               |
| `DONE_STATE`        | Signal completion                                   |

## Signal Interface

#### Configuration & Control

| Signal  | Direction | Width | Source → Destination | Active When | Description               |
| ------- | --------- | ----- | -------------------- | ----------- | ------------------------- |
| `start` | IN        | 1     | Top → CU             | IDLE        | Initiate computation      |
| `cfg_N` | IN        | 7     | Top → CU             | CONFIG      | Image dimension           |
| `cfg_K` | IN        | 5     | Top → CU             | CONFIG      | Kernel dimension          |
| `done`  | OUT       | 1     | CU → Top             | DONE_STATE  | Computation complete flag |

#### Data Loader Interface

| Signal                       | Direction | Width | Source → Destination | Active When       | Description                               |
| ---------------------------- | --------- | ----- | -------------------- | ----------------- | ----------------------------------------- |
| `dl_cfg_N`                   | OUT       | 7     | CU → Data Loader     | CONFIG            | Pass N to data loader                     |
| `dl_cfg_K`                   | OUT       | 5     | CU → Data Loader     | CONFIG            | Pass K to data loader                     |
| `start_loading_data_to_sram` | OUT       | 1     | CU → Data Loader     | LOAD_DATA_TO_SRAM | Begin loading image/kernel from DRAM      |
| `done_loading_data_to_sram`  | IN        | 1     | Data Loader → CU     | LOAD_DATA_TO_SRAM | Data loading completed                    |
| `start_pass_dl`              | OUT       | 1     | CU → Data Loader     | LOAD_K_TO_SA      | Pulse to initiate data loader kernel pass |
| `dl_output_data_valid`       | IN        | 1     | Data Loader → CU     | COMPUTE           | Data from loader is valid                 |

### Kernel Loading

| Signal                      | Direction | Width | Source → Destination | Active When       | Description                            |
| --------------------------- | --------- | ----- | -------------------- | ----------------- | -------------------------------------- |
| `load_kernel`               | OUT       | 1     | CU → SA Controller   | LOAD_K_TO_SA      | Command to load kernel to SA           |
| `kernel_index`              | OUT       | 2     | CU → SA Controller   | K > SA_DIM        | Identifies which kernel quadrant (0-3) |
| `done_loading_kernel_to_sa` | IN        | 1     | SA Controller → CU   | WAIT_LOAD_K_TO_SA | Kernel loaded into SA                  |
