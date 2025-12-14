class axi_reg_block extends uvm_reg_block;
	`uvm_object_utils(axi_reg_block)
	
	MEM_SIZE_REG MEM_SIZE_REG_INST;
	FIFO_STATUS_REG FIFO_STATUS_REG_INST;
	WRITE_COUNT_REG WRITE_COUNT_REG_INST;
	READ_COUNT_REG READ_COUNT_REG_INST;

	uvm_reg_map axi_reg_map;

	function new (name="axi_reg_block");
		super.new(name);
	endfunction

	virtual function void build();
		MEM_SIZE_REG_INST = MEM_SIZE_REG::type_id::create("MEM_SIZE_REG_INST");
		MEM_SIZE_REG_INST.configure(this);
		MEM_SIZE_REG_INST.build();

		FIFO_STATUS_REG_INST = FIFO_STATUS_REG::type_id::create("FIFO_STATUS_REG_INST");
		FIFO_STATUS_REG_INST.configure(this);
		FIFO_STATUS_REG_INST.build();
		
		WRITE_COUNT_REG_INST = WRITE_COUNT_REG::type_id::create("WRITE_COUNT_REG_INST");
		WRITE_COUNT_REG_INST.configure(this);
		WRITE_COUNT_REG_INST.build();
	
		READ_COUNT_REG_INST = READ_COUNT_REG::type_id::create("READ_COUNT_REG_INST");
		READ_COUNT_REG_INST.configure(this);
		READ_COUNT_REG_INST.build();

		axi_reg_map = create_map(.name("AXI_REG_MAP"),
					 .base_addr('h0),
					 .n_bytes(4),
					 .endian(UVM_LITTLE_ENDIAN));

		axi_reg_map.add_reg(.rg(MEM_SIZE_REG_INST), .offset(8'h0000), .rights("RW"));
		axi_reg_map.add_reg(.rg(FIFO_STATUS_REG_INST), .offset(8'h0004), .rights("RO"));
		axi_reg_map.add_reg(.rg(WRITE_COUNT_REG_INST), .offset(8'h0008), .rights("RO"));
		axi_reg_map.add_reg(.rg(READ_COUNT_REG_INST), .offset(8'h000C), .rights("RO"));
		`uvm_info("RAL", "Reg block build complete. Locking the RAL model now!", UVM_LOW);
		lock_model();
	endfunction

endclass
