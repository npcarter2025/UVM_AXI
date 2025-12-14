`ifndef AXI_RANDOM_SEQUENCE_SVH
`define AXI_RANDOM_SEQUENCE_SVH

class axi_random_sequence extends axi_base_sequence;
  `uvm_object_utils(axi_random_sequence)

  rand int num_transactions = 20;
  
  // Control randomization
  rand bit include_registers = 1;
  rand bit include_memory = 1;

  constraint num_txn_constraint {
    num_transactions inside {[10:100]};
  }

  function new(string name = "axi_random_sequence");
    super.new(name);
  endfunction

  task body();
    axi_transaction txn;
    bit [31:0] addr_val;
    bit [1:0] addr_type;

    `uvm_info(get_type_name(), $sformatf("Starting random sequence with %0d transactions", num_transactions), UVM_LOW)

    for (int i = 0; i < num_transactions; i++) begin
      txn = axi_transaction::type_id::create("txn");
      
      start_item(txn);
      
      // Randomize address type (register vs memory)
      addr_type = $urandom_range(0, 3);
      
      if (include_registers && addr_type == 0) begin
        // Access registers (25% probability)
        addr_val = ($urandom_range(0, 3)) * 4;  // 0x0000, 0x0004, 0x0008, 0x000C
      end else if (include_memory) begin
        // Access memory (75% probability)
        addr_val = $urandom_range(32'h0010, 32'h03FF);
      end else begin
        addr_val = $urandom_range(32'h0010, 32'h03FF);
      end
      
      assert(txn.randomize() with {
        addr == addr_val;
        if (is_write) {
          data dist {
            [32'h0000_0000:32'h0000_00FF] := 20,
            [32'hDEAD_BEEF:32'hDEAD_BEEF] := 5,
            [32'h0000_0100:32'hFFFF_FFFF] := 75
          };
        }
      });
      
      finish_item(txn);
      
      `uvm_info(get_type_name(), $sformatf("Sent random transaction %0d: %s", i, txn.convert2string()), UVM_MEDIUM)
      
      // Random delay between transactions
      #($urandom_range(5, 50));
    end
    
    `uvm_info(get_type_name(), "Random sequence completed", UVM_LOW)
  endtask

endclass

`endif
