`ifndef AXI_READ_SEQUENCE_SVH
`define AXI_READ_SEQUENCE_SVH

class axi_read_sequence extends axi_base_sequence;
  `uvm_object_utils(axi_read_sequence)

  rand int num_transactions = 10;
  rand bit [31:0] start_addr;
  rand bit [31:0] addr_inc;

  constraint num_txn_constraint {
    num_transactions inside {[1:50]};
  }

  constraint addr_constraint {
    start_addr inside {[32'h0010:32'h03FF]};  // Memory addresses, not registers
    addr_inc inside {[1:16]};
  }

  function new(string name = "axi_read_sequence");
    super.new(name);
  endfunction

  task body();
    axi_transaction txn;
    bit [31:0] current_addr;

    `uvm_info(get_type_name(), $sformatf("Starting read sequence with %0d transactions", num_transactions), UVM_LOW)

    current_addr = start_addr;
    
    for (int i = 0; i < num_transactions; i++) begin
      txn = axi_transaction::type_id::create("txn");
      
      start_item(txn);
      
      assert(txn.randomize() with {
        is_write == 0;
        addr == current_addr;
      });
      
      finish_item(txn);
      
      `uvm_info(get_type_name(), $sformatf("Sent read transaction %0d: %s", i, txn.convert2string()), UVM_MEDIUM)
      
      current_addr = current_addr + addr_inc;
      
      // Small delay between transactions
      #10;
    end
    
    `uvm_info(get_type_name(), "Read sequence completed", UVM_LOW)
  endtask

endclass

`endif
