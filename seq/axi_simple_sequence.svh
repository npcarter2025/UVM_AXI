`ifndef AXI_SIMPLE_SEQUENCE_SVH
`define AXI_SIMPLE_SEQUENCE_SVH

// Simple directed sequence for basic functional testing
class axi_simple_sequence extends axi_base_sequence;
  `uvm_object_utils(axi_simple_sequence)

  function new(string name = "axi_simple_sequence");
    super.new(name);
  endfunction

  task body();
    axi_transaction txn;

    `uvm_info(get_type_name(), "Starting simple directed sequence", UVM_LOW)

    // Test 1: Write to memory location
    txn = axi_transaction::type_id::create("write_txn");
    start_item(txn);
    assert(txn.randomize() with { is_write == 1; addr == 32'h0010; data == 32'h1234_5678; });
    finish_item(txn);
    `uvm_info(get_type_name(), "Write transaction sent", UVM_MEDIUM)
    #500;  // Wait longer for write to go through FIFO and 2-cycle pipeline

    // Test 2: Read from same location
    txn = axi_transaction::type_id::create("read_txn");
    start_item(txn);
    assert(txn.randomize() with { is_write == 0; addr == 32'h0010; });
    txn.expected_data = 32'h1234_5678;
    finish_item(txn);
    `uvm_info(get_type_name(), "Read transaction sent", UVM_MEDIUM)
    #100;

    // Test 3: Write to register
    txn = axi_transaction::type_id::create("reg_write_txn");
    start_item(txn);
    assert(txn.randomize() with { is_write == 1; addr == 32'h0000; data == 32'h0000_0400; });  // MEM_SIZE_REG
    finish_item(txn);
    `uvm_info(get_type_name(), "Register write transaction sent", UVM_MEDIUM)
    #100;

    // Test 4: Read from register
    txn = axi_transaction::type_id::create("reg_read_txn");
    start_item(txn);
    assert(txn.randomize() with { is_write == 0; addr == 32'h0004; });  // FIFO_STATUS_REG
    finish_item(txn);
    `uvm_info(get_type_name(), "Register read transaction sent", UVM_MEDIUM)
    #200;

    `uvm_info(get_type_name(), "Simple sequence completed", UVM_LOW)
  endtask

endclass

`endif
