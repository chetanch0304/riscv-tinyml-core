`timescale 1ns / 1ps
// ============================================================
// instruction_fetch_unit.v
// Manages PC: normal increment, branch, jump.
// BUG FIX: branch target is now computed in EX stage and
//          fed back here; PC update is fully registered.
// ============================================================
module instruction_fetch_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,           // hold PC (load-use hazard)
    input  wire        branch_taken,    // resolved in EX stage
    input  wire [31:0] branch_target,   // PC-relative resolved address
    input  wire        jump,            // JAL
    input  wire [31:0] jump_target,     // PC + imm_J
    output reg  [31:0] pc,
    output reg  [31:0] pc_plus4         // return address for JAL
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc       <= 32'b0;
            pc_plus4 <= 32'b0;
        end else if (!stall) begin
            pc_plus4 <= pc + 32'd4;
            if (branch_taken)
                pc <= branch_target;
            else if (jump)
                pc <= jump_target;
            else
                pc <= pc + 32'd4;
        end
        // stall: pc and pc_plus4 hold
    end
endmodule
