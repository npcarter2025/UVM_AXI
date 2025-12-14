`ifndef AXI_DRIVER_SVH
`define AXI_DRIVER_SVH

class axi_driver extends uvm_driver#(axi_transaction);
  `uvm_component_utils(axi_driver)

  virtual axi_if.tb vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if.tb)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
    end
  endfunction

  task run_phase(uvm_phase phase);
    axi_transaction txn;

    // Wait for reset to be released
    wait(vif.rst_n);
    #10;

    // Initialize interface signals
    vif.write_addr <= 0;
    vif.write_data <= 0;
    vif.write_valid <= 0;
    vif.read_addr <= 0;
    vif.read_valid <= 0;

    forever begin
      seq_item_port.get_next_item(txn);
      
      `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", txn.convert2string()), UVM_MEDIUM)

      if (txn.is_write) begin
        drive_write_transaction(txn);
      end else begin
        drive_read_transaction(txn);
      end

      seq_item_port.item_done();
    end
  endtask

  task drive_write_transaction(axi_transaction txn);
    @(posedge vif.clk);
    
    // Wait until FIFO is not full (for memory writes)
    // Register writes can bypass FIFO
    if (txn.addr >= 32'h0010) begin  // Memory address
      wait(!vif.fifo_full);
    end
    
    // Drive write signals
    vif.write_addr <= txn.addr;
    vif.write_data <= txn.data;
    vif.write_valid <= 1'b1;
    
    @(posedge vif.clk);
    
    // Wait for ready
    while (!vif.write_ready) begin
      @(posedge vif.clk);
    end
    
    // Deassert valid
    vif.write_valid <= 1'b0;
    
    `uvm_info(get_type_name(), "Write transaction completed", UVM_HIGH)
    
    // Wait a few cycles for transaction to complete
    repeat(2) @(posedge vif.clk);
  endtask

  task drive_read_transaction(axi_transaction txn);
    @(posedge vif.clk);
    
    // Drive read address and valid
    vif.read_addr <= txn.addr;
    vif.read_valid <= 1'b1;
    
    @(posedge vif.clk);
    
    // Wait for ready
    while (!vif.read_ready) begin
      @(posedge vif.clk);
    end
    
    // Deassert valid
    vif.read_valid <= 1'b0;
    
    // Wait for 2-cycle delay to get read data
    repeat(3) @(posedge vif.clk);
    
    // Capture read data and store in transaction
    txn.data = vif.read_data;
    
    `uvm_info(get_type_name(), $sformatf("Read transaction completed, data=0x%08h", txn.data), UVM_HIGH)
  endtask

endclass

`endif
