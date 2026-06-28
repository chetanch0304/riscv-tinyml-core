`timescale 1ns / 1ps
// ============================================================
// pipeline_regs.v
// 5-Stage Pipeline Register Structs (as individual modules)
// Stages: IF/ID  |  ID/EX  |  EX/MEM  |  MEM/WB
// ============================================================

// ----------------------------------------------------------
// IF/ID register
// ----------------------------------------------------------
module if_id_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,          // hold on load-use hazard
    input  wire        flush,          // flush on branch taken
    // inputs from IF stage
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    // outputs to ID stage
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            pc_out    <= 32'b0;
            instr_out <= 32'b0;   // NOP (ADDI x0,x0,0)
        end else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // stall: hold values (do nothing)
    end
endmodule

// ----------------------------------------------------------
// ID/EX register
// ----------------------------------------------------------
module id_ex_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,          // flush on branch mis-predict
    // control signals from ID
    input  wire [5:0]  alu_control_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        reg_write_in,
    input  wire        beq_ctrl_in,
    input  wire        bne_ctrl_in,
    input  wire        blt_ctrl_in,
    input  wire        bge_ctrl_in,
    input  wire        jump_in,
    input  wire        lui_ctrl_in,
    input  wire        tinyml_en_in,   // TinyML extension active
    input  wire [2:0]  tinyml_op_in,   // which TinyML op
    // data from ID
    input  wire [31:0] pc_in,
    input  wire [31:0] read_data1_in,
    input  wire [31:0] read_data2_in,
    input  wire [31:0] imm_in,
    input  wire [31:0] imm_branch_in,
    input  wire [31:0] imm_jump_in,
    input  wire [31:0] imm_lui_in,
    input  wire [4:0]  rs1_in,
    input  wire [4:0]  rs2_in,
    input  wire [4:0]  rd_in,
    // outputs to EX stage
    output reg  [5:0]  alu_control_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         reg_write_out,
    output reg         beq_ctrl_out,
    output reg         bne_ctrl_out,
    output reg         blt_ctrl_out,
    output reg         bge_ctrl_out,
    output reg         jump_out,
    output reg         lui_ctrl_out,
    output reg         tinyml_en_out,
    output reg  [2:0]  tinyml_op_out,
    output reg  [31:0] pc_out,
    output reg  [31:0] read_data1_out,
    output reg  [31:0] read_data2_out,
    output reg  [31:0] imm_out,
    output reg  [31:0] imm_branch_out,
    output reg  [31:0] imm_jump_out,
    output reg  [31:0] imm_lui_out,
    output reg  [4:0]  rs1_out,
    output reg  [4:0]  rs2_out,
    output reg  [4:0]  rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            alu_control_out  <= 6'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_to_reg_out   <= 1'b0;
            reg_write_out    <= 1'b0;
            beq_ctrl_out     <= 1'b0;
            bne_ctrl_out     <= 1'b0;
            blt_ctrl_out     <= 1'b0;
            bge_ctrl_out     <= 1'b0;
            jump_out         <= 1'b0;
            lui_ctrl_out     <= 1'b0;
            tinyml_en_out    <= 1'b0;
            tinyml_op_out    <= 3'b0;
            pc_out           <= 32'b0;
            read_data1_out   <= 32'b0;
            read_data2_out   <= 32'b0;
            imm_out          <= 32'b0;
            imm_branch_out   <= 32'b0;
            imm_jump_out     <= 32'b0;
            imm_lui_out      <= 32'b0;
            rs1_out          <= 5'b0;
            rs2_out          <= 5'b0;
            rd_out           <= 5'b0;
        end else begin
            alu_control_out  <= alu_control_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            mem_to_reg_out   <= mem_to_reg_in;
            reg_write_out    <= reg_write_in;
            beq_ctrl_out     <= beq_ctrl_in;
            bne_ctrl_out     <= bne_ctrl_in;
            blt_ctrl_out     <= blt_ctrl_in;
            bge_ctrl_out     <= bge_ctrl_in;
            jump_out         <= jump_in;
            lui_ctrl_out     <= lui_ctrl_in;
            tinyml_en_out    <= tinyml_en_in;
            tinyml_op_out    <= tinyml_op_in;
            pc_out           <= pc_in;
            read_data1_out   <= read_data1_in;
            read_data2_out   <= read_data2_in;
            imm_out          <= imm_in;
            imm_branch_out   <= imm_branch_in;
            imm_jump_out     <= imm_jump_in;
            imm_lui_out      <= imm_lui_in;
            rs1_out          <= rs1_in;
            rs2_out          <= rs2_in;
            rd_out           <= rd_in;
        end
    end
endmodule

// ----------------------------------------------------------
// EX/MEM register
// ----------------------------------------------------------
module ex_mem_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,
    // control
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        reg_write_in,
    input  wire        tinyml_en_in,
    // branch resolved signals
    input  wire        branch_taken_in,
    input  wire [31:0] branch_target_in,
    // data
    input  wire [31:0] alu_result_in,
    input  wire [31:0] tinyml_result_in,
    input  wire [31:0] write_data_in,
    input  wire [4:0]  rd_in,
    // outputs
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         reg_write_out,
    output reg         tinyml_en_out,
    output reg         branch_taken_out,
    output reg  [31:0] branch_target_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] tinyml_result_out,
    output reg  [31:0] write_data_out,
    output reg  [4:0]  rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            reg_write_out     <= 1'b0;
            tinyml_en_out     <= 1'b0;
            branch_taken_out  <= 1'b0;
            branch_target_out <= 32'b0;
            alu_result_out    <= 32'b0;
            tinyml_result_out <= 32'b0;
            write_data_out    <= 32'b0;
            rd_out            <= 5'b0;
        end else begin
            mem_read_out      <= mem_read_in;
            mem_write_out     <= mem_write_in;
            mem_to_reg_out    <= mem_to_reg_in;
            reg_write_out     <= reg_write_in;
            tinyml_en_out     <= tinyml_en_in;
            branch_taken_out  <= branch_taken_in;
            branch_target_out <= branch_target_in;
            alu_result_out    <= alu_result_in;
            tinyml_result_out <= tinyml_result_in;
            write_data_out    <= write_data_in;
            rd_out            <= rd_in;
        end
    end
endmodule

// ----------------------------------------------------------
// MEM/WB register
// ----------------------------------------------------------
module mem_wb_reg (
    input  wire        clk,
    input  wire        reset,
    // control
    input  wire        mem_to_reg_in,
    input  wire        reg_write_in,
    input  wire        tinyml_en_in,
    // data
    input  wire [31:0] read_data_in,
    input  wire [31:0] alu_result_in,
    input  wire [31:0] tinyml_result_in,
    input  wire [4:0]  rd_in,
    // outputs
    output reg         mem_to_reg_out,
    output reg         reg_write_out,
    output reg         tinyml_en_out,
    output reg  [31:0] read_data_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] tinyml_result_out,
    output reg  [4:0]  rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_to_reg_out    <= 1'b0;
            reg_write_out     <= 1'b0;
            tinyml_en_out     <= 1'b0;
            read_data_out     <= 32'b0;
            alu_result_out    <= 32'b0;
            tinyml_result_out <= 32'b0;
            rd_out            <= 5'b0;
        end else begin
            mem_to_reg_out    <= mem_to_reg_in;
            reg_write_out     <= reg_write_in;
            tinyml_en_out     <= tinyml_en_in;
            read_data_out     <= read_data_in;
            alu_result_out    <= alu_result_in;
            tinyml_result_out <= tinyml_result_in;
            rd_out            <= rd_in;
        end
    end
endmodule
