`ifndef AXI_STRESS_TEST_SVH
`define AXI_STRESS_TEST_SVH

class axi_stress_test extends uvm_test;
  `uvm_component_utils(axi_stress_test)

  axi_env env;
  axi_random_sequence seq;

  function new(string name = "axi_stress_test", uvm_component parent = null);
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
    
    `uvm_info(get_type_name(), "Starting randomized stress test", UVM_LOW)
    
    seq = axi_random_sequence::type_id::create("seq");
    assert(seq.randomize() with { num_transactions inside {[50:100]}; });
    seq.start(env.agent.sequencer);
    
    #5000;  // Wait for transactions to complete
    
    phase.drop_objection(this);
  endtask

endclass

`endif
