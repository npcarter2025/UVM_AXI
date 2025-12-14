`ifndef AXI_AGENT_SVH
`define AXI_AGENT_SVH

class axi_agent extends uvm_agent;
  `uvm_component_utils(axi_agent)

  axi_driver driver;
  axi_sequencer sequencer;
  axi_monitor monitor;
  
  uvm_analysis_port#(axi_transaction) ap;

  bit is_active = 1;  // 1=active (has driver), 0=passive (monitor only)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    monitor = axi_monitor::type_id::create("monitor", this);
    
    if (is_active) begin
      driver = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitor analysis port to agent analysis port
    monitor.ap.connect(ap);
    
    if (is_active) begin
      // Connect driver to sequencer
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass

`endif
