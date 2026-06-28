`timescale 1ns / 1ps
// ============================================================
// tinyml_core.v
// Custom AI acceleration unit — new in this project.
//
// Supported operations (tinyml_op = funct3):
//   000 VMACCZ  acc  = rs1 * rs2         (zero-start accumulate)
//   001 VMACC   acc += rs1 * rs2         (accumulate)
//   010 VRELU   rd   = max(rs1, 0)       (ReLU activation)
//   011 VSIGM   rd   = sigmoid_approx(rs1)  (piecewise linear)
//   100 VMAXP   rd   = max(rs1, rs2)     (2-element max-pool)
//   101 VAVGP   rd   = (rs1 + rs2) >> 1  (2-element avg-pool)
//
// Accumulator:
//   - 32-bit dedicated register (acc)
//   - Cleared by VMACCZ
//   - Accumulated by VMACC
//   - Read as result for both MAC ops (rd = acc after op)
// ============================================================
module tinyml_core (
    input  wire        clk,
    input  wire        reset,
    input  wire        tinyml_en,
    input  wire [2:0]  tinyml_op,
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,
    output reg  [31:0] result,
    output wire [31:0] acc            // 🔥 THEEK KIYA: 'reg' hata kar 'wire' kar diya hai
);
    // ---- accumulator register ----
    reg [31:0] acc_reg;               // 🔥 THEEK KIYA: Register implementation actual memory block hai
    assign acc = acc_reg;   // wire out for debug (Ab ye perfectly chalega!)

    // ---- piecewise linear sigmoid ----
    function [31:0] sigmoid_approx;
        input signed [31:0] x;
        reg signed [31:0] sx;
        begin
            sx = $signed(x);
            if      (sx <= -4) sigmoid_approx = 32'd0;
            else if (sx <= -2) sigmoid_approx = ($signed(sx) + 4) * 16;
            else if (sx <= 0)  sigmoid_approx = ($signed(sx) + 2) * 48 + 32;
            else if (sx <= 2)  sigmoid_approx =  $signed(sx)      * 48 + 128;
            else if (sx <= 4)  sigmoid_approx = ($signed(sx) - 2) * 16 + 224;
            else               sigmoid_approx = 32'd255;
        end
    endfunction

    // ---- combinatorial result + sequential accumulator ----
    always @(*) begin
        result = 32'b0;
        if (tinyml_en) begin
            case (tinyml_op)
                3'd0: result = rs1_val * rs2_val;                               // VMACCZ: result = product
                3'd1: result = acc_reg + (rs1_val * rs2_val);                   // VMACC:  result = acc + product
                3'd2: result = ($signed(rs1_val) > 0) ? rs1_val : 32'd0;        // VRELU
                3'd3: result = sigmoid_approx(rs1_val);                         // VSIGM
                3'd4: result = ($signed(rs1_val) > $signed(rs2_val)) ? rs1_val : rs2_val; // VMAXP
                3'd5: result = (rs1_val + rs2_val) >> 1;                         // VAVGP
                default: result = 32'd0;
            endcase
        end
    end

    // accumulator update (registered)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            acc_reg <= 32'b0;
        end else if (tinyml_en) begin
            case (tinyml_op)
                3'd0: acc_reg <= rs1_val * rs2_val;              // VMACCZ: reset/load accumulator
                3'd1: acc_reg <= acc_reg + (rs1_val * rs2_val);  // VMACC:  accumulate
                default: acc_reg <= acc_reg;                     // other ops don't touch acc
            endcase
        end
    end
endmodule