import mem_pkg::*;
module axi_memory (
  axi_if.dut axi
);

 // Register definitions
 localparam MEMSIZEREG =32'h0000;
 localparam FIFOSTATUSREG =32'h0004;
 localparam WRITECOUNTREG =32'h0008;
 localparam READCOUNTREG =32'h000C;
 localparam FIFO_PTR_MSB = $clog2(mem_pkg::FIFO_DEPTH);
 localparam MEM_SIZE = $clog2(mem_pkg::MEM_DEPTH);


 // Memory logic
 logic [31:0] mem [0:mem_pkg::MEM_DEPTH-1]; //1KB memory

 // FIFO logic - buffers write transactions (address + data pairs)
 logic [31:0] fifo_addr [0:mem_pkg::FIFO_DEPTH-1]; // FIFO addresses
 logic [31:0] fifo_data [0:mem_pkg::FIFO_DEPTH-1]; // FIFO data
 logic [FIFO_PTR_MSB-1:0] fifo_head;
 logic [FIFO_PTR_MSB-1:0] fifo_tail;
 logic fifo_full;
 logic fifo_empty;
 logic [$clog2(mem_pkg::FIFO_DEPTH+1)-1:0] fifo_count; // Count of entries in FIFO

 // Registers - NO initial values (reset in reset block instead)
 logic [31:0] mem_size_reg;
 logic [31:0] write_count_reg;
 logic [31:0] read_count_reg;
 
 // FIFO drain signals
 logic [31:0] fifo_drain_addr;
 logic [31:0] fifo_drain_data;
 
 // Delay pipeline for writes (2-cycle delay)
 logic [31:0] write_pipe_addr [0:1];
 logic [31:0] write_pipe_data [0:1];
 logic [0:1] write_pipe_valid;
 
 // Delay pipeline for reads (2-cycle delay)
 logic [31:0] read_pipe_addr [0:1];
 logic [0:1] read_pipe_valid;

   // FIFO status signals
   assign fifo_full = (fifo_count == mem_pkg::FIFO_DEPTH);
   assign fifo_empty = (fifo_count == 0);
   assign axi.fifo_full = fifo_full;
   assign axi.fifo_empty = fifo_empty;

   // Read from FIFO for draining (combinational)
   assign fifo_drain_addr = fifo_addr[fifo_tail];
   assign fifo_drain_data = fifo_data[fifo_tail];
   
   // FIFO management - handles both enqueue and dequeue
   logic fifo_enqueue;
   logic fifo_dequeue;
   
   assign fifo_enqueue = axi.write_valid && axi.write_ready && !fifo_full &&
                         axi.write_addr != MEMSIZEREG &&
                         axi.write_addr != FIFOSTATUSREG &&
                         axi.write_addr != WRITECOUNTREG &&
                         axi.write_addr != READCOUNTREG;
   
   assign fifo_dequeue = !fifo_empty;
   
   always @(posedge axi.clk or negedge axi.rst_n) begin
     if (!axi.rst_n) begin
       fifo_head <= 0;
       fifo_tail <= 0;
       fifo_count <= 0;
       mem_size_reg <= mem_pkg::MEM_DEPTH;  // Reset to default: 1024 words
       write_count_reg <= 0;
       read_count_reg <= 0;
       write_pipe_addr[0] <= 0;
       write_pipe_addr[1] <= 0;
       write_pipe_data[0] <= 0;
       write_pipe_data[1] <= 0;
       write_pipe_valid[0] <= 0;
       write_pipe_valid[1] <= 0;
     end else begin
       // Enqueue into FIFO
       if (fifo_enqueue) begin
         fifo_addr[fifo_head] <= axi.write_addr;
         fifo_data[fifo_head] <= axi.write_data;
         fifo_head <= (fifo_head + 1) % mem_pkg::FIFO_DEPTH;
         fifo_count <= fifo_count + 1;
         write_count_reg <= write_count_reg + 1;
       end
       
       // Dequeue from FIFO into write pipeline (stage 0)
       if (fifo_dequeue) begin
         write_pipe_addr[0] <= fifo_drain_addr;
         write_pipe_data[0] <= fifo_drain_data;
         write_pipe_valid[0] <= 1'b1;
         fifo_tail <= (fifo_tail + 1) % mem_pkg::FIFO_DEPTH;
         fifo_count <= fifo_count - 1;
       end else begin
         write_pipe_valid[0] <= 1'b0;
       end
       
       // Write pipeline stage 1 (1-cycle delay)
       write_pipe_addr[1] <= write_pipe_addr[0];
       write_pipe_data[1] <= write_pipe_data[0];
       write_pipe_valid[1] <= write_pipe_valid[0];
       
       // Write pipeline stage 2 - commit to memory (2-cycle delay complete)
       if (write_pipe_valid[1]) begin
         // Convert byte address to word index (divide by 4, use bits [11:2])
         // Addresses are word-aligned (32-bit words), so use bits [11:2] for word index
         if (write_pipe_addr[1][11:2] < mem_size_reg) begin
           mem[write_pipe_addr[1][11:2]] <= write_pipe_data[1];
         end
       end
     end
   end
   
   // Read pipeline for 2-cycle delay
   always @(posedge axi.clk or negedge axi.rst_n) begin
     if (!axi.rst_n) begin
       read_pipe_addr[0] <= 0;
       read_pipe_addr[1] <= 0;
       read_pipe_valid[0] <= 0;
       read_pipe_valid[1] <= 0;
     end else begin
       // Read pipeline stage 0 - capture read request
       if (axi.read_valid && axi.read_ready) begin
         read_pipe_addr[0] <= axi.read_addr;
         read_pipe_valid[0] <= 1'b1;
       end else begin
         read_pipe_valid[0] <= 1'b0;
       end
       
       // Read pipeline stage 1 (1-cycle delay)
       read_pipe_addr[1] <= read_pipe_addr[0];
       read_pipe_valid[1] <= read_pipe_valid[0];
     end
   end
   // Memory and register access
   always @(posedge axi.clk or negedge axi.rst_n) begin
     if (!axi.rst_n) begin
       axi.write_ready <= 0;
       axi.read_ready <= 0;
       axi.read_data <= 0;
     end else begin
       // Write ready: accept writes if FIFO is not full (or if writing to special register)
       if (axi.write_addr == MEMSIZEREG) begin
         axi.write_ready <= axi.write_valid; // Special registers bypass FIFO
       end else begin
         axi.write_ready <= axi.write_valid && !fifo_full;
       end
       
       // Read ready: always ready for reads (no FIFO buffering needed)
       axi.read_ready <= axi.read_valid;
       
       // Handle writes to special registers immediately (bypass FIFO)
       if (axi.write_valid && axi.write_ready && axi.write_addr == MEMSIZEREG) begin
         mem_size_reg <= axi.write_data;
       end
       
       // Handle reads from memory and registers (2-cycle delay via pipeline)
       if (read_pipe_valid[1]) begin
         if (read_pipe_addr[1] == MEMSIZEREG) begin
           axi.read_data <= mem_size_reg;
         end else if (read_pipe_addr[1] == FIFOSTATUSREG) begin
           axi.read_data <= {30'd0, fifo_full, fifo_empty};
         end else if (read_pipe_addr[1] == WRITECOUNTREG) begin
           axi.read_data <= write_count_reg;
         end else if (read_pipe_addr[1] == READCOUNTREG) begin
           axi.read_data <= read_count_reg;
           read_count_reg <= read_count_reg + 1;
         end else begin
           // Convert byte address to word index (divide by 4, use bits [11:2])
           // Addresses are word-aligned (32-bit words), so use bits [11:2] for word index
           if (read_pipe_addr[1][11:2] < mem_size_reg) begin
             axi.read_data <= mem[read_pipe_addr[1][11:2]];
           end else begin
             axi.read_data <= 32'hDEADBEEF;
           end
         end
       end else begin
         axi.read_data <= 32'h0; // Default value when no read
       end
     end
   end
 endmodule
