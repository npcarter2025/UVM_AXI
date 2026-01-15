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
`ifdef VPD_DUMP
     // VPD format (for DVE)
     $vcdpluson(0, tb_top);
     $vcdplusmemon(0, tb_top);
`elsif VCD_DUMP
     // VCD format (for Verdi/GTKWave)
     $dumpfile(`VCD_FILE);
     $dumpvars(0, tb_top);
`elsif FSDB_DUMP
     // FSDB format (for Verdi)
     $fsdbDumpfile(`FSDB_FILE);
     $fsdbDumpvars(0, tb_top);
`endif
   end

   // UVM test execution
   initial begin
      // Set virtual interface in config_db
      uvm_config_db#(virtual axi_if.tb)::set(null, "*", "vif", axi_vif);
      
      // Configure C memory model if USE_DPI_MODEL is defined
`ifdef USE_DPI_MODEL
      uvm_config_db#(bit)::set(null, "*scoreboard*", "use_c_memory_model", 1);
      `uvm_info("TB_TOP", "C memory model enabled via USE_DPI_MODEL", UVM_LOW)
`endif
      
      // Run test
      run_test();
   end
  
endmodule

`endif
