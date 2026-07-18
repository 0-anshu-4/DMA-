# Configurable Multi-Channel DMA Controller
## RTL Design & UVM Verification | SystemVerilog, UVM 1.2, Cadence Xcelium

---

## Overview

A 4-channel configurable DMA Controller designed and verified from scratch in
SystemVerilog. The DMA moves data between memory locations without CPU
intervention, configured via an AXI4-Lite slave interface and executing
transfers over an AXI4 master interface. A round-robin arbiter fairly schedules
access to the shared AXI4 master across all 4 channels.

---

## Architecture

                +----------------+
                |      CPU       |
                +----------------+
                        |
                  AXI4-Lite
                        |
        +--------------------------------+
        |          DMA Controller         |
        |                                |
        |  +--------------------------+  |
        |  |      AXI4-Lite Slave     |  |
        |  +--------------------------+  |
        |               |                |
        |        +--------------+        |
        |        | Register File|        |
        |        +--------------+        |
        |         |  |  |  |             |
        |   +-----+--+--+--+-----+       |
        |   | CH0 | CH1 | CH2 | CH3|      |
        |   | FSM | FSM | FSM | FSM |      |
        |   +-----+--+--+--+-----+       |
        |              |                 |
        |        Round-Robin Arbiter     |
        |              |                 |
        |         Channel MUX            |
        |              |                 |
        |         AXI4 Master            |
        +--------------|-----------------+
                       |
                    AXI4 Bus
                       |
                 +-------------+
                 |   Memory    |
                 +-------------+

---

## Features

- 4 independent DMA channels with parameterizable data/address width
- AXI4-Lite slave interface for CPU configuration (src, dst, length, control)
- AXI4 full master interface for multi-word burst data movement
- Round-robin arbiter with sticky grant — no mid-burst preemption
- Per-channel FSM: IDLE → LOAD → WAIT_GRANT → START_TRANSFER → WAIT_DONE → COMPLETE
- Channel MUX routing granted channel's addresses to shared AXI master
- Done signal correctly demuxed back to the completing channel's FSM

---

## Project Structure

dma_controller/
├── rtl/
│   ├── dma_top.sv
│   ├── reg_file.sv
│   ├── ch_fsm.sv
│   ├── arbiter.sv
│   ├── channel_mux.sv
│   ├── axi4_lite_slave.sv
│   └── axi4_master.sv
├── interfaces/
│   ├── axil_if.sv
│   └── axi_if.sv
├── tb/
│   ├── tb_dma_top.sv
│   └── axi_mem_model.sv
├── uvm/
│   └── tb_uvm_top.sv
└── docs/
└── block_diagram.png

---

## Verification Results

| Test | Transfers | Result | Coverage |
|------|-----------|--------|----------|
| Single channel directed | 1 | PASS | — |
| 2-channel concurrent directed | 2 | PASS | — |
| 4-channel simultaneous directed | 4 | PASS | — |
| UVM random regression | 20 | PASS: 20 FAIL: 0 | 91.7% |

**UVM Environment:**
- Constrained-random stimulus via `dma_seq_item` (src, dst, length, channel)
- Driver performs AXI4-Lite register writes per transaction
- Monitor captures all 4 register writes per channel, reconstructs full transaction
- Scoreboard checks every observed transaction, reports PASS/FAIL per transfer
- Functional coverage: channel selection × transfer length cross coverage, 91.7%
  across 12 bins (4 channels × 3 length buckets)

---

## RTL Bugs Found and Fixed

### Bug 1 — Dead-ended `done` signal

**File:** `dma_top.sv`, `channel_mux.sv`

**Symptom:** Transfers appeared to complete at the AXI master level but channel
FSMs never left the WAIT_DONE state. The system would stall indefinitely after
the first transfer.

**Root cause:** The `axi4_master`'s `done` output was connected to a local
signal `axi_done` in `dma_top`, but that signal was never routed back through
`channel_mux` to the FSMs' `fsm_done` inputs. The `channel_mux` only routed
data in one direction (FSM → AXI master) and had no return path for completion.

**Fix:** Added `axi_done` as an input to `channel_mux` and added a demux
logic block that routes `axi_done` back to `fsm_done[active_ch]` — only the
channel currently holding the grant receives the completion signal.

---

### Bug 2 — Arbiter grant reassigned mid-burst (critical)

**File:** `arbiter.sv`, `ch_fsm.sv`

**Symptom:** With two or more channels started simultaneously, data was
corrupted at destination addresses. Memory contents at dst did not match
expected src data. The bug was non-deterministic — sometimes one channel
would get the other channel's data.

**Root cause:** Two separate issues compounding each other:

1. **`ch_req` deasserted too early:** The channel FSM only held `ch_req`
   high while in `WAIT_GRANT` and `START_TRANSFER` states, then dropped it
   in `WAIT_DONE`. The AXI master takes multiple cycles to complete a
   multi-word transfer. The moment `ch_req` dropped, the arbiter treated
   the channel as no longer needing the bus.

2. **Non-sticky arbiter:** The round-robin arbiter recalculated a fresh
   grant every single clock cycle. With channel 0's `ch_req` dropped
   while the AXI master was still mid-burst for channel 0, and channel 1
   still requesting, the arbiter granted channel 1. The `active_ch`
   tracking then pointed to channel 1, so when the AXI master eventually
   asserted `done`, the completion signal was routed to channel 1 instead
   of channel 0.

**Fix:**
- `ch_fsm.sv`: Held `ch_req = 1` through both `START_TRANSFER` and
  `WAIT_DONE` states. A channel must assert its request for the full
  duration it occupies the shared resource.
- `arbiter.sv`: Made grant sticky — if the currently granted channel is
  still requesting, keep granting it rather than rotating to the next
  requester. Only rotate when the active channel releases its request.

**Verified:** Grant transition log confirms `GRANT` held steady per channel
for the entire burst duration with no mid-burst switching. 4-channel
simultaneous test shows clean rotation 0001→0010→0100→1000.

---

### Bug 3 — `start` pulse not auto-clearing in register file

**File:** `reg_file.sv`

**Symptom:** After a transfer completed, the channel FSM would immediately
restart another transfer without any new CPU write. In simulation, channels
appeared to loop continuously after being started once.

**Root cause:** The CONTROL register's `start` bit was stored in a standard
flip-flop that latched the written value and held it. Once written `1`, it
stayed `1` permanently unless explicitly overwritten. The channel FSM checks
`start` on every clock cycle in IDLE state, so it would re-trigger immediately
after returning to IDLE.

**Fix:** Added auto-clear logic — `start` defaults to `'0` every clock cycle
and is only overridden to `1` on the specific cycle when the CPU writes the
CONTROL register. This makes `start` a 1-cycle pulse rather than a level
signal, matching the expected behavior of a write-only trigger bit.

---

## UVM Challenges and Solutions

### Challenge 1 — UVM library not found (`uvm_macros.svh` missing)

**Problem:** First attempt to run UVM on EDA Playground failed with
`cannot open include file 'uvm_macros.svh'` and `Package uvm_pkg could
not be bound`. All UVM macros (`uvm_component_utils`, `uvm_info`, etc.)
were treated as undefined identifiers, causing cascading parse errors
across every class file.

**Root cause:** UVM was not enabled in EDA Playground's simulator
configuration. Without selecting UVM 1.2 from the dropdown, the simulator
has no knowledge of the UVM package or where the macros header lives.

**Fix:** Selected UVM 1.2 under the "UVM/OVM" dropdown in EDA Playground's
left panel. Also added `-uvmnocdnsextra -uvmhome $UVM_HOME` to compile
options and moved `import uvm_pkg::*` and `` `include "uvm_macros.svh" ``
to the very top of the testbench file, before any class definitions.

**Lesson:** `import uvm_pkg::*` must precede all class declarations.
Any class that extends a UVM base class (`uvm_driver`, `uvm_monitor`, etc.)
needs the package visible at parse time.

---

### Challenge 2 — Reserved keyword collision in covergroup bin names

**Problem:** Compile error `A "Verilog/SystemVerilog" keyword was found
where an identifier was expected` on covergroup bin names. The names
`small` and `medium` were used for length bins.

**Root cause:** `small` and `medium` are reserved keywords in
SystemVerilog. Using them as bin identifiers caused the parser to fail
when it encountered them in the covergroup body.

**Fix:** Renamed bins to non-reserved names: `len_2_4` and `len_5_8`.

**Lesson:** Avoid common English words as identifiers in SystemVerilog —
many are reserved. Prefer descriptive technical names with underscores.

---

### Challenge 3 — Monitor sending X values to scoreboard

**Problem:** Scoreboard received transactions with `src=0xxxxxxxxx
dst=0xxxxxxxxx len=x` — all fields uninitialized despite the driver
clearly sending valid data.

**Root cause:** The monitor only watched for the CONTROL register write
(the transfer trigger at offset 0x0C) but created a brand new empty
`dma_seq_item` and only set `channel_sel`. The `src_addr`, `dst_addr`,
and `length` fields came from the three earlier writes (offsets 0x00,
0x04, 0x08) which the monitor ignored. Since `logic` fields default to X
in SystemVerilog, the scoreboard received incomplete transactions.

**Fix:** Added per-channel capture buffers (`cap_src[4]`, `cap_dst[4]`,
`cap_len[4]`) inside the monitor's `run_phase`. The monitor now watches
every AXI4-Lite write transaction and stores values by channel index using
`addr[5:4]` to decode the channel and `addr[3:0]` to decode the register
offset. Only when a CONTROL write is seen does it create and send the
complete transaction using the previously captured values.

**Lesson:** A monitor must observe the full protocol sequence, not just
the final trigger. In register-based protocols, all prerequisite writes
must be captured before the stimulus transaction can be reconstructed.

---

### Challenge 4 — Functional coverage showing 0.0% despite sampling

**Problem:** Covergroup `dma_cg` consistently reported 0.0% coverage
despite the `write()` function being called 20 times with valid data.
Xcelium printed: `Sampling of covergroup type "dma_coverage::dma_cg" is
not enabled`.

**Root cause:** Xcelium requires explicit coverage instrumentation to be
enabled at compile time. Without the `-coverage all` flag, covergroups
inside dynamically-created UVM objects (classes) are not instrumented
during compilation and calls to `sample()` silently do nothing.

Additionally, the initial covergroup implementation referenced `item`
(a class handle) directly in coverpoint expressions. Since `item` is null
at covergroup construction time, Xcelium could not resolve the coverpoint
variables.

**Fix (two-part):**
1. Added `-coverage all` to EDA Playground's compile options. This
   instructs Xcelium to instrument all covergroups for sampling.
2. Replaced direct `item.field` references in coverpoints with
   class-level `int unsigned` variables (`cov_channel`, `cov_length`)
   that are updated before `dma_cg.sample()` is called. Using `int`
   instead of `logic` ensures Xcelium can track the variables across
   clock boundaries in a coverage context.

**Result:** Coverage immediately jumped from 0.0% to 91.7% on the next
run with no other code changes.

**Lesson:** In Xcelium, coverage collection is opt-in at compile time.
`logic` type variables can cause silent coverage failures inside
dynamically-instantiated UVM objects — prefer `int unsigned` for
covergroup sample variables.

---

### Challenge 5 — `fork/join` missing `done` pulses in 4-channel test

**Problem:** The 4-channel simultaneous test's `fork/join` block hung
indefinitely waiting for `@(posedge dut.done[0])` and
`@(posedge dut.done[1])`. The testbench never printed `ALL 4 CHANNEL
TEST PASSED` and eventually hit the timeout watchdog.

**Root cause:** `done` is a 1-cycle pulse signal asserted for exactly one
clock cycle when a channel FSM transitions through its COMPLETE state.
Because channels 0 and 1 were configured and started first (AXI4-Lite
writes are sequential — each `axil_write` takes multiple clock cycles),
they had already completed their transfers and their `done` pulses had
come and gone by the time all 4 channels were configured and the `fork`
block started executing. The `@(posedge dut.done[0])` edge-sensitive wait
could never trigger on an event that already happened in the past.

**Fix:** Replaced the `fork/join` with a polling loop checking
`dut.busy != 4'b0000 || dut.ch_req != 4'b0000` every clock cycle.
`busy` is a level signal that stays high for the entire duration of a
transfer — polling it is immune to pulse timing. Also restructured the
test to configure all addresses first, then start all channels, so
the gap between first and last channel start is minimized.

**Lesson:** Never use edge-sensitive waits (`@posedge signal`) for
completion detection of signals that may pulse before the waiter is set
up. Use level-sensitive polling or sticky latching flags instead.

---

## Tools

- SystemVerilog / UVM 1.2
- Cadence Xcelium 25.03 via EDA Playground- https://www.edaplayground.com/x/a53r
- Git / GitHub

---

## Author

Anshu
ECE, Thapar Institute of Engineering & Technology
Target: RTL Design / Verification Engineer | VLSI | Semiconductor
