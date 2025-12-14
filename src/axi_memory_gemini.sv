import mem_pkg::*;
module axi_memory (
  axi_if.dut axi
);

 // --- Parameters and Definitions ---
 localparam MEMSIZEREG    = 32'h0000;
 localparam FIFOSTATUSREG = 32'h0004;
 localparam WRITECOUNTREG = 32'h0008;
 localparam READCOUNTREG  = 32'h000C;
 localparam FIFO_PTR_MSB  = $clog2(mem_pkg::FIFO_DEPTH);
 localparam RAM_ADDR_BITS = $clog2(mem_pkg::MEM_DEPTH); // Typically 10 for 1KB

 // Command Definition (Stored in FIFO)
 localparam CMD_WRITE = 1'b1;
 localparam CMD_READ  = 1'b0;
 localparam CMD_WIDTH = 1;
 localparam CMD_ENTRY_WIDTH = CMD_WIDTH + 32; // Command + Address (32-bit)

 // --- Memory and Registers ---
 logic [31:0] mem [0:mem_pkg::MEM_DEPTH-1]; // 1KB memory
 logic [31:0] mem_size_reg;    // NO initial value - reset in reset block
 logic [31:0] write_count_reg; // NO initial value - reset in reset block
 logic [31:0] read_count_reg;  // NO initial value - reset in reset block

 // --- FIFO Logic (Stores Command + Address) ---
 // We store only Command Type (1) + Address (32) = 33 bits. Data is handled separately for writes.
 logic [CMD_ENTRY_WIDTH-1:0] fifo_q [0:mem_pkg::FIFO_DEPTH-1];
 logic [FIFO_PTR_MSB-1:0] fifo_head;
 logic [FIFO_PTR_MSB-1:0] fifo_tail;
 logic [FIFO_PTR_MSB:0]   fifo_count; // Needs one extra bit for full check
 logic                    fifo_full;
 logic                    fifo_empty;

 // --- Execution Engine State ---
 typedef enum {IDLE, EXECUTE_CMD} exec_state_t;
 exec_state_t exec_state;  // Remove next_state - it's not used
 logic        fifo_read_en;

 // Deconstructed command from FIFO
 logic cmd_type_out;
 logic [31:0] addr_out;

 // Write Data Buffer: Since we only store address in FIFO, we need to buffer
 // the write data separately when a write command is accepted.
 logic [31:0] wdata_fifo [0:mem_pkg::FIFO_DEPTH-1];
 logic [FIFO_PTR_MSB-1:0] wdata_head, wdata_tail;

 // --- 1. Ready/Status Logic (Combinational) ---
 assign fifo_full  = (fifo_count == mem_pkg::FIFO_DEPTH);
 assign fifo_empty = (fifo_count == 0);

 // Ready signals controlled by FIFO space
 assign axi.write_ready = ~fifo_full;
 assign axi.read_ready  = ~fifo_full;
 
 // FIFO Status Register (Read Only)
 logic [31:0] fifo_status_reg;
 assign fifo_status_reg = {30'd0, fifo_full, fifo_empty};

 // Drive interface status signals (REQUIRED for interface compatibility)
 assign axi.fifo_full = fifo_full;
 assign axi.fifo_empty = fifo_empty;


 // --- 2. FIFO and Counter Management (Clocked) ---
 always @(posedge axi.clk or negedge axi.rst_n) begin
   if (!axi.rst_n) begin
       fifo_head <= 0;
       fifo_tail <= 0;
       wdata_head <= 0;
       wdata_tail <= 0;
       fifo_count <= 0;
       mem_size_reg <= mem_pkg::MEM_DEPTH;  // Reset to default: 1024 words
       write_count_reg <= 0;
       read_count_reg <= 0;
   end else begin
        
        // --- FIFO Write (Accepting Commands from Master) ---
        if (axi.write_valid && axi.write_ready) begin // Accepted Write
            // Store Command + Address
            fifo_q[fifo_head] <= {CMD_WRITE, axi.write_addr};
            // Store Write Data separately
            wdata_fifo[wdata_head] <= axi.write_data;
            
            fifo_head <= (fifo_head + 1) % mem_pkg::FIFO_DEPTH;
            wdata_head <= (wdata_head + 1) % mem_pkg::FIFO_DEPTH;
            fifo_count <= fifo_count + 1;
            write_count_reg <= write_count_reg + 1; // FIX: Increment counter
        end else if (axi.read_valid && axi.read_ready) begin // Accepted Read
            // Store Command + Address
            fifo_q[fifo_head] <= {CMD_READ, axi.read_addr};
            
            fifo_head <= (fifo_head + 1) % mem_pkg::FIFO_DEPTH;
            fifo_count <= fifo_count + 1;
            read_count_reg <= read_count_reg + 1; // FIX: Increment counter
        end

        // --- FIFO Read (Execution Engine Popping Command) ---
        if (fifo_read_en) begin
            fifo_tail <= (fifo_tail + 1) % mem_pkg::FIFO_DEPTH;
            fifo_count <= fifo_count - 1;
            
            // If it was a WRITE command, also pop the Write Data FIFO
            if (cmd_type_out == CMD_WRITE) begin
                wdata_tail <= (wdata_tail + 1) % mem_pkg::FIFO_DEPTH;
            end
        end
    end
 end


 // --- 3. Command Execution Engine (Clocked State Machine) ---
 // Deconstruct the command at the FIFO tail
 assign {cmd_type_out, addr_out} = fifo_q[fifo_tail];
 logic [31:0] wdata_out = wdata_fifo[wdata_tail]; // Write data to be executed

 always_ff @(posedge axi.clk or negedge axi.rst_n) begin
    if (!axi.rst_n) begin
        exec_state <= IDLE;
        fifo_read_en <= 1'b0;
        axi.read_data <= 32'h0;
    end else begin
        fifo_read_en <= 1'b0; // Default de-assert

        case (exec_state)
            IDLE: begin
                if (~fifo_empty) begin
                    exec_state <= EXECUTE_CMD;
                end
            end

            EXECUTE_CMD: begin
                // Check for Register Access
                if (addr_out <= READCOUNTREG) begin
                    // Register Access (Read or Write)
                    if (cmd_type_out == CMD_WRITE) begin
                        if (addr_out == MEMSIZEREG) mem_size_reg <= wdata_out;
                    end else begin // CMD_READ
                        // Drive read_data for register access
                        case (addr_out)
                            MEMSIZEREG:    axi.read_data <= mem_size_reg;
                            FIFOSTATUSREG: axi.read_data <= fifo_status_reg;
                            WRITECOUNTREG: axi.read_data <= write_count_reg;
                            READCOUNTREG:  axi.read_data <= read_count_reg;
                        endcase
                    end
                end 
                // Check for Memory Access
                // Convert byte address to word index (addresses are word-aligned, use bits [11:2])
                else if (addr_out[11:2] < mem_size_reg) begin
                    // Memory Access - addresses are word-aligned (32-bit words)
                    // Use bits [11:2] to convert byte address to word index
                    if (cmd_type_out == CMD_WRITE) begin
                        mem[addr_out[11:2]] <= wdata_out; // Write to RAM
                    end else begin // CMD_READ
                        axi.read_data <= mem[addr_out[11:2]]; // Read from RAM
                    end
                end else begin
                    // Invalid address - return DEADBEEF for reads
                    if (cmd_type_out == CMD_READ) begin
                        axi.read_data <= 32'hDEADBEEF;
                    end
                end
                
                // Done with the command, pop the FIFO
                fifo_read_en <= 1'b1;
                exec_state <= IDLE;
            end
        endcase
    end
 end
 
 // --- 4. Interface Default Values ---
 // FIX: Initialize interface outputs correctly outside of the clocked blocks
 // The read/write ready signals are assigned combinatorially above.
 // axi.read_data is assigned within the Execution Engine.

endmodule