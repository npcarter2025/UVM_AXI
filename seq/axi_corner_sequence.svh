`ifndef AXI_CORNER_SEQUENCE_SVH
`define AXI_CORNER_SEQUENCE_SVH

class axi_corner_sequence extends axi_base_sequence;
  `uvm_object_utils(axi_corner_sequence)

  function new(string name = "axi_corner_sequence");
    super.new(name);
  endfunction

  task body();
    axi_transaction txn;

    `uvm_info(get_type_name(), "Starting corner case sequence", UVM_LOW)
    
    // Corner case 1: FIFO full condition - send many writes
    `uvm_info(get_type_name(), "Testing FIFO full condition", UVM_LOW)
    for (int i = 0; i < 20; i++) begin
      txn = axi_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with { 
        is_write == 1; 
        addr inside {[32'h0010:32'h03FF]}; 
      });
      finish_item(txn);
      #10;
    end
    #500;
    
    // Corner case 2: Invalid address read
    `uvm_info(get_type_name(), "Testing invalid address read", UVM_LOW)
    txn = axi_transaction::type_id::create("txn");
    start_item(txn);
    assert(txn.randomize() with { 
      is_write == 0; 
      addr == 32'hFFFF; 
    });
    finish_item(txn);
    #200;
    
    // Corner case 3: Register boundary test
    `uvm_info(get_type_name(), "Testing register boundaries", UVM_LOW)
    for (int i = 0; i < 4; i++) begin
      txn = axi_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with { 
        is_write == 1; 
        addr == (i * 4); 
        data == 32'hAABB_CCDD; 
      });
      finish_item(txn);
      #50;
    end
    
    #500;
    
    `uvm_info(get_type_name(), "Corner case sequence completed", UVM_LOW)
  endtask

endclass

`endif
