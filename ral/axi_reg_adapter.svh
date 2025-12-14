class axi_reg_adapter extends uvm_reg_adapter;
	`uvm_object_utils(axi_reg_adapter);

	axi_write_transaction axi_wr_txn;
	axi_read_transaction axi_rd_txn;
	static int read_cycle_count = 1;
	static bit [7:0] read_addr_local;

	function new (string name="axi_reg_adapter");
		super.new(name);
		supports_byte_enable=0;
		provides_responses=1;
	endfunction
	
	virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
		axi_wr_txn = axi_write_transaction::type_id::create("axi_wr_txn");
		axi_rd_txn = axi_read_transaction::type_id::create("axi_rd_txn");
		if(rw.kind == UVM_WRITE) begin
			axi_wr_txn.write_data = rw.data;
			axi_wr_txn.write_addr = rw.addr;
			return axi_wr_txn;
		end else begin
			axi_rd_txn.read_addr = rw.addr;
			return axi_rd_txn;
		end
	endfunction

	virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
		axi_transaction axi_txn;

		if(!$cast(axi_txn, bus_item)) begin
			`uvm_fatal(get_type_name(), "Casing failed in axi_adapter");
		end
		if (rw.kind == UVM_WRITE) begin
			rw.addr = axi_txn.write_addr;
			rw.data = axi_txn.write_data;
			rw.status = UVM_IS_OK;
		end
		if (rw.kind == UVM_READ) begin
			rw.data = axi_txn.read_data;
			rw.addr = axi_txn.read_addr;
			rw.status = UVM_IS_OK;
		end

				
	endfunction

endclass
