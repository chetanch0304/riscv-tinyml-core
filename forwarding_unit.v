`timescale 1ns / 1ps
// ============================================================
// forwarding_unit.v
// Resolves data hazards by selecting the most recent value
// of a register rather than stalling.
//
// Priority:  EX/MEM stage  >  MEM/WB stage  >  register file
//
// forwardA / forwardB encoding:
//   2'b00 = read from register file (no hazard)
//   2'b10 = forward from EX/MEM  ALU result
//   2'b01 = forward from MEM/WB  (ALU result or memory data)
// ============================================================
module forwarding_unit (
    // Source registers in EX stage
    input  wire [4:0]  ex_rs1,
    input  wire [4:0]  ex_rs2,
    // Destination register from EX/MEM stage
    input  wire [4:0]  exmem_rd,
    input  wire        exmem_reg_write,
    // Destination register from MEM/WB stage
    input  wire [4:0]  memwb_rd,
    input  wire        memwb_reg_write,
    // Forwarding mux selects
    output reg  [1:0]  forwardA,
    output reg  [1:0]  forwardB
);
    always @(*) begin
        // ---- forwardA (for rs1) ----
        if (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == ex_rs1))
            forwardA = 2'b10;   // EX/MEM forward
        else if (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == ex_rs1))
            forwardA = 2'b01;   // MEM/WB forward
        else
            forwardA = 2'b00;   // no forwarding

        // ---- forwardB (for rs2) ----
        if (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == ex_rs2))
            forwardB = 2'b10;
        else if (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == ex_rs2))
            forwardB = 2'b01;
        else
            forwardB = 2'b00;
    end
endmodule
