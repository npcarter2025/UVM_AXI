
class test extends uvm_test;
  `uvm_component_utils(test)
  
  function new (string name = "test",uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
  endfunction
  
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
  
  virtual task main_phase(uvm_phase phase);
    super.main_phase(phase);
    
    phase.raise_objection(this);
    
    #30;
    `uvm_info(get_name(), "In main phase of Test", UVM_LOW);
    
    phase.drop_objection(this);
    
  endtask:main_phase
  
endclass:test
