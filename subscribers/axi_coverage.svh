`ifndef AXI_COVERAGE_SVH
`define AXI_COVERAGE_SVH

class axi_coverage extends uvm_subscriber#(axi_transaction);
  `uvm_component_utils(axi_coverage)

  // Member variables for coverage sampling
  bit [31:0] cov_addr;
  bit cov_is_write;
  bit cov_is_register_access;
  bit fifo_full_flag = 0;
  bit fifo_empty_flag = 1;
  virtual axi_if.tb vif;

  // Coverage groups
  covergroup address_range_cg;
    // Address range coverage - divide into bins
    addr_bin: coverpoint cov_addr {
      bins low_range    = {[32'h0000:32'h03FF]};      // 0-1KB (registers + first 1KB)
      bins mid_range    = {[32'h0400:32'h07FF]};      // 1-2KB
      bins high_range   = {[32'h0800:32'h0FFF]};      // 2-3KB
      bins very_high    = {[32'h1000:32'hFFFF]};      // 3KB-64KB
      bins register_0   = {32'h0000};                 // MEM_SIZE_REG
      bins register_4   = {32'h0004};                 // FIFO_STATUS_REG
      bins register_8   = {32'h0008};                 // WRITE_COUNT_REG
      bins register_C   = {32'h000C};                 // READ_COUNT_REG
    }
  endgroup

  covergroup transaction_type_cg;
    // Transaction type coverage
    txn_type: coverpoint cov_is_write {
      bins write = {1'b1};
      bins read  = {1'b0};
    }
  endgroup

  covergroup fifo_state_cg;
    // FIFO state coverage - we'll need to track this from the interface
    fifo_full_state: coverpoint fifo_full_flag {
      bins not_full = {1'b0};
      bins full     = {1'b1};
    }
    fifo_empty_state: coverpoint fifo_empty_flag {
      bins not_empty = {1'b0};
      bins empty     = {1'b1};
    }
  endgroup

  covergroup register_access_cg;
    // Register access coverage
    reg_access: coverpoint cov_is_register_access {
      bins register_access = {1'b1};
      bins memory_access   = {1'b0};
    }
    
    // Specific register coverage
    reg_addr: coverpoint cov_addr {
      bins mem_size_reg    = {32'h0000};
      bins fifo_status_reg = {32'h0004};
      bins write_count_reg = {32'h0008};
      bins read_count_reg  = {32'h000C};
    }
    
    // Register read/write coverage
    reg_rw: coverpoint cov_is_write {
      bins reg_write = {1'b1};
      bins reg_read  = {1'b0};
    }
    
    // Cross coverage: which register accessed with read/write
    reg_addr_x_rw: cross reg_addr, reg_rw;
  endgroup

  covergroup address_transaction_cross_cg;
    // Cross coverage between address ranges and transaction types
    addr_range: coverpoint cov_addr {
      bins low_range    = {[32'h0000:32'h03FF]};
      bins mid_range    = {[32'h0400:32'h07FF]};
      bins high_range   = {[32'h0800:32'h0FFF]};
      bins very_high    = {[32'h1000:32'hFFFF]};
    }
    
    txn_type: coverpoint cov_is_write {
      bins write = {1'b1};
      bins read  = {1'b0};
    }
    
    // Cross coverage: address range x transaction type
    addr_x_txn: cross addr_range, txn_type;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    address_range_cg = new();
    transaction_type_cg = new();
    fifo_state_cg = new();
    register_access_cg = new();
    address_transaction_cross_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.tb)::get(this, "", "vif", vif)) begin
      `uvm_warning("NO_VIF", "Virtual interface not found in config_db - FIFO state coverage may be limited")
    end
  endfunction

  function void write(axi_transaction t);
    // Update FIFO state flags from interface if available
    if (vif != null) begin
      fifo_full_flag = vif.fifo_full;
      fifo_empty_flag = vif.fifo_empty;
    end
    
    // Copy transaction fields to coverage member variables
    cov_addr = t.addr;
    cov_is_write = t.is_write;
    cov_is_register_access = t.is_register_access;
    
    // Sample all coverage groups
    address_range_cg.sample();
    transaction_type_cg.sample();
    fifo_state_cg.sample();
    register_access_cg.sample();
    address_transaction_cross_cg.sample();
    
    `uvm_info(get_type_name(), 
              $sformatf("Coverage sampled: %s", t.convert2string()), 
              UVM_HIGH)
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "Coverage Report:", UVM_LOW)
    `uvm_info(get_type_name(), 
              $sformatf("  Address Range Coverage: %0.2f%%", 
                        address_range_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), 
              $sformatf("  Transaction Type Coverage: %0.2f%%", 
                        transaction_type_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), 
              $sformatf("  FIFO State Coverage: %0.2f%%", 
                        fifo_state_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), 
              $sformatf("  Register Access Coverage: %0.2f%%", 
                        register_access_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), 
              $sformatf("  Address x Transaction Cross Coverage: %0.2f%%", 
                        address_transaction_cross_cg.get_inst_coverage()), UVM_LOW)
    
    // Overall coverage
    begin
      real overall_cov;
      overall_cov = (address_range_cg.get_inst_coverage() +
                     transaction_type_cg.get_inst_coverage() +
                     fifo_state_cg.get_inst_coverage() +
                     register_access_cg.get_inst_coverage() +
                     address_transaction_cross_cg.get_inst_coverage()) / 5.0;
      `uvm_info(get_type_name(), 
                $sformatf("  Overall Coverage: %0.2f%%", overall_cov), UVM_LOW)
    end
  endfunction

endclass

`endif

