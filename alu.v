`timescale 1ns / 1ps
// ============================================================
// alu.v
// 32-bit ALU supporting all RV32I operations.
// BUG FIX: all duplicate case entries removed; each alu_control
//          code maps to exactly one operation.
// ============================================================
module alu (
    input  wire [31:0] src1,
    input  wire [31:0] src2,        // rs2 or immediate (muxed before ALU)
    input  wire [5:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero          // convenience flag (src1 == src2)
);
    assign zero = (result == 32'b0);

    always @(*) begin
        case (alu_control)
            6'd1:  result = src1 + src2;                           // ADD
            6'd2:  result = src1 - src2;                           // SUB
            6'd3:  result = src1 << src2[4:0];                     // SLL
            6'd4:  result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; // SLT
            6'd5:  result = (src1 < src2) ? 32'd1 : 32'd0;        // SLTU
            6'd6:  result = src1 ^ src2;                           // XOR
            6'd7:  result = src1 >> src2[4:0];                     // SRL
            6'd8:  result = $signed(src1) >>> src2[4:0];           // SRA
            6'd9:  result = src1 | src2;                           // OR
            6'd10: result = src1 & src2;                           // AND
            // I-type (src2 carries sign-extended immediate)
            6'd11: result = src1 + src2;                           // ADDI
            6'd12: result = src1 << src2[4:0];                     // SLLI
            6'd13: result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; // SLTI
            6'd14: result = (src1 < src2) ? 32'd1 : 32'd0;        // SLTIU
            6'd15: result = src1 ^ src2;                           // XORI
            6'd16: result = src1 >> src2[4:0];                     // SRLI
            6'd17: result = $signed(src1) >>> src2[4:0];           // SRAI
            6'd18: result = src1 | src2;                           // ORI
            6'd19: result = src1 & src2;                           // ANDI
            // Load/Store — address = rs1 + imm
            6'd20: result = src1 + src2;                           // LOAD addr
            6'd21: result = src1 + src2;                           // STORE addr
            // Branch compares (result==1 means condition true)
            6'd22: result = (src1 == src2) ? 32'd1 : 32'd0;       // BEQ
            6'd23: result = (src1 != src2) ? 32'd1 : 32'd0;       // BNE
            6'd24: result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; // BLT
            6'd25: result = ($signed(src1) >= $signed(src2)) ? 32'd1 : 32'd0;// BGE
            // LUI: pass imm_u straight through
            6'd26: result = src2;                                  // LUI
            // JAL: result = PC+4 (written to rd), handled in WB
            6'd27: result = src1 + 32'd4;                         // JAL pc+4
            default: result = 32'b0;
        endcase
    end
endmodule
