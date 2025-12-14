`ifndef TEST_PKG
`define TEST_PKG

package test_pkg;
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    
    // Include all UVM components
    `include "../include/axi_transaction.svh"
    `include "../seq/axi_base_sequence.svh"
    `include "../seq/axi_simple_sequence.svh"
    `include "../seq/axi_write_sequence.svh"
    `include "../seq/axi_read_sequence.svh"
    `include "../seq/axi_random_sequence.svh"
    `include "../seq/axi_corner_sequence.svh"
    `include "../agent/axi_driver.svh"
    `include "../agent/axi_monitor.svh"
    `include "../agent/axi_sequencer.svh"
    `include "../agent/axi_agent.svh"
    `include "../subscribers/axi_scoreboard.svh"
    `include "../subscribers/axi_coverage.svh"
    `include "../env/axi_env.svh"
    `include "axi_basic_test.svh"
    `include "axi_stress_test.svh"
    `include "axi_write_read_test.svh"
    `include "axi_corner_case_test.svh"
    `include "test.sv"
endpackage

`endif