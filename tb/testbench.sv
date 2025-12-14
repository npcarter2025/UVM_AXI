`ifndef TB_TOP
`define TB_TOP

import uvm_pkg::*;
import test_pkg::*;
`include "uvm_macros.svh"

module tb_top();
   bit   clk;
   logic rst_n;

   //Instantiate AXI Interface
   axi_if axi_vif(clk, rst_n);

   //Instantiate DUT
   axi_memory axi_memory0 (.axi(axi_vif));

   //Clock generator
   initial clk = 0;
   always #5 clk = ~clk;

   // Reset generation
   initial begin
     rst_n = 0;
     #100;
     rst_n = 1;
     `uvm_info("TB_TOP", "Reset deasserted", UVM_LOW)
   end

   // VCD dump
   initial begin
     $vcdpluson();
   end

   // UVM test execution
   initial begin
      // Set virtual interface in config_db
      uvm_config_db#(virtual axi_if.tb)::set(null, "*", "vif", axi_vif);
      
      // Run test
      run_test();
   end
  
endmodule

`endif
