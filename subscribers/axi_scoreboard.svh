`ifndef AXI_SCOREBOARD_SVH
`define AXI_SCOREBOARD_SVH

// DPI-C imports for C memory model
import "DPI-C" function void c_memory_model_init();
import "DPI-C" function void c_memory_model_write(input bit [31:0] addr, input bit [31:0] data);
import "DPI-C" function bit [31:0] c_memory_model_read(input bit [31:0] addr);

class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)

  uvm_analysis_imp#(axi_transaction, axi_scoreboard) analysis_export;
  
  // Configuration: use C memory model instead of SystemVerilog model
  bit use_c_memory_model = 0;
  
  // Memory model to track writes (SystemVerilog implementation)
  logic [31:0] memory_model [0:1023];
  logic [31:0] mem_size_reg_model;
  logic [31:0] write_count_reg_model;
  logic [31:0] read_count_reg_model;
  
  // Statistics
  int num_writes = 0;
  int num_reads = 0;
  int num_mismatches = 0;
  int num_matches = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    
    // Check if C memory model should be used (from config_db)
    if (uvm_config_db#(bit)::exists(this, "", "use_c_memory_model")) begin
      void'(uvm_config_db#(bit)::get(this, "", "use_c_memory_model", use_c_memory_model));
      `uvm_info(get_type_name(), $sformatf("C memory model enabled: %0d", use_c_memory_model), UVM_LOW)
    end
    
    // Initialize memory model
    if (use_c_memory_model) begin
      // Initialize C memory model
      c_memory_model_init();
      `uvm_info(get_type_name(), "Initialized C memory model", UVM_LOW)
    end else begin
      // Initialize SystemVerilog memory model
      foreach (memory_model[i]) begin
        memory_model[i] = 32'h0;
      end
      mem_size_reg_model = 1024;  // Default: 1024 words (MEM_DEPTH)
      write_count_reg_model = 0;
      read_count_reg_model = 0;
      `uvm_info(get_type_name(), "Initialized SystemVerilog memory model", UVM_LOW)
    end
  endfunction

  function void write(axi_transaction txn);
    `uvm_info(get_type_name(), $sformatf("Scoreboard received: %s", txn.convert2string()), UVM_MEDIUM)
    
    if (txn.is_write) begin
      handle_write(txn);
    end else begin
      handle_read(txn);
    end
  endfunction

  function void handle_write(axi_transaction txn);
    num_writes++;
    
    if (use_c_memory_model) begin
      // Use C memory model
      c_memory_model_write(txn.addr, txn.data);
      `uvm_info(get_type_name(), $sformatf("C model: Write addr=0x%08h, data=0x%08h", txn.addr, txn.data), UVM_HIGH)
    end else begin
      // Update SystemVerilog memory model based on address
      case (txn.addr)
        32'h0000: begin  // MEM_SIZE_REG
          mem_size_reg_model = txn.data;
          `uvm_info(get_type_name(), $sformatf("Updated MEM_SIZE_REG model to 0x%08h", txn.data), UVM_HIGH)
        end
        32'h0010, 32'h0014, 32'h0018, 32'h001C,
        32'h0020, 32'h0024, 32'h0028, 32'h002C,
        32'h0030, 32'h0034, 32'h0038, 32'h003C: begin  // Memory addresses (word-aligned)
          // Addresses are word-aligned, convert to word index using bits [11:2]
          if (txn.addr[11:2] < mem_size_reg_model) begin
            memory_model[txn.addr[11:2]] = txn.data;
            `uvm_info(get_type_name(), $sformatf("Updated memory model[0x%03h] = 0x%08h", txn.addr[11:2], txn.data), UVM_HIGH)
          end
        end
        default: begin
          // Convert byte address to word index (bits [11:2])
          if (txn.addr[11:2] < mem_size_reg_model) begin
            memory_model[txn.addr[11:2]] = txn.data;
            `uvm_info(get_type_name(), $sformatf("Updated memory model[0x%03h] = 0x%08h", txn.addr[11:2], txn.data), UVM_HIGH)
          end
        end
      endcase
    end
  endfunction

  function void handle_read(axi_transaction txn);
    logic [31:0] expected_data;
    num_reads++;
    
    if (use_c_memory_model) begin
      // Use C memory model to get expected data
      expected_data = c_memory_model_read(txn.addr);
      
      // Check if C model returned skip flag (0xFFFFFFFF for FIFO_STATUS_REG)
      if (expected_data === 32'hFFFFFFFF) begin
        `uvm_info(get_type_name(), "C model: FIFO_STATUS_REG read - skipping prediction", UVM_HIGH)
        return;
      end
    end else begin
      // Predict read data based on address (SystemVerilog model)
      case (txn.addr)
        32'h0000: begin  // MEM_SIZE_REG
          expected_data = mem_size_reg_model;
        end
        32'h0004: begin  // FIFO_STATUS_REG
          // Cannot predict FIFO status, skip check
          expected_data = txn.data;  // Accept whatever we get
          `uvm_info(get_type_name(), "FIFO_STATUS_REG read - skipping prediction", UVM_HIGH)
          return;
        end
        32'h0008: begin  // WRITE_COUNT_REG
          expected_data = write_count_reg_model;
        end
        32'h000C: begin  // READ_COUNT_REG
          expected_data = read_count_reg_model;
          read_count_reg_model++;
        end
        default: begin
          // Memory read - convert byte address to word index (bits [11:2])
          if (txn.addr[11:2] < mem_size_reg_model) begin
            expected_data = memory_model[txn.addr[11:2]];
          end else begin
            expected_data = 32'hDEADBEEF;  // Invalid address
          end
        end
      endcase
    end
    
    // Compare expected vs actual
    if (txn.data === expected_data) begin
      num_matches++;
      `uvm_info(get_type_name(), $sformatf("PASS: Read addr=0x%08h, expected=0x%08h, actual=0x%08h", 
                txn.addr, expected_data, txn.data), UVM_MEDIUM)
    end else begin
      num_mismatches++;
      `uvm_error(get_type_name(), $sformatf("FAIL: Read addr=0x%08h, expected=0x%08h, actual=0x%08h", 
                txn.addr, expected_data, txn.data))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Scoreboard Statistics:"), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Writes: %0d", num_writes), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Reads: %0d", num_reads), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Matches: %0d", num_matches), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Mismatches: %0d", num_mismatches), UVM_LOW)
    
    if (num_mismatches > 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard found %0d mismatches!", num_mismatches))
    end else begin
      `uvm_info(get_type_name(), "Scoreboard: All checks passed!", UVM_LOW)
    end
  endfunction

endclass

`endif
