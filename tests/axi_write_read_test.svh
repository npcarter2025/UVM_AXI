`ifndef AXI_WRITE_READ_TEST_SVH
`define AXI_WRITE_READ_TEST_SVH

class axi_write_read_test extends uvm_test;
  `uvm_component_utils(axi_write_read_test)

  axi_env env;
  axi_write_sequence write_seq;
  axi_read_sequence read_seq;

  function new(string name = "axi_write_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    env = axi_env::type_id::create("env", this);
    
    // Virtual interface is set in testbench via config_db
    // Driver and monitor will get it automatically
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    `uvm_info(get_type_name(), "Starting write-then-read test", UVM_LOW)
    
    // First write to memory
    write_seq = axi_write_sequence::type_id::create("write_seq");
    assert(write_seq.randomize() with { num_transactions == 20; });
    write_seq.start(env.agent.sequencer);
    
    #1000;  // Wait for writes to complete
    
    // Then read from same addresses
    read_seq = axi_read_sequence::type_id::create("read_seq");
    read_seq.start_addr = write_seq.start_addr;
    read_seq.addr_inc = write_seq.addr_inc;
    read_seq.num_transactions = write_seq.num_transactions;
    read_seq.start(env.agent.sequencer);
    
    #2000;  // Wait for reads to complete
    
    phase.drop_objection(this);
  endtask

endclass

`endif
