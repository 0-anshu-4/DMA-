# Configurable Multi-Channel DMA Controller

## Overview

This project implements a configurable multi-channel Direct Memory Access (DMA) Controller in SystemVerilog. The DMA allows data transfer between memory locations without continuous CPU intervention. It is designed around an AXI4-Lite interface for configuration and an AXI4 Master interface for memory transactions.

The project is being developed from scratch as a learning-oriented RTL design and verification project with modular architecture and independent verification for each hardware block.

---

## Features

* 4 Independent DMA Channels
* AXI4-Lite Configuration Interface
* AXI4 Memory Interface
* Channel Register File
* Per-Channel DMA Finite State Machines (FSM)
* Round-Robin Arbiter
* Shared AXI4 Master
* Channel Multiplexer for AXI Master Selection
* AXI Memory Model for Simulation
* Modular RTL Design
* Independent Module Verification Testbenches

---

## Architecture

```
                   CPU
                    │
                    ▼
            AXI4-Lite Slave
                    │
                    ▼
              Register File
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
      FSM0        FSM1        FSM2 ... FSM3
        │           │           │
        └───────────┼───────────┘
                    ▼
          Round Robin Arbiter
                    │
                    ▼
              Channel MUX
                    │
                    ▼
              AXI4 Master
                    │
                    ▼
               AXI Memory
```

---

## Project Structure

```
DMA Controller/

├── rtl/
│   ├── dma_top.sv
│   ├── reg_file.sv
│   ├── ch_fsm.sv
│   ├── arbiter.sv
│   ├── channel_mux.sv
│   ├── axi4_master.sv
│   ├── axi4_lite_slave.sv
│   └── axi_mem_model.sv
│
├── interfaces/
│   ├── axi_if.sv
│   └── axil_if.sv
│
├── testbenches/
│   ├── tb_reg_file.sv
│   ├── tb_axi4_master.sv
│   ├── tb_axi4_lite_slave.sv
│   ├── tb_arbiter.sv
│   └── ...
│
└── README.md
```

---

## Modules

### Register File

Stores source address, destination address, transfer length, control and status registers for all DMA channels.

### AXI4-Lite Slave

Receives CPU read/write requests and converts them into register file accesses.

### Channel FSM

Controls the transfer sequence for each DMA channel.

### Round Robin Arbiter

Selects one requesting DMA channel at a time to access the shared AXI Master.

### Channel MUX

Routes the granted channel's transfer information to the AXI Master.

### AXI4 Master

Performs memory read and write transactions through the AXI4 interface.

### AXI Memory Model

Simulation memory used for functional verification.

---

## Verification

Individual testbenches have been developed for:

* Register File
* Round Robin Arbiter
* AXI4 Master
* AXI4-Lite Slave
* Partial DMA Integration

Current verification includes:

* Register read/write verification
* AXI4-Lite read and write transactions
* Multi-word memory transfers
* Round-robin arbitration
* AXI Master memory copy operation

---

## Current Status

### Completed

* RTL architecture
* Register File
* Channel FSM
* Arbiter
* AXI4 Master
* AXI4-Lite Slave
* Channel Multiplexer
* AXI Memory Model
* Individual module verification

### In Progress

* Full DMA top-level integration
* Multi-channel shared AXI Master operation
* End-to-end DMA transfer verification
* UVM-based verification environment

---

## Tools Used

* SystemVerilog
* Cadence Xcelium
* EDA Playground
* Visual Studio Code
* Git
* GitHub

---

## Future Work

* Complete multi-channel DMA operation
* Burst transfer support
* Interrupt generation
* Error handling
* UVM Verification Environment
* Functional Coverage
* Assertion-Based Verification
* FPGA Implementation
* Synthesis using OpenLane

---


## Mistake Log – Shared AXI Master Completion Signal

### Issue

After introducing a shared AXI Master through a channel multiplexer, I connected the request path (`fsm_src_addr`, `fsm_dst_addr`, `fsm_length`, `fsm_start`) from the granted channel to the AXI Master but overlooked the completion (`done`) return path.

### Root Cause

Originally, the AXI Master was connected only to Channel 0:

```systemverilog
.done(fsm_done[0])
```

After adding the channel multiplexer, any of the four channel FSMs could initiate a transfer, but the AXI Master's `done` signal was no longer routed back to the correct FSM.

As a result, a channel could successfully complete the memory transfer, but its FSM would remain in the `WAIT_DONE` state because `fsm_done` was never asserted.

### Solution

Added logic in `dma_top` to decode the granted channel and route the AXI Master's `done` signal back to the corresponding `fsm_done[i]`.

This ensures that only the FSM owning the current transfer receives the completion signal and transitions from `WAIT_DONE` to `COMPLETE`.

### Lesson Learned

When multiple modules share a hardware resource, both the **request path** and the **response/completion path** must be correctly routed. Designing only the forward data path is not sufficient—the return/control path is equally important for correct system behavior.

## Author

Anshu

ECE | RTL Design & Verification | VLSI Enthusiast
