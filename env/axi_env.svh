`ifndef AXI_ENV_SVH
`define AXI_ENV_SVH

class axi_env extends uvm_env;
  `uvm_component_utils(axi_env)

  axi_agent agent;
  axi_scoreboard scoreboard;
  axi_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    agent = axi_agent::type_id::create("agent", this);
    scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
    coverage = axi_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect agent analysis port to scoreboard
    agent.ap.connect(scoreboard.analysis_export);
    // Connect agent analysis port to coverage collector
    agent.ap.connect(coverage.analysis_export);
  endfunction

endclass

`endif
