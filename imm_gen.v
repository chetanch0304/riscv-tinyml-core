`timescale 1ns / 1ps
// ============================================================
// imm_gen.v
// Sign-extended immediate extraction, one wire per format.
// BUG FIX:
//   - I-type was reading [31:21] (11 bits); corrected to [31:20]
//   - B-type bit ordering now matches RISC-V spec exactly
//   - J-type bit ordering now matches RISC-V spec exactly
// ============================================================
module imm_gen (
    input  wire [31:0] instr,
    output wire [31:0] imm_i,    // I-type  (loads, arithmetic-imm)
    output wire [31:0] imm_s,    // S-type  (stores)
    output wire [31:0] imm_b,    // B-type  (branches)  — PC-relative
    output wire [31:0] imm_u,    // U-type  (LUI, AUIPC)
    output wire [31:0] imm_j     // J-type  (JAL)        — PC-relative
);
    // I-type: instr[31:20], sign-extended
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // S-type: {instr[31:25], instr[11:7]}, sign-extended
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type: {imm[12],imm[10:5],imm[4:1],imm[11],1'b0}
    //  bit  [12] = instr[31]
    //  bits [10:5] = instr[30:25]
    //  bits [4:1]  = instr[11:8]
    //  bit  [11]  = instr[7]
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7],
                    instr[30:25], instr[11:8], 1'b0};

    // U-type: upper 20 bits shifted left 12, lower 12 = 0
    assign imm_u = {instr[31:12], 12'b0};

    // J-type: {imm[20],imm[10:1],imm[11],imm[19:12],1'b0}
    //  bit  [20] = instr[31]
    //  bits [10:1] = instr[30:21]
    //  bit  [11]  = instr[20]
    //  bits [19:12] = instr[19:12]
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                    instr[20], instr[30:21], 1'b0};
endmodule
