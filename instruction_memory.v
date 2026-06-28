`timescale 1ns / 1ps
// ============================================================
// instruction_memory.v — verified instruction encodings
// ============================================================
module instruction_memory (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] pc,
    output wire [31:0] instr_out
);
    reg [7:0] mem [0:255];
    assign instr_out = { mem[pc+3], mem[pc+2], mem[pc+1], mem[pc] };

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 256; i = i + 1) mem[i] <= 8'h00;

            // 0:  addi x1, x0, 5          0x00500093
            mem[3]<=8'h00; mem[2]<=8'h50; mem[1]<=8'h00; mem[0]<=8'h93;
            // 4:  addi x2, x0, 3          0x00300113
            mem[7]<=8'h00; mem[6]<=8'h30; mem[5]<=8'h01; mem[4]<=8'h13;
            // 8:  add  x3, x1, x2         0x002081B3
            mem[11]<=8'h00; mem[10]<=8'h20; mem[9]<=8'h81; mem[8]<=8'hB3;
            // 12: sub  x4, x3, x1         0x40118233
            mem[15]<=8'h40; mem[14]<=8'h11; mem[13]<=8'h82; mem[12]<=8'h33;
            // 16: and  x5, x1, x2         0x0020F2B3
            mem[19]<=8'h00; mem[18]<=8'h20; mem[17]<=8'hF2; mem[16]<=8'hB3;
            // 20: or   x6, x1, x2         0x002061B3 — NOTE: or uses funct3=110
            mem[23]<=8'h00; mem[22]<=8'h20; mem[21]<=8'hE3; mem[20]<=8'h33;
            // 24: xor  x7, x1, x2         0x0020C3B3
            mem[27]<=8'h00; mem[26]<=8'h20; mem[25]<=8'hC3; mem[24]<=8'hB3;
            // 28: sll  x8, x1, x2         0x00209433
            mem[31]<=8'h00; mem[30]<=8'h20; mem[29]<=8'h94; mem[28]<=8'h33;
            // 32: srl  x9, x3, x2         0x0021D4B3
            mem[35]<=8'h00; mem[34]<=8'h21; mem[33]<=8'hD4; mem[32]<=8'hB3;
            // 36: sra  x10,x3, x2         0x4021D533
            mem[39]<=8'h40; mem[38]<=8'h21; mem[37]<=8'hD5; mem[36]<=8'h33;
            // 40: slt  x11,x1, x2         0x0020A5B3
            mem[43]<=8'h00; mem[42]<=8'h20; mem[41]<=8'hA5; mem[40]<=8'hB3;
            // 44: addi x12,x1, 10         0x00A08613
            mem[47]<=8'h00; mem[46]<=8'hA0; mem[45]<=8'h86; mem[44]<=8'h13;
            // 48: ori  x13,x1, 0xF        0x00F0E693
            mem[51]<=8'h00; mem[50]<=8'hF0; mem[49]<=8'hE6; mem[48]<=8'h93;
            // 52: andi x14,x1, 0x3        0x0030F713
            mem[55]<=8'h00; mem[54]<=8'h30; mem[53]<=8'hF7; mem[52]<=8'h13;
            // 56: xori x15,x1, 0x6        0x0060C793
            mem[59]<=8'h00; mem[58]<=8'h60; mem[57]<=8'hC7; mem[56]<=8'h93;
            // 60: slti x16,x1, 10         0x00A0A813  funct3=010
            mem[63]<=8'h00; mem[62]<=8'hA0; mem[61]<=8'hA8; mem[60]<=8'h13;
            // 64: sw   x2, 0(x0)          0x00202023
            mem[67]<=8'h00; mem[66]<=8'h20; mem[65]<=8'h20; mem[64]<=8'h23;
            // 68: lw   x17, 0(x0)         0x00002883
            mem[71]<=8'h00; mem[70]<=8'h00; mem[69]<=8'h28; mem[68]<=8'h83;
            // 72: lui  x18, 0x12345       0x12345937
            mem[75]<=8'h12; mem[74]<=8'h34; mem[73]<=8'h59; mem[72]<=8'h37;
            // 76: beq  x1, x1, +8 (to PC=84)   0x00108463
            mem[79]<=8'h00; mem[78]<=8'h10; mem[77]<=8'h84; mem[76]<=8'h63;
            // 80: addi x19,x0,99 (should be skipped)  0x06300993
            mem[83]<=8'h06; mem[82]<=8'h30; mem[81]<=8'h09; mem[80]<=8'h93;
            // 84: addi x20,x0,42 (branch target)      0x02A00A13
            mem[87]<=8'h02; mem[86]<=8'hA0; mem[85]<=8'h0A; mem[84]<=8'h13;
            // 88: jal  x21, +8 (to PC=96)      0x00800AEF
            mem[91]<=8'h00; mem[90]<=8'h80; mem[89]<=8'h0A; mem[88]<=8'hEF;
            // 92: addi x0,x0,0 (NOP, skipped)  0x00000013
            mem[95]<=8'h00; mem[94]<=8'h00; mem[93]<=8'h00; mem[92]<=8'h13;
            // 96: addi x22,x0,7  (JAL target)  0x00700B13
            mem[99]<=8'h00; mem[98]<=8'h70; mem[97]<=8'h0B; mem[96]<=8'h13;

            // --- TinyML instructions ---
            // 100: VMACCZ x23, x1, x2       0x00208BFB
            mem[103]<=8'h00; mem[102]<=8'h20; mem[101]<=8'h8B; mem[100]<=8'hFB;
            // 104: VMACC  x24, x3, x2       0x00219C7B
            mem[107]<=8'h00; mem[106]<=8'h21; mem[105]<=8'h9C; mem[104]<=8'h7B;
            // 108: VRELU  x25, x4, x0       0x00022CFB
            mem[111]<=8'h00; mem[110]<=8'h02; mem[109]<=8'h2C; mem[108]<=8'hFB;
            // 112: VMAXP  x26, x1, x2       0x0020CD7B
            mem[115]<=8'h00; mem[114]<=8'h20; mem[113]<=8'hCD; mem[112]<=8'h7B;
            // 116: VAVGP  x27, x3, x1       0x0011DDFB
            mem[119]<=8'h00; mem[118]<=8'h11; mem[117]<=8'hDD; mem[116]<=8'hFB;
            // 120: VSIGM  x28, x1, x0       0x0000BE7B
            mem[123]<=8'h00; mem[122]<=8'h00; mem[121]<=8'hBE; mem[120]<=8'h7B;
            // 124: NOP
            mem[127]<=8'h00; mem[126]<=8'h00; mem[125]<=8'h00; mem[124]<=8'h13;
        end
    end
endmodule
