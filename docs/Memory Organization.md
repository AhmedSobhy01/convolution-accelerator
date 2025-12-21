## Memory Organization

### SRAM0 – Image and Kernel Storage

SRAM0 stores the full input image and full kernel weights.

- DRAM provides **32 bits (4 bytes) per cycle**
- The Data Loader packs and writes data sequentially into SRAM0
  Memory layout:
- Image base address: `SRAM0_BASE_IMG = 0`
- Kernel base address: `SRAM0_BASE_KER = 4096`
  SRAM0 may use a 64-bit (8-byte) macro width to simplify sliding-window reads. This choice is independent of SRAM1, which is fixed at 32 bits to support packed partial outputs.

### SRAM1 – Packed Partial Output Buffer

SRAM1 is a **32-bit wide memory** used to store partial convolution results.
Each output pixel `p` maps to one 32-bit word:

```
SRAM1[p] = {partial3, partial2, partial1, partial0}
```

where each `partiali` is an 8-bit result from sub-kernel pass `idx = i`.

#### Byte-Lane Mapping

| Sub-kernel index (`idx`) | Byte Lane    | Write Mask |
| ------------------------ | ------------ | ---------- |
| 0                        | Lane 0 (LSB) | `4'b0001`  |
| 1                        | Lane 1       | `4'b0010`  |
| 2                        | Lane 2       | `4'b0100`  |
| 3                        | Lane 3 (MSB) | `4'b1000`  |

This mapping enables independent byte writes using SRAM write masks, avoiding read-modify-write operations

---

## Address Generation Unit (AGU)

The AGU generates all addresses required for convolution.
AGU responsibilities:

- Map 2D coordinates to linear SRAM addresses
- Generate kernel addresses for each `LOAD_KERNEL_IDX(idx)`
- Generate sliding-window image addresses for `LOAD_COL(col)`
- Produce the linear output pixel index `p` for SRAM1
- Signal loop termination (`done_col`, `done_kernel`)
  This separation allows the Data Loader to remain mostly streaming, while CU remains a clean scheduler.

---

## Data Loader (DL)

The Data Loader implements all data movement between DRAM, SRAM0, SRAM1, and the SA, using valid/ready flow control where applicable.

#### DL responsibilities:

##### DRAM → SRAM0

- `IMAGE_LOAD(N)`: load an `N×N` image sequentially
- `KERNEL_LOAD(K)`: load a `K×K` kernel sequentially
- Pack 32-bit DRAM beats into the SRAM word format
- Handle tail writes using write masks if needed

##### SRAM0 → SA

- `LOAD_KERNEL_IDX(idx)`: stream one 8×8 kernel quadrant, row-by-row
- `LOAD_COL(col)`: stream the vertical image window for a given column
- Handle word-boundary crossings using dual-read + concatenation

##### SA → SRAM1

- Write partial outputs only when `data_valid = 1`
- Use byte-masked writes to place each partial into the correct lane

##### Drain Mode

- Read packed partials from SRAM1
- Sum four bytes per pixel
- Stream final 8-bit outputs to DRAM with valid/ready backpressure

---

### Drain Phase

After all columns and sub-kernel passes complete:

1. Read each 32-bit word from SRAM1
2. Extract four 8-bit partials
3. Compute: `sum = b0 + b1 + b2 + b3`
4. Truncate or saturate to 8-bit
5. Stream result to DRAM using `tx_valid / tx_ready`
   This guarantees correct accumulation and supports backpressure.

---

| Command             | Parameters | Description                                                                                                                                                                 | Memory Access                                                                                   | Completion Signal     |
| ------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | --------------------- |
| **IMAGE_LOAD**      | `N`        | Loads an `N × N` input image from DRAM into SRAM0 starting at byte address `0`.                                                                                             | Sequential DRAM reads and sequential SRAM0 writes.                                              | `image_done`          |
| **KERNEL_LOAD**     | `K`        | Loads a `K × K` convolution kernel from DRAM into SRAM0 starting at byte address `4096`.                                                                                    | Sequential DRAM reads; SRAM0 writes use byte masking for non-aligned tail data.                 | `kernel_done`         |
| **LOAD_KERNEL_IDX** | `idx`      | Streams kernel weights into the SA. For `K ≤ 8`, only `idx = 0` is used. For `K > 8`, `idx ∈ {0,1,2,3}` selects one 8×8 kernel quadrant.                                    | SRAM0 reads; one kernel row streamed to SA per cycle (8 cycles total).                          | `kernel_stream_done`  |
| **LOAD_COL**        | `col`      | Streams the sliding image window corresponding to output column `col`. `col` ranges from `0` to `N − K`. AGU adjusts row bounds to align partial outputs for split kernels. | SRAM0 reads with non-linear addressing; SA outputs written to SRAM1 only when `data_valid = 1`. | `done_col` (from AGU) |
