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

 // FIFO logic
 logic [31:0] fifo [0:mem_pkg::FIFO_DEPTH]; //8-entry FIFO
 logic [FIFO_PTR_MSB-1:0] fifo_head;
 logic [FIFO_PTR_MSB-1:0] fifo_tail;
 logic fifo_full =0;
 logic fifo_empty =1;

 // Registers
 logic [31:0] mem_size_reg =MEM_SIZE; //1KB default
 logic [31:0] write_count_reg =0;
 logic [31:0] read_count_reg =0;

   // FIFO management
   always @(posedge axi.clk or negedge axi.rst_n) begin
     if (!axi.rst_n) begin
       fifo_head <=0;
       fifo_tail <=0;
       fifo_full <=0;
       fifo_empty <=1;
       write_count_reg <=0;
       read_count_reg <=0;
     end else begin
       if (axi.write_valid && axi.write_ready) begin
         if (!fifo_full) begin
           fifo[fifo_head] <= axi.write_data;
           fifo_head <= (fifo_head +1) %mem_pkg::FIFO_DEPTH;
           fifo_empty <=0;
           write_count_reg <= write_count_reg -1;
           if (fifo_head == fifo_tail)
             fifo_full <=1;
         end
       end
       if (axi.read_valid && axi.read_ready) begin
         if (!fifo_empty) begin
           fifo_tail <= (fifo_tail +1) %mem_pkg::FIFO_DEPTH;
           fifo_full <=0;
           read_count_reg <= read_count_reg +1;
           if (fifo_head == fifo_tail)
             fifo_empty <=0;
         end
       end
     end
   end
   // Memory and register access
   always @(posedge axi.clk or negedge axi.rst_n) begin
     if (!axi.rst_n) begin
       axi.write_ready <=0;
       axi.read_ready <=0;
       axi.read_data <=0;
     end else begin
       axi.write_ready <= axi.write_valid && !fifo_full;
       axi.read_ready <= axi.read_valid && !fifo_empty;
       if (axi.write_valid && axi.write_ready) begin
         if (axi.write_addr == MEMSIZEREG) begin
           mem_size_reg <= axi.write_data;
       end else if (axi.write_addr < mem_size_reg) begin
           mem[axi.write_addr[9:0]] <= axi.write_data;
       end
     end
     if (axi.read_valid && axi.read_ready) begin
       if (axi.read_addr == MEMSIZEREG) begin
         axi.read_data <= mem_size_reg;
       end else if (axi.read_addr == FIFOSTATUSREG) begin
         axi.read_data <= {30'd0, fifo_full, fifo_empty};
       end else if (axi.read_addr == WRITECOUNTREG) begin
         axi.read_data <= write_count_reg;
       end else if (axi.read_addr == READCOUNTREG) begin
         axi.read_data <= read_count_reg;
       end else if (axi.read_addr < mem_size_reg) begin
         axi.read_data <= mem[axi.read_addr[9:0]];
       end else begin
         axi.read_data <= 32'hDEADBEEF;
       end
     end
   end
 end
 endmodule
