# Physical Implementation (RTL-to-GDS)

This document describes how the convolution accelerator is taken from RTL to a
manufacturable GDSII layout: the toolchain, the configuration, the signoff
results, and the non-obvious issues that had to be solved to get a clean run.

## 1. Toolchain

| Component | Version / detail |
|-----------|------------------|
| Flow      | OpenLane 2 (`2.3.10`), Classic flow |
| PDK       | SkyWater sky130A (via `volare`) |
| Std cells | `sky130_fd_sc_hd` (high density) |
| Synthesis | Yosys |
| P&R / STA | OpenROAD |
| DRC / XOR | KLayout (`sky130A_mr` deck) and Magic |
| LVS       | Netgen |
| Macros    | 2 custom OpenRAM SRAMs (see below) |

The flow reads `config/config.json` and runs on the OpenLane 2 binary (see
"Running the flow" below). To check progress, watch `config/runs/<tag>/`.

## 2. Floorplan and macros

The accelerator instantiates 20 hardened SRAM macros (dual-port, 1RW/1R,
OpenRAM-generated):

| Macro | Size | Count | Role |
|-------|------|-------|------|
| `sky130_sram_2kbyte_1rw1r_32x512_8` | 683.1 x 416.5 µm | 4  | SRAM0 (image/kernel), 64-bit banked |
| `sky130_sram_1kbyte_1rw1r_32x256_8` | 479.8 x 397.5 µm | 16 | SRAM1 (packed partial outputs), 32-bit banked |

- Die area: 6000 x 3000 µm (`18,000,000 µm²`)
- Core area: 50 to 5950 x 50 to 2950 µm (`17,089,700 µm²`)
- Macros are placed in columns (`config/macro_placement.cfg`) with routing
  channels of 200 µm or more, so the design is macro-dominated and std-cell-sparse.
- The SRAM macro views (GDS, LEF, LIB, blackbox netlist) live under
  `rtl/data-loader-agu/Python_scripts/macro_files/` and are wired in via the
  `MACROS` block in `config/config.json`.

## 3. Key configuration decisions

All settings are in `config/config.json`. The non-default, project-critical ones:

| Key | Value | Why |
|-----|-------|-----|
| `CLOCK_PERIOD` | `80.0` ns | Operating point (12.5 MHz) at which the design closes timing (see section 5). |
| `DIE_AREA` / `CORE_AREA` | `6000x3000` / inset 50 µm | Large enough for the 20 SRAM macros plus logic. |
| `FP_CORE_UTIL` / `PL_TARGET_DENSITY_PCT` | `25` / `30` | Sparse, macro-dominated floorplan. |
| `VERILOG_POWER_DEFINE`, `VERILOG_DEFINES`, `SYNTH_DEFINES` | `USE_POWER_PINS` | Required so the SRAM power ports (`vccd1`/`vssd1`) connect. Without it the macro power floats and the flow halts at `Checker.DisconnectedPins`. |
| `MAGIC_MACRO_STD_CELL_SOURCE` | `PDK` | Lets Magic stream out the SRAMs without a duplicate-subcell collision crash (see section 4.2). |
| `PRIMARY_GDSII_STREAMOUT_TOOL` | `klayout` | KLayout merges the vendor SRAM GDS verbatim, which makes the signoff GDS DRC-clean (see section 4.3). |
| `ERROR_ON_XOR_ERROR` | `false` | The Magic-vs-KLayout XOR difference is a known artifact of the two tools handling the SRAM differently. KLayout is authoritative (see section 4.4). |
| `RUN_ANTENNA_REPAIR`, `RUN_HEURISTIC_DIODE_INSERTION` | `true` | Antenna mitigation (see section 5). |
| `RUN_KLAYOUT_DRC` / `RUN_MAGIC_DRC` | `true` / `false` | KLayout is the signoff DRC engine. |

## 4. Signoff issues solved (and why)

Getting a clean run required fixing several buried, cascading problems. They are
recorded here so they are not re-diagnosed from scratch.

### 4.1 SRAM GDS carried unmapped annotation layers

The OpenRAM SRAM GDS files included mask-prep and boundary layers that the
sky130A Magic techfile does not map: `cfom.maskAdd/Drop` (22/21, 22/22),
`cp1m.maskAdd/Drop` (33/42, 33/43), and `boundary` (235/0). Magic's GDS reader
desynced on them (`Error while reading cell ... Unknown layer/datatype`), which
OpenLane treats as fatal.

Fix: strip exactly those five non-physical layer/datatypes from the SRAM GDS
with KLayout. Drawing layers and the real `prBoundary` (235/4) are preserved.
The originals are kept alongside as `*.gds.orig`.

### 4.2 Magic streamout duplicate-cell collision

In the default blackbox streamout mode, Magic loads the SRAM top cell but pulls
the SRAM subcells in via its search path. Because both SRAMs share the same
`sky130_fd_bd_sram__openram_*` base cells, the second load is renamed `_2`, and
Magic's readonly byte-copy then fails to find those `_2` names, producing 20
fatal `Calma output error`s.

Fix: `MAGIC_MACRO_STD_CELL_SOURCE = "PDK"`. Magic fully reads the cleaned macro
GDS into memory and writes from memory, so there is no fragile byte-copy and no
collision.

### 4.3 PDK-mode Magic mangles the SRAM, causing 2388 DRC errors

The PDK-mode full read-and-rewrite reconstructs the SRAM polygons and perturbs
`npc`/`li`/`met1` spacing, injecting 2388 KLayout DRC violations, all inside SRAM
subcells. The proof: the same SRAM extracted from the Magic GDS reports 946
violations, but extracted from the KLayout GDS (or the original vendor GDS) it
reports 0. The design's own logic and routing are DRC-clean, and OpenROAD
detailed routing reports 0 violations.

Fix: `PRIMARY_GDSII_STREAMOUT_TOOL = "klayout"`. KLayout merges the vendor SRAM
GDS verbatim, so the signoff GDS and DRC use the clean layout. Magic streamout
still runs as a flow step, but its mangled GDS is not used as the primary.

### 4.4 `Checker.XOR` blocked signoff

With KLayout as the primary GDS but Magic still producing its own mangled GDS,
the Magic-vs-KLayout XOR check reports about 9.6 million differences, all in the
SRAM regions. That is a deferred fatal error.

Fix: `ERROR_ON_XOR_ERROR = false`. The difference is fully explained by section 4.3. The
KLayout GDS is authoritative and DRC/LVS-clean, so the XOR check is made
non-fatal. It still runs and reports.

## 5. Signoff results

At the 80 ns (12.5 MHz) operating point, the flow completes all 78 stages
(`Flow complete.`) and writes a full set of signoff views to
`config/runs/<tag>/final/` (GDS, DEF, LEF, LIB, netlists, SDC, SDF, SPEF, SPICE).

| Check | Result |
|-------|--------|
| DRC (KLayout `sky130A_mr`) | 0 violations, pass |
| LVS (Netgen) | 0 errors, pass |
| Setup timing | met, +13.0 ns worst-corner slack |
| Hold timing | met, no violations |
| Antenna | 31 net / 31 pin violations, known and accepted (see below) |
| Magic vs KLayout XOR | about 9.6 M diffs, known SRAM artifact, non-fatal (see section 4.4) |

The clock was tightened from an earlier 150 ns run, which met timing with about
46 ns of unused slack. 80 ns is the fastest clean operating point from
configuration alone. At 70 ns setup still passes but a few small hold violations
appear, so going faster needs RTL pipelining of the systolic-array drain path.

See [Metrics.md](Metrics.md) for the full PPA table.

### Known issue: antenna violations (38, accepted)

After repair, 31 antenna violations remain, almost all marginal `met1` "side
area" violations on logic nets. They are a manufacturing-yield concern, not a
functional defect, and they cannot be closed by configuration:

- OpenLane runs all antenna repair (diode insertion and `repair_antennas`) before
  detailed routing. The router then creates `met1` antennas that no later pass
  repairs.
- Verified dead-ends. Pushing heuristic diode insertion to 51k diodes had no
  effect. `RT_MIN_LAYER=met2` eliminated `met1` antennas but broke pin-access
  routing (`DRT-0155`). Penalizing `met1` capacity over-congested routing and
  broke LVS.

Closing them to zero would require a custom flow with a post-detailed-route diode
insertion and ECO reroute pass. For this target the violations are accepted and
documented.

## 6. Running the flow

Setting up the host (Nix, OpenLane 2, and the sky130 PDK) depends on your
environment. Source the Nix profile
(`. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`) and make sure the
OpenLane 2 `openlane` binary is on your `PATH`.

```bash
# Launch the full RTL-to-GDS flow (run tag "my_run")
openlane config/config.json --run-tag my_run

# Follow the live flow log of a run
tail -f config/runs/my_run/flow.log
```

- Each run writes its output to `config/runs/<tag>/`.
- A run succeeds when `config/runs/<tag>/final/` appears, containing
  `final/gds/conv_accelerator_top.gds`.
- Each completed step writes a numbered `NN-tool-name/` folder under the run
  directory, so `ls config/runs/my_run/` shows how far the flow has progressed.
