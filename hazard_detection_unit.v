`timescale 1ns / 1ps
// ============================================================
// hazard_detection_unit.v
// Detects two classes of hazard:
//
// 1. Load-use hazard:
//    A load in ID/EX is followed by a use in the next cycle.
//    Fix: stall IF/ID register, stall PC, and insert a bubble
//         (NOP) into ID/EX.
//
// 2. Branch / jump taken:
//    When a branch resolves as taken (or a JAL is seen in ID),
//    the instructions in IF and ID must be flushed.
// ============================================================
module hazard_detection_unit (
    // From ID/EX pipeline register
    input  wire        idex_mem_read,  // is the EX instruction a load?
    input  wire [4:0]  idex_rd,        // load destination register
    // From IF/ID register (the instruction in ID)
    input  wire [4:0]  ifid_rs1,
    input  wire [4:0]  ifid_rs2,
    // Branch outcome (resolved in EX stage)
    input  wire        branch_taken,
    // Jump detected in ID
    input  wire        jump,
    // Outputs
    output wire        stall,           // hold PC and IF/ID
    output wire        flush_ifid,      // flush IF/ID (branch taken)
    output wire        flush_idex       // flush ID/EX (load-use bubble OR branch)
);
    // Load-use: load in EX writes rd that ID needs
    wire load_use_hazard = idex_mem_read &&
                           ((idex_rd == ifid_rs1) || (idex_rd == ifid_rs2));

    assign stall       = load_use_hazard;
    assign flush_ifid  = branch_taken || jump;
    assign flush_idex  = load_use_hazard || branch_taken;
endmodule
