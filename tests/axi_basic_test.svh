`ifndef AXI_BASIC_TEST_SVH
`define AXI_BASIC_TEST_SVH

class axi_basic_test extends uvm_test;
  `uvm_component_utils(axi_basic_test)

  axi_env env;
  axi_simple_sequence seq;

  function new(string name = "axi_basic_test", uvm_component parent = null);
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
    
    `uvm_info(get_type_name(), "Starting basic functional test", UVM_LOW)
    
    seq = axi_simple_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);
    
    #1000;  // Wait for transactions to complete
    
    phase.drop_objection(this);
  endtask

endclass

`endif
