# DMA Controller (SystemVerilog)

## Overview

This project implements a multi-channel Direct Memory Access (DMA) Controller in SystemVerilog. The DMA is designed to transfer data between memory locations without continuous CPU intervention. The design follows a modular RTL architecture and includes verification testbenches for individual components and subsystem integration.

---

## Architecture

CPU (AXI4-Lite)
↓
AXI4-Lite Slave
↓
Register File
↓
Channel FSMs (4 Channels)
↓
Round Robin Arbiter
↓
AXI4 Master
↓
Memory

---

## Features

* 4 DMA Channels
* AXI4-Lite Configuration Interface
* Register-Based DMA Programming
* Channel FSM Based Transfer Control
* Round Robin Arbitration
* Modular RTL Design
* Component-Level Verification
* Multi-Channel Integration Testing

---

## Implemented Modules

### RTL

* `axil_if.sv`

  * AXI4-Lite interface definition

* `axi_if.sv`

  * AXI4 memory interface definition

* `axi4_lite_slave.sv`

  * Configuration interface skeleton

* `reg_file.sv`

  * DMA configuration registers
  * Stores source address, destination address, transfer length, enable and start bits
  * Provides busy and done status readback

* `ch_fsm.sv`

  * DMA channel finite state machine
  * Handles request, grant, transfer start and completion flow

* `arbiter.sv`

  * Round Robin Arbiter
  * Fairly schedules requests from multiple DMA channels

* `dma_top.sv`

  * Top-level integration module

* `axi4_master.sv`

  * Under Development

---

## Verification

### Testbenches

* `reg_testbench.sv`

  * Register file verification

* `tb_ch_fsm.sv`

  * FSM verification

* `tb_arbiter.sv`

  * Round Robin arbiter verification

* `dma_partial.sv`

  * Multi-channel integration test
  * Verifies arbitration and FSM interaction

---

## Verification Results

### Register File

Verified:

* Register writes
* Register reads
* Control register functionality
* Busy status readback
* Done status readback

### Channel FSM

Verified:

* IDLE → WAIT_GRANT
* WAIT_GRANT → START_TRANSFER
* START_TRANSFER → WAIT_DONE
* WAIT_DONE → COMPLETE
* COMPLETE → IDLE

### Arbiter

Verified:

* Single-channel requests
* Multi-channel requests
* Fair round-robin grant rotation

### Integration

Verified:

* Multiple channels requesting simultaneously
* Arbitration between competing channels
* Grant propagation to FSMs
* Transfer start signaling

---

## Current Progress

* [x] AXI Interfaces
* [x] Register File
* [x] Channel FSM
* [x] Round Robin Arbiter
* [x] Multi-Channel Integration
* [ ] AXI4 Master
* [ ] Full DMA Data Transfer
* [ ] UVM Verification Environment

---

## Tools Used

* SystemVerilog
* Cadence Xcelium
* EDA Playground
* Git
* GitHub

---

## Future Work

* Complete AXI4 Master implementation
* Support burst transfers
* Integrate complete DMA datapath
* Develop UVM verification environment
* Add functional coverage and assertions

---

## Author

Anshu
Electronics and Communication Engineering (ECE)
Thapar Institute of Engineering and Technology
