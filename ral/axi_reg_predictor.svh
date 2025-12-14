class axi_reg_predictor extends uvm_reg_predictor#(axi_transaction);
	`uvm_component_utils(axi_reg_predictor)
	uvm_analysis_imp#(axi_transaction, axi_reg_predictor) reg_predictor_imp;
	axi_reg_adapter reg_adapter;
	function new (string name = "axi_reg_predictor", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		reg_predictor_imp = new("reg_predictor_imp", this);
		reg_adapter = axi_reg_adapter::type_id::create("reg_adapter", this);
	endfunction

	function void write(axi_transaction txn);
		uvm_reg_bus_op rw_mon;
		super.write(txn);
		rw_mon.byte_en = -1;
		
      		`uvm_info("RAL", "CAlling bus2reg...", UVM_MEDIUM);
		reg_adapter.bus2reg(txn, rw_mon);
	endfunction
endclass
