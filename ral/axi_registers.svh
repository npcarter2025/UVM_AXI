class MEM_SIZE_REG extends uvm_reg;

	`uvm_object_utils(MEM_SIZE_REG)

	uvm_reg_field total_memory_size;

	function new(name="MEM_SIZE_REG");
	    super.new(.name(name),.n_bits(32),.has_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
    		total_memory_size=uvm_reg_field::type_id::create("total_memory_size");
    		total_memory_size.configure(.parent(this),
                        .size(32),
                        .lsb_pos(0),
                        .access("RW"),
                        .volatile(0),  
                        .reset(0),
                        .has_reset(1),
                        .is_rand(1),
                        .individually_accessible(0));
	endfunction
endclass


class FIFO_STATUS_REG extends uvm_reg;

	`uvm_object_utils(FIFO_STATUS_REG)

	uvm_reg_field fifo_full_status;
	uvm_reg_field fifo_empty_status;

	function new(name="FIFO_STATUS_REG");
	    super.new(.name(name),.n_bits(32),.has_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
    		fifo_full_status = uvm_reg_field::type_id::create("fifo_full_status");
    		fifo_full_status.configure(.parent(this),
                        .size(1),
                        .lsb_pos(0),
                        .access("RO"),
                        .volatile(0),  
                        .reset(0),
                        .has_reset(1),
                        .is_rand(1),
                        .individually_accessible(0));
    		fifo_empty_status = uvm_reg_field::type_id::create("fifo_empty_status");
    		fifo_empty_status.configure(.parent(this),
                        .size(1),
                        .lsb_pos(1),
                        .access("RO"),
                        .volatile(0),  
                        .reset(0),
                        .has_reset(1),
                        .is_rand(1),
                        .individually_accessible(0));
	endfunction
endclass
class WRITE_COUNT_REG extends uvm_reg;

	`uvm_object_utils(WRITE_COUNT_REG)

	uvm_reg_field  num_wr_transactions;

	function new(name="WRITE_COUNT_REG");
	    super.new(.name(name),.n_bits(32),.has_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
    		num_wr_transactions=uvm_reg_field::type_id::create("num_wr_transactions");
    		num_wr_transactions.configure(.parent(this),
                        .size(32),
                        .lsb_pos(0),
                        .access("RO"),
                        .volatile(0),  
                        .reset(0),
                        .has_reset(1),
                        .is_rand(1),
                        .individually_accessible(0));
	endfunction
endclass



class READ_COUNT_REG extends uvm_reg;

	`uvm_object_utils(READ_COUNT_REG)

	uvm_reg_field  num_rd_transactions;

	function new(name="READ_COUNT_REG");
	    super.new(.name(name),.n_bits(32),.has_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
    		num_rd_transactions=uvm_reg_field::type_id::create("num_rd_transactions");
    		num_rd_transactions.configure(.parent(this),
                        .size(32),
                        .lsb_pos(0),
                        .access("RO"),
                        .volatile(0),  
                        .reset(0),
                        .has_reset(1),
                        .is_rand(1),
                        .individually_accessible(0));
	endfunction
endclass


