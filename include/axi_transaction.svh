`ifndef AXI_TRANSACTION_SVH
`define AXI_TRANSACTION_SVH

class axi_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_transaction)

  // Transaction type: 0=READ, 1=WRITE
  rand bit is_write;
  
  // Address and data
  rand bit [31:0] addr;
  rand bit [31:0] data;
  
  // Expected data for reads (used by scoreboard)
  bit [31:0] expected_data;
  
  // Status fields
  bit is_register_access;  // Set to 1 for register accesses
  bit transaction_complete;
  
  // Constraints for randomization
  constraint addr_constraint {
    // Allow all addresses, including registers and memory
    addr inside {[32'h0000:32'hFFFF]};
  }
  
  constraint data_constraint {
    // Only constrain data for writes
    if (is_write) {
      data inside {[32'h0000_0000:32'hFFFF_FFFF]};
    }
  }
  
  constraint write_dist {
    is_write dist {1 := 50, 0 := 50};  // 50% writes, 50% reads
  }

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    string txn_type = (is_write) ? "WRITE" : "READ";
    if (is_write) begin
      return $sformatf("AXI %s: Addr=0x%08h, Data=0x%08h", txn_type, addr, data);
    end else begin
      return $sformatf("AXI %s: Addr=0x%08h, Expected_Data=0x%08h", txn_type, addr, expected_data);
    end
  endfunction

  function void do_copy(uvm_object rhs);
    axi_transaction txn;
    if (!$cast(txn, rhs)) begin
      `uvm_error("DO_COPY", "Cast failed")
      return;
    end
    super.do_copy(rhs);
    is_write = txn.is_write;
    addr = txn.addr;
    data = txn.data;
    expected_data = txn.expected_data;
    is_register_access = txn.is_register_access;
    transaction_complete = txn.transaction_complete;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_transaction txn;
    if (!$cast(txn, rhs)) begin
      `uvm_error("DO_COMPARE", "Cast failed")
      return 0;
    end
    return (is_write == txn.is_write) &&
           (addr == txn.addr) &&
           (data == txn.data);
  endfunction

  function void post_randomize();
    // Determine if this is a register access
    is_register_access = (addr == 32'h0000) ||  // MEM_SIZE_REG
                         (addr == 32'h0004) ||  // FIFO_STATUS_REG
                         (addr == 32'h0008) ||  // WRITE_COUNT_REG
                         (addr == 32'h000C);    // READ_COUNT_REG
    
    if (!is_write) begin
      // For reads, we'll need to set expected_data later
      expected_data = 32'h0;
    end
  endfunction

endclass

`endif
