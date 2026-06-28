`timescale 1ns / 1ps
// ============================================================
// data_memory.v
// 32-bit word-addressable SRAM, 64 words (256 bytes).
// Synchronous write, asynchronous (combinatorial) read.
//
// BUG FIX: original had 8-bit cells and wrote 32-bit wr_data
//          into a single byte. Now word-aligned 32-bit storage.
// ============================================================
module data_memory (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] addr,       // byte address (word-aligned)
    input  wire [31:0] wr_data,
    input  wire        mem_write,
    input  wire        mem_read,
    output wire [31:0] rd_data
);
    reg [31:0] mem [0:63];   // 64 words = 256 bytes

    integer i;
    // Synchronous write
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 64; i = i + 1)
                mem[i] <= 32'b0;
        end else if (mem_write) begin
            mem[addr[7:2]] <= wr_data;   // word-align: drop lower 2 bits
        end
    end

    // Asynchronous read
    assign rd_data = mem_read ? mem[addr[7:2]] : 32'b0;
endmodule
