`ifndef AXI_MONITOR_SVH
`define AXI_MONITOR_SVH

class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)

  uvm_analysis_port#(axi_transaction) ap;
  virtual axi_if.tb vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.tb)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    // Wait for reset to be released
    wait(vif.rst_n);
    #10;
    
    fork
      monitor_write_transactions();
      monitor_read_transactions();
    join
  endtask

  task monitor_write_transactions();
    axi_transaction txn;
    
    forever begin
      @(posedge vif.clk);
      
      if (vif.write_valid && vif.write_ready) begin
        txn = axi_transaction::type_id::create("write_txn", this);
        txn.is_write = 1'b1;
        txn.addr = vif.write_addr;
        txn.data = vif.write_data;
        txn.transaction_complete = 1'b1;
        
        `uvm_info(get_type_name(), $sformatf("Monitored WRITE: %s", txn.convert2string()), UVM_MEDIUM)
        
        ap.write(txn);
      end
    end
  endtask

  task monitor_read_transactions();
    axi_transaction txn;
    bit [31:0] read_addr_pipeline [0:1];
    bit read_valid_pipeline [0:1];
    
    // Initialize pipeline
    read_addr_pipeline[0] = 0;
    read_addr_pipeline[1] = 0;
    read_valid_pipeline[0] = 0;
    read_valid_pipeline[1] = 0;
    
    forever begin
      @(posedge vif.clk);
      
      // Pipeline stage 0: Capture read request
      if (vif.read_valid && vif.read_ready) begin
        read_addr_pipeline[0] = vif.read_addr;
        read_valid_pipeline[0] = 1'b1;
      end else begin
        read_valid_pipeline[0] = 1'b0;
      end
      
      // Pipeline stage 1: Shift
      read_addr_pipeline[1] = read_addr_pipeline[0];
      read_valid_pipeline[1] = read_valid_pipeline[0];
      
      // Pipeline stage 2: Capture read data (after 2-cycle delay)
      if (read_valid_pipeline[1]) begin
        txn = axi_transaction::type_id::create("read_txn", this);
        txn.is_write = 1'b0;
        txn.addr = read_addr_pipeline[1];
        txn.data = vif.read_data;  // Data is available after 2 cycles
        txn.expected_data = vif.read_data;
        txn.transaction_complete = 1'b1;
        
        `uvm_info(get_type_name(), $sformatf("Monitored READ: %s", txn.convert2string()), UVM_MEDIUM)
        
        ap.write(txn);
      end
    end
  endtask

endclass

`endif
