`timescale 1ns / 1ps
// ============================================================
// register_file.v
// 32x32 register file. x0 hardwired to 0.
// Synchronous write, combinatorial read WITH write-first bypass:
//   if the WB stage is writing to rs1 or rs2 at the same cycle
//   that ID is reading, bypass the new value directly.
//   This eliminates the same-cycle RAW hazard (the 3-deep
//   forwarding case that the forwarding unit can't see).
// ============================================================
module register_file (
    input  wire        clk,
    input  wire        reset,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    input  wire [4:0]  rd,
    input  wire [31:0] write_data,
    input  wire        reg_write
);
    reg [31:0] regs [0:31];

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (reg_write && rd != 5'b0) begin
            regs[rd] <= write_data;
        end
    end

    // Write-first bypass: if WB is writing to the register we're reading,
    // use the new write_data instead of the (not-yet-updated) reg array.
    assign read_data1 = (rs1 == 5'b0)                        ? 32'b0     :
                        (reg_write && rd != 5'b0 && rd == rs1) ? write_data :
                        regs[rs1];

    assign read_data2 = (rs2 == 5'b0)                        ? 32'b0     :
                        (reg_write && rd != 5'b0 && rd == rs2) ? write_data :
                        regs[rs2];
endmodule
