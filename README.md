# RISC-V RV32I + TinyML Acceleration Core

[![Simulation](https://img.shields.io/badge/simulation-28%2F28%20passing-brightgreen)](#simulation)
[![Language](https://img.shields.io/badge/language-Verilog-blue)](#)
[![Architecture](https://img.shields.io/badge/ISA-RV32I-orange)](#supported-instructions)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

A fully functional 32-bit RISC-V processor implementing the RV32I base integer ISA, extended with a custom **TinyML acceleration co-processor** for neural network inference operations. Written entirely in synthesisable Verilog.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Pipeline Stages](#pipeline-stages)
- [Hazard Handling](#hazard-handling)
- [TinyML ISA Extension](#tinyml-isa-extension)
- [Supported Instructions](#supported-instructions)
- [File Structure](#file-structure)
- [Simulation](#simulation)
- [Author](#author)

---

## Features

- 5-stage in-order pipeline: **IF → ID → EX → MEM → WB**
- Full **data forwarding** (EX→EX and MEM→EX paths) via dedicated forwarding unit
- **Load-use stall** detection with 1-cycle bubble insertion
- **Branch/jump flush** — resolved in EX stage, no branch predictor needed
- **Write-first register file** — same-cycle WB→ID bypass
- Custom **TinyML ISA extension** — 6 new instructions for AI inference
- Dedicated **32-bit accumulator** register for MAC sequences
- **Piecewise-linear sigmoid** approximation (Q8.0 integer input)
- Self-checking testbench — **28 assertions, 0 failures**
- Fully synthesisable — no non-synthesisable constructs in RTL

---

## Architecture

```
 ┌──────────────────────────────────────────────────────────────────┐
 │                      5-Stage Pipeline                            │
 │                                                                  │
 │  ┌────┐  IF/ID  ┌────┐  ID/EX  ┌────┐  EX/MEM  ┌─────┐ MEM/WB │
 │  │ IF │────────►│ ID │────────►│ EX │──────────►│ MEM │───────►│ WB │
 │  └────┘         └────┘         └────┘           └─────┘        └────┘
 │                   │               │  │                            │
 │                   │     ┌─────────┘  └──────── Forwarding ───────┘
 │                   │     │                  EX→EX  and  MEM→EX
 │                   ▼     ▼
 │            ┌──────────────────┐
 │            │ Hazard Detection │  stall (load-use)  ·  flush (branch/jump)
 │            └──────────────────┘
 │
 │  EX stage contains:
 │  ┌───────────────────┬──────────────────────────────────────────┐
 │  │   ALU  (RV32I)    │            TinyML Core                   │
 │  │ ADD SUB AND OR XOR│  VMACC  VMACCZ  VRELU  VSIGM  VMAXP  VAVGP │
 │  │ SLL SRL SRA SLT…  │  + 32-bit dedicated accumulator register │
 │  └───────────────────┴──────────────────────────────────────────┘
 └──────────────────────────────────────────────────────────────────┘
```

---

## Pipeline Stages

| Stage | Modules | Function |
|-------|---------|----------|
| **IF** | `instruction_fetch_unit.v`, `instruction_memory.v` | PC register with stall/branch/jump control; byte-addressable instruction ROM |
| **ID** | `control_unit.v`, `register_file.v`, `imm_gen.v` | Opcode decode; 32×32 register read; immediate extraction (I/S/B/U/J formats) |
| **EX** | `alu.v`, `tinyml_core.v` | ALU execution; TinyML co-processor; branch resolution; forwarding muxes |
| **MEM** | `data_memory.v` | 32-bit word-addressed synchronous SRAM (64 words / 256 bytes) |
| **WB** | `top_riscv.v` | Writeback mux — priority: TinyML result > memory data > ALU result |

### Pipeline Registers

All four pipeline registers (`IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`) are implemented in `pipeline_regs.v` with:
- Synchronous reset to NOP / zero on `posedge clk`
- `stall` input — holds current values (used for load-use hazard)
- `flush` input — clears to NOP (used for branch/jump)

---

## Hazard Handling

### Data Hazards

| Hazard | Detection | Resolution |
|--------|-----------|------------|
| EX→EX RAW | `exmem_rd == ex_rs1/rs2` && `exmem_reg_write` | Forward `alu_result_mem` into ALU src mux |
| MEM→EX RAW | `memwb_rd == ex_rs1/rs2` && `memwb_reg_write` | Forward `wb_data` into ALU src mux |
| Load-use RAW | `idex_mem_read` && `idex_rd == ifid_rs1/rs2` | Stall: hold PC + IF/ID; insert bubble into ID/EX |
| Same-cycle WB→ID | WB writes `rd` at same posedge ID reads `rs` | Write-first bypass in `register_file.v` |

### Control Hazards

| Hazard | Detection | Resolution |
|--------|-----------|------------|
| Branch taken | Compare result = 1 resolved in EX stage | Flush IF/ID and ID/EX (2-cycle penalty) |
| JAL | `jump` signal asserted in EX | Flush IF/ID (1-cycle penalty) |

---

## TinyML ISA Extension

All TinyML instructions share opcode **`7'b111_1011`**. The `funct3` field selects the operation. They follow R-type encoding and write results back to `rd` in the register file.

| Instruction | funct3 | Operation | Use Case |
|-------------|--------|-----------|----------|
| `VMACCZ rd, rs1, rs2` | `000` | `acc = rs1 × rs2 ; rd = acc` | Start a new MAC chain |
| `VMACC  rd, rs1, rs2` | `001` | `acc += rs1 × rs2 ; rd = acc` | Continue accumulating |
| `VRELU  rd, rs1`      | `010` | `rd = max(rs1, 0)` | ReLU activation |
| `VSIGM  rd, rs1`      | `011` | `rd = sigmoid_approx(rs1)` | Sigmoid activation |
| `VMAXP  rd, rs1, rs2` | `100` | `rd = max(rs1, rs2)` | 2-element max pooling |
| `VAVGP  rd, rs1, rs2` | `101` | `rd = (rs1 + rs2) >> 1` | 2-element average pooling |

### Accumulator Register

A dedicated 32-bit `acc` register is maintained inside `tinyml_core.v`:
- `VMACCZ` resets `acc` to `rs1 × rs2` (start of new accumulation)
- `VMACC` adds `rs1 × rs2` to existing `acc`
- All other TinyML ops leave `acc` unchanged

### Example — Dot Product of Two 3-Element Vectors

```asm
# a = [x1, x2, x3],  b = [x4, x5, x6]
# Result written to x10

VMACCZ  x10, x1, x4     # acc  = a[0]*b[0]
VMACC   x10, x2, x5     # acc += a[1]*b[1]
VMACC   x10, x3, x6     # acc += a[2]*b[2]  →  x10 = dot(a, b)
```

### Sigmoid Approximation (piecewise linear, Q8.0 input)

```
x ≤ −4       →   0
x ∈ (−4,−2]  →  (x + 4) × 16
x ∈ (−2, 0]  →  (x + 2) × 48 + 32
x ∈ ( 0, 2]  →   x      × 48 + 128
x ∈ ( 2, 4]  →  (x − 2) × 16 + 224
x ≥  4       →  255
```

---

## Supported Instructions

### RV32I Base ISA

| Format | Instructions |
|--------|-------------|
| **R-type** | `ADD` `SUB` `AND` `OR` `XOR` `SLL` `SRL` `SRA` `SLT` `SLTU` |
| **I-type (arithmetic)** | `ADDI` `ANDI` `ORI` `XORI` `SLTI` `SLTIU` `SLLI` `SRLI` `SRAI` |
| **I-type (load)** | `LW` |
| **S-type** | `SW` |
| **B-type** | `BEQ` `BNE` `BLT` `BGE` |
| **U-type** | `LUI` |
| **J-type** | `JAL` |

> `AUIPC` and `JALR` are not yet implemented.

### TinyML Extension (opcode `7'b111_1011`)

`VMACCZ` `VMACC` `VRELU` `VSIGM` `VMAXP` `VAVGP`

---

## File Structure

```
riscv-tinyml-core/
├── top_riscv.v               # Top-level — connects all 5 pipeline stages
├── pipeline_regs.v           # IF/ID · ID/EX · EX/MEM · MEM/WB registers
├── tinyml_core.v             # TinyML co-processor (MAC · ReLU · Sigmoid · Pooling)
├── forwarding_unit.v         # EX→EX and MEM→EX forwarding mux selects
├── hazard_detection_unit.v   # Load-use stall + branch/jump flush logic
├── control_unit.v            # Opcode decoder — RV32I + TinyML extension
├── alu.v                     # 32-bit ALU — all RV32I operations
├── register_file.v           # 32×32 RegFile with write-first bypass
├── imm_gen.v                 # Sign-extended immediate extraction (I/S/B/U/J)
├── instruction_fetch_unit.v  # PC register with stall/branch/jump control
├── instruction_memory.v      # Byte-addressable instruction ROM (256 bytes)
├── data_memory.v             # 32-bit word-addressed synchronous SRAM
└── top_tb.v                  # Self-checking testbench — 28 assertions
```

---

## Simulation

### Requirements

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) `v10+`
- [GTKWave](https://gtkwave.sourceforge.net/) (optional — for waveform viewing)

### Run

```bash
# Compile
iverilog -g2012 pipeline_regs.v instruction_fetch_unit.v instruction_memory.v \
  control_unit.v register_file.v imm_gen.v alu.v tinyml_core.v \
  forwarding_unit.v hazard_detection_unit.v data_memory.v \
  top_riscv.v top_tb.v -o riscv_tinyml_sim

# Simulate
vvp riscv_tinyml_sim

# View waveforms (optional)
gtkwave riscv_tinyml.vcd
```

### Expected Output

```
============================================================
  RISC-V + TinyML Core — Self-Checking Testbench
============================================================

--- R-Type ---
  PASS  x1   addi x1,x0,5      got=0x00000005
  PASS  x3   add x3,x1,x2      got=0x00000008
  PASS  x4   sub x4,x3,x1      got=0x00000003
  ...

--- TinyML Extension ---
  PASS  x23  VMACCZ acc=5*3    got=0x0000000f
  PASS  x24  VMACC  +8*3=39    got=0x00000027
  PASS  x25  VRELU  max(3,0)   got=0x00000003
  PASS  x26  VMAXP  max(5,3)   got=0x00000005
  PASS  x27  VAVGP  (8+5)>>1   got=0x00000006
  PASS  x28  VSIGM  sig(5)     got=0x000000ff

============================================================
  Results: 28 PASSED  |  0 FAILED
============================================================
```

---

## Author

**Chetan Chaudhary**  
B.Tech Electronics and Communication Engineering  
NIT Silchar · Expected 2027

---

## License

MIT — see [LICENSE](LICENSE) for details.
