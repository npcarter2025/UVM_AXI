# Project Deliverables Index

This document provides an index to all project deliverables for my AXI Memory Controller UVM Testbench project.

---

## Deliverable 1: Complete UVM Testbench Source Code

**Location:** All source files in the project directory

**Key Components:**
- **Agent Layer:** `agent/` directory
  - `axi_agent.svh` - Agent container
  - `axi_driver.svh` - Transaction driver
  - `axi_monitor.svh` - Transaction monitor
  - `axi_sequencer.svh` - Sequence item sequencer

- **Environment:** `env/` directory
  - `axi_env.svh` - Testbench environment

- **Transactions:** `include/` directory
  - `axi_transaction.svh` - Base transaction class

- **Sequences:** `seq/` directory
  - `axi_base_sequence.svh` - Base sequence class
  - `axi_simple_sequence.svh` - Simple directed sequence
  - `axi_write_sequence.svh` - Write-only sequence
  - `axi_read_sequence.svh` - Read-only sequence
  - `axi_random_sequence.svh` - Random transaction sequence
  - `axi_corner_sequence.svh` - Corner case sequence

- **Subscribers:** `subscribers/` directory
  - `axi_scoreboard.svh` - Verification scoreboard

- **Tests:** `tests/` directory
  - `test_pkg.sv` - Test package
  - `axi_basic_test.svh` - Basic functional test
  - `axi_stress_test.svh` - Stress test
  - `axi_write_read_test.svh` - Write-read test
  - `axi_corner_case_test.svh` - Corner case test

- **Testbench:** `tb/` directory
  - `testbench.sv` - Top-level testbench module

- **DUT:** `src/` directory
  - `axi_if.sv` - AXI interface
  - `axi_memory.sv` - Device under test
  - `mem_pkg.sv` - Memory package

- **Build System:** `Makefile` - Build and run automation

---

## Deliverable 2: Test Results & Functional Coverage Report

**File:** `Test_Results_and_Coverage_Report.md`

---

## Deliverable 3: Debugging & Optimization Log

**File:** `Debugging_and_Optimization_Log.md`



## Deliverable 4: Summary Report

**File:** `Summary_Report.md`

