`timescale 1ns / 1ps
// ============================================================
// control_unit.v
// Decodes opcode/funct3/funct7 into all control signals.
//
// BUG FIXES from review:
//  1. sw opcode fixed: 7'b010_0011 (was 7'b0100_011 — 8 bits)
//  2. R-type now initialises lb and sw
//  3. All branches now consistently set reg_write=0, mem signals=0
//  4. alu_control encoding is now unique (no duplicate case entries)
//
// NEW: TinyML custom opcode 7'b111_1011 (funct3 selects op)
//   000 = VMACCZ, 001 = VMACC, 010 = VRELU,
//   011 = VSIGM,  100 = VMAXP, 101 = VAVGP
// ============================================================
module control_unit (
    input  wire        reset,
    input  wire [6:0]  funct7,
    input  wire [2:0]  funct3,
    input  wire [6:0]  opcode,
    // standard control outputs
    output reg  [5:0]  alu_control,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg         beq_ctrl,
    output reg         bne_ctrl,
    output reg         blt_ctrl,
    output reg         bge_ctrl,
    output reg         jump,
    output reg         lui_ctrl,
    // TinyML extension outputs
    output reg         tinyml_en,
    output reg  [2:0]  tinyml_op
);

    // ALU control encoding (unique — no duplicates)
    // R-type
    localparam ALU_ADD   = 6'd1,  ALU_SUB  = 6'd2,  ALU_SLL  = 6'd3;
    localparam ALU_SLT   = 6'd4,  ALU_SLTU = 6'd5,  ALU_XOR  = 6'd6;
    localparam ALU_SRL   = 6'd7,  ALU_SRA  = 6'd8,  ALU_OR   = 6'd9;
    localparam ALU_AND   = 6'd10;
    // I-type arithmetic
    localparam ALU_ADDI  = 6'd11, ALU_SLLI = 6'd12, ALU_SLTI = 6'd13;
    localparam ALU_SLTIU = 6'd14, ALU_XORI = 6'd15, ALU_SRLI = 6'd16;
    localparam ALU_SRAI  = 6'd17, ALU_ORI  = 6'd18, ALU_ANDI = 6'd19;
    // Load / Store (address = rs1 + imm, same ALU op)
    localparam ALU_LOAD  = 6'd20, ALU_STORE= 6'd21;
    // Branch compares (result used by forwarding/branch logic)
    localparam ALU_BEQ   = 6'd22, ALU_BNE  = 6'd23;
    localparam ALU_BLT   = 6'd24, ALU_BGE  = 6'd25;
    // LUI / JAL
    localparam ALU_LUI   = 6'd26, ALU_JAL  = 6'd27;

    // TinyML ops (stored in tinyml_op, not alu_control)
    localparam TML_VMACCZ = 3'd0, TML_VMACC = 3'd1, TML_VRELU = 3'd2;
    localparam TML_VSIGM  = 3'd3, TML_VMAXP = 3'd4, TML_VAVGP = 3'd5;

    // -------------------------------------------------------
    // default everything, then override per opcode
    // -------------------------------------------------------
    task set_defaults;
        begin
            alu_control <= 6'b0;
            reg_write   <= 1'b0;
            mem_read    <= 1'b0;
            mem_write   <= 1'b0;
            mem_to_reg  <= 1'b0;
            beq_ctrl    <= 1'b0;
            bne_ctrl    <= 1'b0;
            blt_ctrl    <= 1'b0;
            bge_ctrl    <= 1'b0;
            jump        <= 1'b0;
            lui_ctrl    <= 1'b0;
            tinyml_en   <= 1'b0;
            tinyml_op   <= 3'b0;
        end
    endtask

    always @(*) begin
        set_defaults;
        if (!reset) begin
            case (opcode)

                // -----------------------------------------------
                // R-TYPE: funct7 | funct3 dispatch
                // -----------------------------------------------
                7'b011_0011: begin
                    reg_write <= 1'b1;
                    case (funct3)
                        3'b000: alu_control <= (funct7 == 7'b010_0000) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_control <= ALU_SLL;
                        3'b010: alu_control <= ALU_SLT;
                        3'b011: alu_control <= ALU_SLTU;
                        3'b100: alu_control <= ALU_XOR;
                        3'b101: alu_control <= (funct7 == 7'b010_0000) ? ALU_SRA : ALU_SRL;
                        3'b110: alu_control <= ALU_OR;
                        3'b111: alu_control <= ALU_AND;
                        default:;
                    endcase
                end

                // -----------------------------------------------
                // I-TYPE arithmetic (opcode 0010011)
                // -----------------------------------------------
                7'b001_0011: begin
                    reg_write <= 1'b1;
                    case (funct3)
                        3'b000: alu_control <= ALU_ADDI;
                        3'b001: alu_control <= ALU_SLLI;
                        3'b010: alu_control <= ALU_SLTI;
                        3'b011: alu_control <= ALU_SLTIU;
                        3'b100: alu_control <= ALU_XORI;
                        3'b101: alu_control <= (funct7 == 7'b010_0000) ? ALU_SRAI : ALU_SRLI;
                        3'b110: alu_control <= ALU_ORI;
                        3'b111: alu_control <= ALU_ANDI;
                        default:;
                    endcase
                end

                // -----------------------------------------------
                // LOAD (opcode 0000011)
                // -----------------------------------------------
                7'b000_0011: begin
                    reg_write  <= 1'b1;
                    mem_read   <= 1'b1;
                    mem_to_reg <= 1'b1;
                    alu_control <= ALU_LOAD;  // compute address rs1+imm
                end

                // -----------------------------------------------
                // STORE (opcode 0100011) — BUG FIX: was 8-bit literal
                // -----------------------------------------------
                7'b010_0011: begin
                    mem_write  <= 1'b1;
                    alu_control <= ALU_STORE; // compute address rs1+imm
                end

                // -----------------------------------------------
                // BRANCH (opcode 1100011)
                // -----------------------------------------------
                7'b110_0011: begin
                    case (funct3)
                        3'b000: begin alu_control <= ALU_BEQ; beq_ctrl <= 1'b1; end
                        3'b001: begin alu_control <= ALU_BNE; bne_ctrl <= 1'b1; end
                        3'b100: begin alu_control <= ALU_BLT; blt_ctrl <= 1'b1; end
                        3'b101: begin alu_control <= ALU_BGE; bge_ctrl <= 1'b1; end
                        default:;
                    endcase
                end

                // -----------------------------------------------
                // LUI (opcode 0110111)
                // -----------------------------------------------
                7'b011_0111: begin
                    reg_write  <= 1'b1;
                    lui_ctrl   <= 1'b1;
                    alu_control <= ALU_LUI;
                end

                // -----------------------------------------------
                // JAL (opcode 1101111)
                // -----------------------------------------------
                7'b110_1111: begin
                    reg_write  <= 1'b1;
                    jump       <= 1'b1;
                    alu_control <= ALU_JAL;
                end

                // -----------------------------------------------
                // TINYML EXTENSION (opcode 1111011)
                //   funct3 selects the TinyML sub-operation
                // -----------------------------------------------
                7'b111_1011: begin
                    tinyml_en <= 1'b1;
                    reg_write <= 1'b1;   // result written back to rd
                    tinyml_op <= funct3; // 000..101 as above
                end

                default:;
            endcase
        end
    end
endmodule
