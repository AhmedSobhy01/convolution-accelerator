# PPA and signoff metrics

All numbers below come from the completed OpenLane 2 (sky130A) RTL-to-GDS run at
the 80 ns clock (12.5 MHz) operating point, taken from
`config/runs/<tag>/final/metrics.json`. See
[Physical_Implementation.md](Physical_Implementation.md) for the flow and how
these were produced.

## Signoff status

| Check | Result |
|-------|--------|
| KLayout DRC (`sky130A_mr`) | 0, pass |
| Netgen LVS | 0 errors, pass |
| Setup timing | met, +13.0 ns worst-corner slack |
| Hold timing | met |
| Antenna violations | 31 net / 31 pin, known and accepted |
| Magic vs KLayout XOR | about 9.6 M diffs, known SRAM streamout artifact, non-fatal |

## Power (at 80 ns)

- Total power: 0.0907 W
  - Internal: 0.0333 W
  - Switching: 0.0570 W
  - Leakage: 0.000447 W

## Area and utilization

- Die area: `18,000,000 µm²` (6000 x 3000 µm)
- Core area: `17,089,700 µm²`
- Core utilization (`design__instance__utilization`): 28.3%
- Hardened SRAM macros: 20 (4 of 32x512, 16 of 32x256). The design is
  macro-dominated, so std-cell area is a small fraction of the core.

## Instance composition (post-route)

| Class | Count |
|-------|-------|
| SRAM macros | 20 |
| Logic std cells (from synthesis) | about 35,900 |
| Antenna / diode cells | tens of thousands (heuristic insertion) |
| Tap / decap / fill | remainder |

## Timing

- Clock period: 80 ns (12.5 MHz).
- Worst setup slack at the slow corner (`max_ss_100C_1v60`): +13.0 ns, met.
- Setup and hold both met across all nine corners, no violations.
- The design was tightened from an earlier 150 ns operating point. At 150 ns it
  met timing with about 46 ns of unused slack, so most of that headroom was
  recovered.

## Notes and caveats

- 80 ns is close to the practical floor for config-only optimization. At 70 ns
  setup still passes but a few small hold violations appear, so 80 ns is the
  fastest clean operating point without RTL pipelining of the systolic-array
  drain path.
- Max slew and max cap warnings are reported but are non-fatal advisory checks,
  dominated by long nets and the large diode and fill population. They do not
  block signoff.
- Antenna and XOR are documented known items. See
  [Physical_Implementation.md](Physical_Implementation.md), sections 4 and 5.
