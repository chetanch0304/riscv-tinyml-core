`timescale 1ns / 1ps
// ============================================================
// top_tb.v — Self-checking testbench (corrected)
// ============================================================
module top_tb;

    reg clk, reset;
    integer pass_count, fail_count;

    top_riscv dut (.clk(clk), .reset(reset));

    initial clk = 0;
    always #10 clk = ~clk;

    task check_reg;
        input [4:0]  reg_num;
        input [31:0] expected;
        input [79:0] test_name;
        reg   [31:0] actual;
        begin
            actual = dut.rfile.regs[reg_num];
            if (actual === expected) begin
                $display("  PASS  x%-2d  %s  got=0x%08X", reg_num, test_name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  x%-2d  %s  expected=0x%08X  got=0x%08X",
                         reg_num, test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        reset = 1'b1;
        repeat(4) @(posedge clk);
        reset = 1'b0;
        repeat(160) @(posedge clk);
        #5;

        $display("\n============================================================");
        $display("  RISC-V + TinyML Core — Self-Checking Testbench");
        $display("============================================================");

        $display("\n--- R-Type ---");
        check_reg(5'd1,  32'd5,  "addi x1,x0,5    ");
        check_reg(5'd2,  32'd3,  "addi x2,x0,3    ");
        check_reg(5'd3,  32'd8,  "add x3,x1,x2   ");
        check_reg(5'd4,  32'd3,  "sub x4,x3,x1   ");   // 8-5=3
        check_reg(5'd5,  32'd1,  "and x5,x1,x2   ");   // 5&3=1
        check_reg(5'd6,  32'd7,  "or  x6,x1,x2   ");   // 5|3=7
        check_reg(5'd7,  32'd6,  "xor x7,x1,x2   ");   // 5^3=6
        check_reg(5'd8,  32'd40, "sll x8,x1,x2   ");   // 5<<3=40
        check_reg(5'd9,  32'd1,  "srl x9,x3,x2   ");   // 8>>3=1
        check_reg(5'd10, 32'd1,  "sra x10,x3,x2  ");   // 8>>>3=1
        check_reg(5'd11, 32'd0,  "slt x11,x1,x2  ");   // 5<3=0

        $display("\n--- I-Type Arithmetic ---");
        check_reg(5'd12, 32'd15,         "addi x12,x1,10 ");  // 5+10=15
        check_reg(5'd13, 32'd15,         "ori  x13,x1,0xF");  // 5|15=15
        check_reg(5'd14, 32'd1,          "andi x14,x1,3  ");  // 5&3=1
        check_reg(5'd15, 32'd3,          "xori x15,x1,6  ");  // 5^6=3
        check_reg(5'd16, 32'd1,          "slti x16,x1,10 ");  // 5<10=1

        $display("\n--- Load/Store ---");
        check_reg(5'd17, 32'd3,          "lw x17 from mem");

        $display("\n--- LUI ---");
        check_reg(5'd18, 32'h12345000,   "lui x18,0x12345");

        $display("\n--- Branch (BEQ x1,x1 taken, skips x19) ---");
        check_reg(5'd19, 32'd0,          "x19 skipped    ");   // must stay 0
        check_reg(5'd20, 32'd42,         "addi x20,x0,42 ");

        $display("\n--- JAL ---");
        // jal x21,+8: lands at PC=96 (addi x22,x0,7)
        // x21 = return addr = PC_jal+4 = 92
        check_reg(5'd21, 32'd92,         "jal x21 ret addr");
        check_reg(5'd22, 32'd7,          "addi x22,x0,7  ");

        $display("\n--- TinyML Extension ---");
        check_reg(5'd23, 32'd15,         "VMACCZ acc=5*3 ");
        check_reg(5'd24, 32'd39,         "VMACC  +8*3=39 ");
        check_reg(5'd25, 32'd3,          "VRELU  max(3,0)");
        check_reg(5'd26, 32'd5,          "VMAXP  max(5,3)");
        check_reg(5'd27, 32'd6,          "VAVGP  (8+5)>>1");
        check_reg(5'd28, 32'd255,        "VSIGM  sig(5)  ");

        $display("\n============================================================");
        $display("  Results: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("============================================================\n");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***\n");
        else
            $display("  *** SOME TESTS FAILED — check waveform ***\n");
        $finish;
    end

    initial begin
        $dumpfile("riscv_tinyml.vcd");
        $dumpvars(0, top_tb);
    end
endmodule
