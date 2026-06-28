`timescale 1ns / 1ps
// ============================================================
// top_riscv.v  —  RISC-V RV32I 5-Stage Pipeline + TinyML Core
// Author: TADAKAMALLA GOURAV (extended for TinyML)
//
// Pipeline stages:
//   IF  → instruction_fetch_unit + instruction_memory
//   ID  → control_unit + register_file + imm_gen
//   EX  → alu + tinyml_core  (+ forwarding muxes)
//   MEM → data_memory
//   WB  → writeback mux → register_file
//
// Hazard handling:
//   - Load-use stall    (hazard_detection_unit → stall/bubble)
//   - Branch flush      (branch resolved in EX → flush IF/ID, ID/EX)
//   - JAL flush         (resolved in ID → flush IF/ID)
//   - Forwarding        (EX→EX and MEM→EX via forwarding_unit)
// ============================================================

module top_riscv (
    input wire clk,
    input wire reset
);

// ============================================================
//  WIRE DECLARATIONS
// ============================================================

// ----- IF stage wires -----
wire [31:0] pc_if, pc_plus4_if, instr_if;

// ----- IF/ID register outputs -----
wire [31:0] pc_id, instr_id;

// ----- ID stage wires -----
wire [5:0]  alu_ctrl_id;
wire        reg_write_id, mem_read_id, mem_write_id, mem_to_reg_id;
wire        beq_id, bne_id, blt_id, bge_id, jump_id, lui_id;
wire        tinyml_en_id;
wire [2:0]  tinyml_op_id;
wire [31:0] rd1_id, rd2_id;
wire [31:0] imm_i_id, imm_s_id, imm_b_id, imm_u_id, imm_j_id;
wire [4:0]  rs1_id, rs2_id, rd_id;

// ----- ID/EX register outputs -----
wire [5:0]  alu_ctrl_ex;
wire        reg_write_ex, mem_read_ex, mem_write_ex, mem_to_reg_ex;
wire        beq_ex, bne_ex, blt_ex, bge_ex, jump_ex, lui_ex;
wire        tinyml_en_ex;
wire [2:0]  tinyml_op_ex;
wire [31:0] pc_ex, rd1_ex, rd2_ex;
wire [31:0] imm_ex, imm_b_ex, imm_j_ex, imm_u_ex;
wire [4:0]  rs1_ex, rs2_ex, rd_ex;

// ----- EX stage wires -----
wire [1:0]  fwdA, fwdB;
wire [31:0] alu_src1, alu_src2_mux, alu_src2;
wire [31:0] alu_result_ex, tinyml_result_ex;
wire [31:0] memwb_wb_data;   // writeback data from MEM/WB (for forwarding)
wire        branch_taken_ex;
wire [31:0] branch_target_ex, jump_target_ex;

// ----- EX/MEM register outputs -----
wire        reg_write_mem, mem_read_mem, mem_write_mem, mem_to_reg_mem;
wire        tinyml_en_mem;
wire        branch_taken_mem;
wire [31:0] branch_target_mem;
wire [31:0] alu_result_mem, tinyml_result_mem, write_data_mem;
wire [4:0]  rd_mem;

// ----- MEM stage wires -----
wire [31:0] rd_data_mem;

// ----- MEM/WB register outputs -----
wire        reg_write_wb, mem_to_reg_wb, tinyml_en_wb;
wire [31:0] rd_data_wb, alu_result_wb, tinyml_result_wb;
wire [4:0]  rd_wb;

// ----- WB mux -----
wire [31:0] wb_data;

// ----- Hazard signals -----
wire        stall, flush_ifid, flush_idex;


// ============================================================
//  STAGE DECODE HELPERS
// ============================================================
assign rs1_id = instr_id[19:15];
assign rs2_id = instr_id[24:20];
assign rd_id  = instr_id[11:7];


// ============================================================
//  HAZARD DETECTION UNIT
// ============================================================
hazard_detection_unit hdu (
    .idex_mem_read  (mem_read_ex),
    .idex_rd        (rd_ex),
    .ifid_rs1       (rs1_id),
    .ifid_rs2       (rs2_id),
    .branch_taken   (branch_taken_ex),
    .jump           (jump_ex),
    .stall          (stall),
    .flush_ifid     (flush_ifid),
    .flush_idex     (flush_idex)
);


// ============================================================
//  IF STAGE
// ============================================================
instruction_fetch_unit ifu (
    .clk           (clk),
    .reset         (reset),
    .stall         (stall),
    .branch_taken  (branch_taken_ex),
    .branch_target (branch_target_ex),
    .jump          (jump_ex),
    .jump_target   (jump_target_ex),
    .pc            (pc_if),
    .pc_plus4      (pc_plus4_if)
);

instruction_memory imem (
    .clk           (clk),
    .reset         (reset),
    .pc            (pc_if),
    .instr_out     (instr_if)
);

// IF/ID pipeline register
if_id_reg if_id (
    .clk       (clk),
    .reset     (reset),
    .stall     (stall),
    .flush     (flush_ifid),
    .pc_in     (pc_if),
    .instr_in  (instr_if),
    .pc_out    (pc_id),
    .instr_out (instr_id)
);


// ============================================================
//  ID STAGE
// ============================================================
control_unit cu (
    .reset        (reset),
    .funct7       (instr_id[31:25]),
    .funct3       (instr_id[14:12]),
    .opcode       (instr_id[6:0]),
    .alu_control  (alu_ctrl_id),
    .reg_write    (reg_write_id),
    .mem_read     (mem_read_id),
    .mem_write    (mem_write_id),
    .mem_to_reg   (mem_to_reg_id),
    .beq_ctrl     (beq_id),
    .bne_ctrl     (bne_id),
    .blt_ctrl     (blt_id),
    .bge_ctrl     (bge_id),
    .jump         (jump_id),
    .lui_ctrl     (lui_id),
    .tinyml_en    (tinyml_en_id),
    .tinyml_op    (tinyml_op_id)
);

register_file rfile (
    .clk         (clk),
    .reset       (reset),
    .rs1         (rs1_id),
    .rs2         (rs2_id),
    .read_data1  (rd1_id),
    .read_data2  (rd2_id),
    .rd          (rd_wb),
    .write_data  (wb_data),
    .reg_write   (reg_write_wb)
);

imm_gen ig (
    .instr   (instr_id),
    .imm_i   (imm_i_id),
    .imm_s   (imm_s_id),
    .imm_b   (imm_b_id),
    .imm_u   (imm_u_id),
    .imm_j   (imm_j_id)
);

// Select immediate for EX stage: stores need imm_s, everything else uses imm_i
wire [31:0] imm_for_ex = mem_write_id ? imm_s_id : imm_i_id;

// ID/EX pipeline register
id_ex_reg id_ex (
    .clk              (clk),   .reset          (reset),
    .flush            (flush_idex),
    .alu_control_in   (alu_ctrl_id),    .alu_control_out  (alu_ctrl_ex),
    .mem_read_in      (mem_read_id),    .mem_read_out     (mem_read_ex),
    .mem_write_in     (mem_write_id),   .mem_write_out    (mem_write_ex),
    .mem_to_reg_in    (mem_to_reg_id),  .mem_to_reg_out   (mem_to_reg_ex),
    .reg_write_in     (reg_write_id),   .reg_write_out    (reg_write_ex),
    .beq_ctrl_in      (beq_id),         .beq_ctrl_out     (beq_ex),
    .bne_ctrl_in      (bne_id),         .bne_ctrl_out     (bne_ex),
    .blt_ctrl_in      (blt_id),         .blt_ctrl_out     (blt_ex),
    .bge_ctrl_in      (bge_id),         .bge_ctrl_out     (bge_ex),
    .jump_in          (jump_id),         .jump_out         (jump_ex),
    .lui_ctrl_in      (lui_id),          .lui_ctrl_out     (lui_ex),
    .tinyml_en_in     (tinyml_en_id),   .tinyml_en_out    (tinyml_en_ex),
    .tinyml_op_in     (tinyml_op_id),   .tinyml_op_out    (tinyml_op_ex),
    .pc_in            (pc_id),           .pc_out           (pc_ex),
    .read_data1_in    (rd1_id),          .read_data1_out   (rd1_ex),
    .read_data2_in    (rd2_id),          .read_data2_out   (rd2_ex),
    .imm_in           (imm_for_ex),      .imm_out          (imm_ex),
    .imm_branch_in    (imm_b_id),        .imm_branch_out   (imm_b_ex),
    .imm_jump_in      (imm_j_id),        .imm_jump_out     (imm_j_ex),
    .imm_lui_in       (imm_u_id),        .imm_lui_out      (imm_u_ex),
    .rs1_in           (rs1_id),          .rs1_out          (rs1_ex),
    .rs2_in           (rs2_id),          .rs2_out          (rs2_ex),
    .rd_in            (rd_id),           .rd_out           (rd_ex)
);


// ============================================================
//  EX STAGE
// ============================================================
forwarding_unit fwu (
    .ex_rs1          (rs1_ex),
    .ex_rs2          (rs2_ex),
    .exmem_rd        (rd_mem),
    .exmem_reg_write (reg_write_mem),
    .memwb_rd        (rd_wb),
    .memwb_reg_write (reg_write_wb),
    .forwardA        (fwdA),
    .forwardB        (fwdB)
);

// Forwarding muxes
// For JAL, alu_src1 must be PC (to compute PC+4 as return address),
// not the register-file value of rs1.
wire [31:0] fwd_rs1 = (fwdA == 2'b10) ? alu_result_mem :
                      (fwdA == 2'b01) ? memwb_wb_data   : rd1_ex;
assign alu_src1 = jump_ex ? pc_ex : fwd_rs1;

assign alu_src2_mux = (fwdB == 2'b10) ? alu_result_mem :
                      (fwdB == 2'b01) ? memwb_wb_data   : rd2_ex;

// ALU second source:
//   STORE  → imm_ex already carries imm_s (muxed at ID/EX input below)
//   LUI    → upper immediate (imm_u_ex)
//   I-type → imm_ex (sign-extended I-type immediate)
//   R-type → forwarded rs2
assign alu_src2 = (lui_ex)                                      ? imm_u_ex
                : (alu_ctrl_ex >= 6'd11 && alu_ctrl_ex <= 6'd21) ? imm_ex
                : alu_src2_mux;

alu alu_unit (
    .src1        (alu_src1),
    .src2        (alu_src2),
    .alu_control (alu_ctrl_ex),
    .result      (alu_result_ex),
    .zero        ()
);

tinyml_core tml (
    .clk         (clk),
    .reset       (reset),
    .tinyml_en   (tinyml_en_ex),
    .tinyml_op   (tinyml_op_ex),
    .rs1_val     (alu_src1),
    .rs2_val     (alu_src2_mux),
    .result      (tinyml_result_ex),
    .acc         ()
);

// Branch resolution (EX stage)
assign branch_taken_ex  = (beq_ex  && (alu_result_ex == 32'd1)) ||
                          (bne_ex  && (alu_result_ex == 32'd1)) ||
                          (blt_ex  && (alu_result_ex == 32'd1)) ||
                          (bge_ex  && (alu_result_ex == 32'd1));

assign branch_target_ex = pc_ex + imm_b_ex;   // PC-relative branch
assign jump_target_ex   = pc_ex + imm_j_ex;   // PC-relative JAL

// EX/MEM pipeline register
ex_mem_reg ex_mem (
    .clk               (clk),      .reset            (reset),
    .flush             (1'b0),     // no flush after EX
    .mem_read_in       (mem_read_ex),   .mem_read_out     (mem_read_mem),
    .mem_write_in      (mem_write_ex),  .mem_write_out    (mem_write_mem),
    .mem_to_reg_in     (mem_to_reg_ex), .mem_to_reg_out   (mem_to_reg_mem),
    .reg_write_in      (reg_write_ex),  .reg_write_out    (reg_write_mem),
    .tinyml_en_in      (tinyml_en_ex),  .tinyml_en_out    (tinyml_en_mem),
    .branch_taken_in   (branch_taken_ex), .branch_taken_out (branch_taken_mem),
    .branch_target_in  (branch_target_ex),.branch_target_out(branch_target_mem),
    .alu_result_in     (alu_result_ex),  .alu_result_out   (alu_result_mem),
    .tinyml_result_in  (tinyml_result_ex),.tinyml_result_out(tinyml_result_mem),
    .write_data_in     (alu_src2_mux),  .write_data_out   (write_data_mem),
    .rd_in             (rd_ex),          .rd_out           (rd_mem)
);


// ============================================================
//  MEM STAGE
// ============================================================
data_memory dmem (
    .clk       (clk),
    .reset     (reset),
    .addr      (alu_result_mem),
    .wr_data   (write_data_mem),
    .mem_write (mem_write_mem),
    .mem_read  (mem_read_mem),
    .rd_data   (rd_data_mem)
);

// MEM/WB pipeline register
mem_wb_reg mem_wb (
    .clk              (clk),     .reset           (reset),
    .mem_to_reg_in    (mem_to_reg_mem),  .mem_to_reg_out  (mem_to_reg_wb),
    .reg_write_in     (reg_write_mem),   .reg_write_out   (reg_write_wb),
    .tinyml_en_in     (tinyml_en_mem),   .tinyml_en_out   (tinyml_en_wb),
    .read_data_in     (rd_data_mem),     .read_data_out   (rd_data_wb),
    .alu_result_in    (alu_result_mem),  .alu_result_out  (alu_result_wb),
    .tinyml_result_in (tinyml_result_mem),.tinyml_result_out(tinyml_result_wb),
    .rd_in            (rd_mem),          .rd_out          (rd_wb)
);


// ============================================================
//  WB STAGE — writeback mux
//  Priority: TinyML result > memory read > ALU result
// ============================================================
assign wb_data = tinyml_en_wb ? tinyml_result_wb :
                 mem_to_reg_wb ? rd_data_wb        : alu_result_wb;

assign memwb_wb_data = wb_data;   // expose to forwarding mux

endmodule
