interface axi_if(input logic clk, input logic rst_n);
    // Write interface
    logic [31:0] write_addr;
    logic [31:0] write_data;
    logic write_valid;
    logic write_ready;

    // Read interface
    logic [31:0] read_addr;
    logic read_valid;
    logic read_ready;
    logic [31:0] read_data;

    // Status signals
    logic fifo_full;
    logic fifo_empty;

    // Clocking block
    clocking cb @(posedge clk);
        input rst_n, fifo_full, fifo_empty, write_ready, read_ready, read_data;
        output write_addr, write_data, write_valid, read_addr, read_valid;
    endclocking

    // Modports for different components
    modport tb (
        input clk, rst_n, write_ready, read_ready, fifo_full, fifo_empty, read_data,
        output write_addr, write_data, write_valid, read_addr, read_valid
    );

    modport dut (
        input clk, rst_n, write_addr, write_data, write_valid, read_addr, read_valid,
        output write_ready, read_ready, fifo_full, fifo_empty, read_data
    );
endinterface
