# 4 Issue VLIW Implementation Specification

# **1\. Intended project tree** 

vliw/  
├── rtl/  
│   ├── common/  
│   │   └── vliw\_pkg.sv  
│   ├── core/  
│   │   ├── VLIW\_Core.sv  
│   │   ├── Program\_Counter.sv  
│   │   ├── IF\_ID\_reg.sv  
│   │   ├── control\_unit.sv  
│   │   ├── main\_decoder.sv  
│   │   ├── ALU\_decoder.sv  
│   │   ├── Imm\_Gen.sv  
│   │   ├── bundle\_checker.sv  
│   │   ├── RegisterFile.sv  
│   │   ├── ID\_EX\_reg.sv  
│   │   ├── forward\_unit.sv  
│   │   ├── hazard\_detect.sv  
│   │   ├── ALU.sv  
│   │   ├── Branch\_Comp.sv  
│   │   ├── Branch\_Resolve.sv  
│   │   ├── EX\_MEM\_reg.sv  
│   │   ├── load\_store\_unit.sv  
│   │   ├── MEM\_WB\_reg.sv  
│   │   ├── writeback\_unit.sv  
│   │   └── pipeline\_control.sv  
│   ├── memory/  
│   │   ├── IMEM.sv  
│   │   └── DMEM.sv  
│   └── system/  
│       ├── VLIW\_System.sv  
│       ├── performance\_counters.sv  
│       ├── reset\_sync.sv  
│       └── FPGA\_Top.sv  
├── tools/  
│   ├── isa.py  
│   ├── machine\_config.py  
│   ├── asm\_parser.py  
│   ├── assembler.py  
│   ├── disassembler.py  
│   ├── reference\_model.py  
│   ├── bundle\_model.py  
│   ├── scheduler.py  
│   └── schedule\_checker.py  
├── tb/  
│   ├── tb\_units.sv  
│   ├── tb\_pipeline.sv  
│   ├── tb\_vliw\_core.sv  
│   └── pipeline\_assertions.sv  
├── programs/  
│   ├── instruction\_tests/  
│   ├── pipeline\_tests/  
│   └── benchmarks/  
├── scripts/  
│   ├── run\_regression.py  
│   ├── generate\_random\_programs.py  
│   └── build\_fpga.tcl  
├── constraints/  
│   └── board constraint file  
├── docs/  
│   ├── specification  
│   ├── timing  
│   └── verification  
└── build/  
    ├── memory\_images/  
    ├── simulation/  
    └── implementation/hiding unresolved decisions.

# **2\. ISA and exact operation semantics**

Notation:

• R\[n\]: unsigned 32-bit register value.

• S32(v): interpret v as signed two’s-complement.

• U32(v): retain the low 32 bits.

• P: address of the current bundle.

• I, S, B, U, J: decoded immediates defined in Section 3\.

• A write to x0 is ignored.

• Ignoring a destination write does **not** suppress memory accesses, faults, or control flow.

| Instruction | Sources | Destination | Exact operation | Slots |
| :---- | :---- | :---- | :---- | :---- |
| NOP | None | None | No architectural effect | All |
| ADD | rs1, rs2 | rd | U32(R\[rs1\]+R\[rs2\]) | All |
| SUB | rs1, rs2 | rd | U32(R\[rs1\]-R\[rs2\]) | All |
| AND | rs1, rs2 | rd | Bitwise AND | All |
| OR | rs1, rs2 | rd | Bitwise OR | All |
| XOR | rs1, rs2 | rd | Bitwise XOR | All |
| SLT | rs1, rs2 | rd | 1 if S32(R\[rs1\]) \< S32(R\[rs2\]); otherwise 0 | All |
| SLL | rs1, rs2 | rd | Logical left shift by R\[rs2\]\[4:0\]; retain low 32 bits | All |
| SRL | rs1, rs2 | rd | Logical right shift by R\[rs2\]\[4:0\]; zero-fill | All |
| ADDI | rs1 | rd | U32(R\[rs1\]+I) | All |
| LUI | None | rd | U | All |
| LW | rs1 | rd | Load word from U32(R\[rs1\]+I) | S0 |
| SW | rs1, rs2 | None | Store R\[rs2\] at U32(R\[rs1\]+S) | S0 |
| BEQ | rs1, rs2 | None | If equal, next PC=U32(P+B); otherwise P+16 | S0 |
| BNE | rs1, rs2 | None | If unequal, next PC=U32(P+B); otherwise P+16 | S0 |
| JAL | None | rd | Write U32(P+16); next PC=U32(P+J) | S0 |
| HALT | None | None | Stop younger work; finish older work; assert halted | S0 |

Arithmetic overflow does not fault. There are no arithmetic flags.

SRA, SLTU, ANDI, other immediate operations, byte/halfword memory operations, JALR, AUIPC, multiplication, CSR instructions, and interrupts are excluded from this version.

For valid non-control operations, sequential PC advancement is one bundle. Memory operations can fault on alignment or range. Taken control transfers can fault on target alignment or range. Every operation can be rejected for encoding or bundle illegality.

**Result timing under P1**

| Operation | Result available for forwarding | Architectural register write |
| :---- | :---- | :---- |
| Register ALU, ADDI, LUI | MEM stage, immediately after EX/MEM capture | End of WB |
| JAL link | MEM stage, after target validation | End of WB |
| LW | WB stage, after synchronous data-memory read edge | End of WB |
| SW | No GPR result | Memory write at MEM-to-WB edge |
| BEQ/BNE | Decision during EX | No GPR write |
| NOP/HALT | No data result | None |

# **3\. Instruction encoding**

The supported standard operations RV32I field placements. Bundle execution, PC advancement, link values, slot rules, and HALT are custom. The field and opcode references are the official RV32I specification.

## **3.1 Field layouts**

R: \[31:25\] funct7 | \[24:20\] rs2 | \[19:15\] rs1 |  
   \[14:12\] funct3 | \[11:7\] rd | \[6:0\] opcode

I: \[31:20\] imm\[11:0\] | \[19:15\] rs1 |  
   \[14:12\] funct3 | \[11:7\] rd | \[6:0\] opcode

S: \[31:25\] imm\[11:5\] | \[24:20\] rs2 | \[19:15\] rs1 |  
   \[14:12\] funct3 | \[11:7\] imm\[4:0\] | \[6:0\] opcode

B: \[31\] imm\[12\] | \[30:25\] imm\[10:5\] |  
   \[24:20\] rs2 | \[19:15\] rs1 | \[14:12\] funct3 |  
   \[11:8\] imm\[4:1\] | \[7\] imm\[11\] | \[6:0\] opcode

U: \[31:12\] imm\[31:12\] | \[11:7\] rd | \[6:0\] opcode

J: \[31\] imm\[20\] | \[30:21\] imm\[10:1\] |  
   \[20\] imm\[11\] | \[19:12\] imm\[19:12\] |  
   \[11:7\] rd | \[6:0\] opcode

## **3.2 Authoritative encoding table**

Hexadecimal values are used for opcode and funct7.

| Instruction | Format | Opcode | funct3 | funct7 / additional condition |
| :---- | :---- | :---- | :---- | :---- |
| ADD | R | 33 | 000 | 00 |
| SUB | R | 33 | 000 | 20 |
| AND | R | 33 | 111 | 00 |
| OR | R | 33 | 110 | 00 |
| XOR | R | 33 | 100 | 00 |
| SLT | R | 33 | 010 | 00 |
| SLL | R | 33 | 001 | 00 |
| SRL | R | 33 | 101 | 00 |
| ADDI | I | 13 | 000 | All 12 immediate bits allowed |
| LUI | U | 37 | — | All 20 immediate bits allowed |
| LW | I | 03 | 010 | All 12 immediate bits allowed |
| SW | S | 23 | 010 | All 12 immediate bits allowed |
| BEQ | B | 63 | 000 | B-immediate layout |
| BNE | B | 63 | 001 | B-immediate layout |
| JAL | J | 6F | — | J-immediate layout |
| NOP | I alias | — | — | Entire word=00000013 |
| HALT | Custom | 0B | — | Entire word=0000000B only |

All other words are illegal. In particular:

• 0x00000000 is illegal.

• The entire 7-bit opcode must be checked.

• R-format legality requires the entire funct7.

• Exact NOP is recognized before ordinary ADDI accounting.

• Other operations writing x0 remain valid operations.

## **3.3 Immediate generation**

I \= sign\_extend\_32(inst\[31:20\])

S \= sign\_extend\_32({inst\[31:25\], inst\[11:7\]})

B \= sign\_extend\_32(  
      {inst\[31\], inst\[7\], inst\[30:25\], inst\[11:8\], 0}  
    )

U \= {inst\[31:12\], 12 zero bits}

J \= sign\_extend\_32(  
      {inst\[31\], inst\[19:12\], inst\[20\], inst\[30:21\], 0}  
    )

| Immediate | Encoded range |
| :---- | :---- |
| I/S | −2048 to \+2047 bytes or integer units, as applicable |
| B | −4096 to \+4094 bytes, even |
| J | −1048576 to \+1048574 bytes, even |
| U | Raw 20-bit field placed in bits \[31:12\] |

Although B/J encode even offsets, **executed targets must be 16-byte aligned**. The assembler must reject statically misaligned control targets.

# **4\. Bundle representation and legality**

127          96 95           64 63           32 31            0  
\+--------------+---------------+---------------+---------------+  
|    Slot 3    |    Slot 2     |    Slot 1     |    Slot 0     |  
\+--------------+---------------+---------------+---------------+  
Instruction image line k holds the bundle at byte address 16k.

A hexadecimal image line contains exactly 32 hexadecimal digits:

S3\_word S2\_word S1\_word S0\_word  
Spaces above illustrate grouping; the image uses one uninterrupted hexadecimal value per line.

If serialized as bytes, the lowest-address byte contains bundle bits \[7:0\]. Four bytes encode S0, followed by S1, S2, and S3.

## **4.1 Legality rules**

| Rule | Required behavior |
| :---- | :---- |
| B01 | Every slot contains a legal instruction encoding |
| B02 | LW, SW, BEQ, BNE, JAL, and HALT occur only in S0 |
| B03 | BEQ/BNE/JAL/HALT require exact NOP in S1–S3 |
| B04 | No two slots write the same nonzero destination |
| B05 | No slot writes a nonzero register read by another slot |
| B06 | Dependencies involving writes to x0 are ignored |
| B07 | A source/destination overlap within one operation is allowed |
| B08 | All source values are taken before the bundle’s writes |
| B09 | No same-bundle forwarding |
| B10 | Any violation rejects the entire bundle |

B05 is P1’s conservative rule. It rejects both orderings of cross-slot read/write overlap. Therefore the initial scheduler does not need to distinguish a potentially legal WAR pairing from an illegal same-bundle producer/consumer pairing.

## **4.2 Ten legal examples**

N means exact NOP. T means an aligned, in-range target.

| \# | Bundle |
| :---- | :---- |
| 1 | {N | N | N | N} |
| 2 | {ADD x1,x2,x3 | N | N | N} |
| 3 | {ADD x1,x2,x3 | SUB x4,x5,x6 | N | N} |
| 4 | {ADDI x1,x0,1 | ADDI x2,x0,2 | ADDI x3,x0,3 | ADDI x4,x0,4} |
| 5 | {LUI x1,0x12345 | XOR x2,x3,x4 | N | N} |
| 6 | {LW x1,0(x10) | ADD x2,x3,x4 | N | N} |
| 7 | {SW x1,0(x10) | ADD x2,x3,x4 | N | N} |
| 8 | {BEQ x1,x2,T | N | N | N} |
| 9 | {JAL x1,T | N | N | N} |
| 10 | {HALT | N | N | N} |

## **4.3 Ten illegal examples**

| \# | Bundle | Violation |
| :---- | :---- | :---- |
| 1 | {ADD x1,x2,x3 | SUB x4,x1,x5 | N | N} | B05 |
| 2 | {ADD x4,x1,x2 | ADD x1,x5,x6 | N | N} | B05, reversed read/write ordering |
| 3 | {ADD x1,x2,x3 | SUB x1,x4,x5 | N | N} | B04 |
| 4 | {N | LW x1,0(x2) | N | N} | B02 |
| 5 | {N | N | SW x1,0(x2) | N} | B02 |
| 6 | {N | N | N | BEQ x1,x2,T} | B02 |
| 7 | {BEQ x1,x2,T | ADD x3,x4,x5 | N | N} | B03 |
| 8 | {JAL x1,T | N | ADDI x2,x0,1 | N} | B03 |
| 9 | {HALT | N | N | LUI x3,1} | B03 |
| 10 | {0x00000000 | N | N | N} | B01 |

An aligned LW that later accesses outside data memory is a **legal bundle with a runtime fault**, not a static bundle-legality failure.

# **5\. Architectural registers and memory**

## **5.1 Architectural state table**

| State | Width/count | Reset | Read behavior | Write behavior |
| :---- | :---- | :---- | :---- | :---- |
| x0 | 32 | 0 | Always zero | Ignore all writes |
| x1…x31 | 31 × 32 | 0 | Current committed value | Up to four distinct registers per WB edge |
| Architectural PC | 32 | 0 | Debug/reference-model state | Next address after retired bundle |
| Instruction memory | IMEM\_BUNDLES × 128 | Preserved | Fetch only | Preloaded; no CPU writes |
| Data memory | DMEM\_WORDS × 32 | Preserved | LW | SW |
| halted | 1 | 0 | Status output | Sticky until reset |
| faulted | 1 | 0 | Status output | Sticky until reset |
| fault\_pc | 32 | 0 | Status output | Address of faulting bundle |
| fault\_code | 4 | 0 | Status output | Defined in Section 10 |
| fault\_slots | 4 | 0 | Status output | Participating/offending slot mask |
| fault\_addr | 32 | 0 | Status output | Bad address for address faults; otherwise zero |

No CSR instructions or software-readable counter registers are included.

architectural\_pc is distinct from speculative fetch\_pc. On terminal HALT/fault completion, architectural PC identifies the stopping bundle.

## **5.2 Address ranges**

Build parameters:

IMEM\_BUNDLES \>= 1  
DMEM\_WORDS   \>= 1

Instruction bytes \= 16 × IMEM\_BUNDLES  
Data bytes        \=  4 × DMEM\_WORDS  
Use at least 33-bit elaboration arithmetic to calculate limits without overflow.

| Access | Valid condition |
| :---- | :---- |
| Bundle fetch | PC\[3:0\]=0 and PC \< 16×IMEM\_BUNDLES |
| LW/SW | EA\[1:0\]=0 and EA \< 4×DMEM\_WORDS |
| Taken branch/JAL | Target satisfies valid bundle-fetch conditions |

Addresses are checked **before truncation into RAM indices**.

instruction\_index \= PC \>\> 4  
data\_word\_index   \= EA \>\> 2  
Effective-address arithmetic wraps to 32 bits before alignment and range checks.

Data memory is little-endian. Because only word accesses exist initially, the RTL stores full 32-bit words without byte enables.

A core reset must not clear either RAM. Program and data images determine their initial contents.

# **6\. Pipeline and synchronous-memory timing**

P1 retains your four named pipeline-register modules and adds a small fetch-response holding state inside VLIW\_Core.

Fetch PC → synchronous IMEM response  
                    ↓  
                 IF\_ID\_reg  
                    ↓  
            decode / register read  
                    ↓  
                 ID\_EX\_reg  
                    ↓  
                   EX  
                    ↓  
                 EX\_MEM\_reg  
                    ↓  
           synchronous data access  
                    ↓  
       MEM\_WB metadata \+ DMEM output register  
                    ↓  
                   WB  
The fetch holding state is necessary because a RAM response can already exist while decode becomes stalled.

## **6.1 Clock convention**

All edge references below refer to rising edges.

Signals shown “during a stage” exist between clock edges. A synchronous memory accepts its request at an edge and updates its output **after that edge**.

## **6.2 Normal operation**

For a bundle whose instruction-memory request is accepted at edge e0:

| Edge/interval | Action |
| :---- | :---- |
| e0 | IMEM accepts address; fetch metadata captures PC |
| After e0 | IMEM output and fetch metadata describe the same bundle |
| e1 | IF/ID captures that response if decode has space |
| e1 → e2 | Decode, legality checking, register reads |
| e2 | Bundle issues into ID/EX |
| e2 → e3 | EX computes results, addresses, branch decision, and faults |
| e3 | Nonfaulting bundle enters EX/MEM |
| e3 → e4 | MEM presents data-memory request |
| e4 | DMEM accepts load/store; MEM/WB captures matching metadata |
| After e4 | Load data and MEM/WB metadata are aligned in WB |
| e5 | GPR writes and bundle retirement |

**MEM\_WB must not capture the newly generated load data at \`e4\`.** Its metadata is captured at e4; the registered DMEM output supplies load data throughout the following WB interval.

## **6.3 LW followed by a dependent operation**

| Edge | Load bundle | Dependent bundle |
| :---- | :---- | :---- |
| e2 | Issues into EX | In decode |
| e3 | Enters MEM | Held in decode; bubble enters EX |
| e4 | Enters WB; RAM output becomes available | Issues into EX |
| e4 → e5 | WB forwards loaded value | Executes using that value |
| e5 | Writes register | Enters MEM |

For this exact timing contract, the minimum issue spacing is:

| Producer | Dependent issue spacing |
| :---- | :---- |
| ALU / ADDI / LUI | 1 cycle |
| LW | 2 cycles |
| JAL | Controlled by branch barrier; link uses normal forwarding |
| SW | No register result |

The one-cycle load-use stall is a consequence of this P1 timing.

## **6.4 Store timing**

A store bundle issued at e2:

1\. Computes and checks its address during e2 → e3.

2\. Enters MEM only if the entire bundle is nonfaulting.

3\. Writes memory at e4.

4\. Retires, with any partner GPR writes, at e5.

A following load to the same word reaches its memory edge after the store write, so no store buffer or memory forwarding is required.

# **7\. Package definitions and pipeline register tables**

These are data definitions, not RTL source.

## **7.1 Common conventions**

• Lane index s=0…3.

• Operand port 2s is lane s source A.

• Operand port 2s+1 is lane s source B.

• Aggregate port widths are given as count × element width.

• Flattened arrays place element 0 in the least-significant bits.

• Within a named packed record, fields are ordered as listed, first field most significant.

• Every combinational output must be assigned for all input combinations.

• Reset payloads are zero; validity determines whether payloads have meaning.

## **7.2 Control encodings**

| Type | Width | Values |
| :---- | :---- | :---- |
| alu\_op | 4 | ADD=0, SUB=1, AND=2, OR=3, XOR=4, SLL=5, SRL=6, SLT=8, PASS\_B=A |
| imm\_sel | 3 | I=0, S=1, B=2, U=3, J=4, NONE=7 |
| mem\_op | 2 | NONE=0, LW=1, SW=2; 3 invalid |
| ctrl\_op | 2 | NONE=0, BEQ=1, BNE=2, JAL=3 |
| terminal | 2 | NONE=0, HALT=1, FAULT=2; 3 invalid |
| mode | 2 | RUN=0, DRAIN\_HALT=1, DRAIN\_FAULT=2, STOP=3 |

HALT is represented by its own decoded flag.

## **7.3 fault\_t**

| Field | Width | Meaning |
| :---- | :---- | :---- |
| valid | 1 | Fault present |
| code | 4 | Fault code |
| slots | 4 | Slot mask |
| addr | 32 | Bad address or zero |

Total: **41 bits**.

## **7.4 decode\_t**

| Field | Width | Meaning |
| :---- | :---- | :---- |
| legal | 1 | Supported encoding |
| active | 1 | Instruction is not exact NOP |
| use\_a, use\_b | 1 each | Reads rs1/rs2 |
| write\_rd | 1 | Instruction has register result, before x0 suppression |
| rs1, rs2, rd | 5 each | Register indices |
| imm | 32 | Expanded immediate |
| alu\_op | 4 | ALU selection |
| b\_imm | 1 | Select immediate as ALU B |
| mem\_op | 2 | NONE/LW/SW |
| ctrl\_op | 2 | NONE/BEQ/BNE/JAL |
| halt | 1 | Exact HALT |

Total: **62 bits**.

For unused registers, decode must output index zero. For illegal instructions, legal=0; all other fields are zero.

## **7.5 IF/ID record d\_packet\_t**

| Field | Count | Width each | Classification |
| :---- | :---- | :---- | :---- |
| valid | 1 | 1 | Bundle |
| pc | 1 | 32 | Bundle |
| instr | 4 | 32 | Slot |
| fault | 1 | 41 | Fetch fault metadata |

Total: **202 bits**.

A fetch fault is carried as a token; instruction bits are ignored.

## **7.6 ID/EX record e\_packet\_t**

| Field | Count | Width each | Classification |
| :---- | :---- | :---- | :---- |
| valid | 1 | 1 | Bundle |
| pc | 1 | 32 | Bundle |
| dec | 4 | 62 | Slot |
| operand | 8 | 32 | Slot source |
| fault | 1 | 41 | Fetch/decode/bundle fault |

Total: **578 bits**.

## **7.7 EX/MEM record m\_packet\_t**

| Field | Count | Width each | Classification |
| :---- | :---- | :---- | :---- |
| valid | 1 | 1 | Bundle |
| pc | 1 | 32 | Bundle |
| next\_pc | 1 | 32 | Bundle/control |
| active | 4 | 1 | Slot |
| rd | 4 | 5 | Slot |
| wen | 4 | 1 | Slot; already suppresses x0 |
| result | 4 | 32 | ALU result or JAL link |
| load | 1 | 1 | S0 |
| store | 1 | 1 | S0 |
| addr | 1 | 32 | Memory |
| store\_data | 1 | 32 | Memory |
| branch\_taken | 1 | 1 | Control |

Total: **388 bits**.

Faulting bundles never enter EX/MEM. Consequently this record has no fault field. Fault metadata is captured by pipeline\_control, avoiding contradictory “faulted but valid memory operation” states.

## **7.8 MEM/WB record w\_packet\_t**

Same fields, order, and width as m\_packet\_t: **388 bits**.

For a load, result\[0\] is not the final load value. writeback\_unit selects dmem\_rdata instead.

The memory address and store data are retained for retirement tracing and verification.

## **7.9 Producer record producer\_t**

| Field | Width | Meaning |
| :---- | :---- | :---- |
| valid | 1 | Actual nonzero register destination |
| rd | 5 | Destination |
| ready | 1 | Data can be forwarded now |
| data | 32 | Forwarding value |

Total: **39 bits**.

Four MEM producers and four WB producers are supplied to forwarding.

## **7.10 Pipeline storage update rule**

Applies to IF/ID, ID/EX, EX/MEM, and MEM/WB:

| Priority | Condition | Next state |
| :---- | :---- | :---- |
| 1 | rst\_n=0 | Entire record zero |
| 2 | clear\_i=1 | Entire record zero |
| 3 | load\_i=1 | Capture packet\_i |
| 4 | Otherwise | Hold current record |

In P1, ID/EX, EX/MEM, and MEM/WB normally load every cycle, including invalid bubble records. Only IF/ID needs routine holding.

# **8\. Register file, forwarding, and hazards**

## **8.1 Register-file behavior**

| Property | Contract |
| :---- | :---- |
| Storage | 32 words × 32 bits |
| Read ports | Eight asynchronous/combinational reads |
| Write ports | Four rising-edge writes |
| Reset | All stored words zero |
| x0 | Reads zero; writes ignored |
| Same-edge read/write | Explicit write-through bypass |
| Two enabled writes to same nonzero register | Internal protocol violation; suppress the entire write group and assert collision\_o |
| Valid write group | All enabled distinct destinations update on the same edge |

For read port p:

1\. If address is zero, return zero.

2\. If a noncolliding enabled WB port matches, return its write data.

3\. Otherwise return the stored register value.

The core must ensure collisions never reach the register file during legal execution. collision\_o is an assertion/debug signal, not an architectural fault mechanism.

## **8.2 Forwarding matrix**

Each cell applies to both source operands.

| Producer lane → consumer lane | S0 | S1 | S2 | S3 |
| :---- | :---- | :---- | :---- | :---- |
| S0 | M/W | M/W | M/W | M/W |
| S1 | M/W | M/W | M/W | M/W |
| S2 | M/W | M/W | M/W | M/W |
| S3 | M/W | M/W | M/W | M/W |

For each EX source:

1\. Unused source → zero.

2\. rs=0 → zero.

3\. Match a MEM producer:

   \- Ready → use MEM value.

   \- Not ready → report blocked; **do not fall back to WB**.

4\. Otherwise match a WB producer → use WB value.

5\. Otherwise use the operand captured in ID/EX.

MEM is younger than WB and therefore has priority.

| Producer | Ready in MEM | Ready in WB |
| :---- | :---- | :---- |
| ALU/ADDI/LUI/JAL | Yes | Yes |
| LW | No | Yes |
| SW/branch/NOP/HALT | No producer | No producer |

Forwarded source B feeds both the ALU register operand and store-data path. Forwarded sources A/B feed branch comparison.

## **8.3 Exact load-use stall condition**

Let the load in EX have destination L.

stall\_D \=  
    D.valid  
    AND E.valid  
    AND NOT E.fault.valid  
    AND E.S0.mem\_op \== LW  
    AND E.S0.rd \!= 0  
    AND any actually used D source equals E.S0.rd  
If D already contains an encoding/bundle/fetch fault, skip operand waiting and issue its fault token, subject to older EX events.

The stall holds D, inserts an invalid E record, and allows the load and all older work to advance.

A load currently in MEM does not require another decode stall: it will be ready in WB when the consumer reaches EX.

forward\_unit.blocked\_o must remain zero for valid EX work if the interlock is correct. It is an assertion check, not an additional EX stall path.

## **8.4 Other hazards**

| Hazard | P1 treatment |
| :---- | :---- |
| Cross-bundle RAW | Forwarding plus load-use interlock |
| Same-bundle RAW/WAR overlap | Bundle rejection |
| Same-bundle duplicate destination | Bundle rejection |
| Cross-bundle WAR | In-order operand capture precedes younger writes |
| Cross-bundle WAW | All bundles retain in-order WB |
| Memory ordering | One path; operations remain in bundle order |
| Branch/store operand dependency | Same source-use and forwarding rules as ALU |
| Structural slot conflict | Bundle rejection |
| Variable-latency unit | Not present |

# **9\. Fetch, branch, and pipeline-control rules**

## **9.1 Fetch response holding state**

VLIW\_Core owns:

• f\_valid\_q

• f\_pc\_q

• f\_fault\_q

IMEM owns the matching registered rdata\_q.

When no new request is accepted, IMEM retains its output. Thus these states form one held response.

A response can move into IF/ID at the same edge that IMEM accepts the next request. IF/ID samples the **old** RAM output; IMEM produces the next output after the edge.

## **9.2 Combinational control terms**

run          \= mode \== RUN  
event\_E      \= valid EX branch/JAL resolution, HALT, or fault  
barrier\_D    \= D.valid AND  
               (D has fault OR bundle illegal OR  
                S0 is BEQ/BNE/JAL/HALT)

issue\_D      \= run AND D.valid AND NOT stall\_D AND NOT event\_E  
space\_D      \= NOT D.valid OR issue\_D

move\_F\_D     \= run AND F.valid AND space\_D  
               AND NOT barrier\_D AND NOT event\_E

space\_F      \= NOT F.valid OR move\_F\_D

create\_F     \= run AND space\_F  
               AND NOT barrier\_D AND NOT event\_E  
create\_F creates either:

• A normal IMEM request plus fetch metadata, or

• A fetch-fault token if the PC is invalid.

imem\_req\_o \= create\_F AND fetch\_address\_valid.

No memory access occurs for a fetch-fault token.

## **9.3 Stage movement**

| State | Normal rule |
| :---- | :---- |
| PC | Advance by 16 when create\_F; hold otherwise |
| F | Capture new request metadata; otherwise clear if moved to D; otherwise hold |
| D | Capture F when moved; otherwise clear when issued; otherwise hold |
| E | Capture D when issued; otherwise load invalid bubble |
| M | Capture nonfaulting, non-HALT E; otherwise load invalid bubble |
| W | Capture M every cycle |
| RF | Apply valid W writes |

When D is a barrier, clear any younger F response and stop new fetches. The barrier can wait for operands without allowing younger work to issue.

## **9.4 Branch resolution**

BEQ/BNE/JAL resolve during EX.

BEQ taken \= A \== B  
BNE taken \= A \!= B  
JAL taken \= true

taken target \= U32(E.pc \+ E.S0.imm)  
not-taken next\_pc \= U32(E.pc \+ 16\)  
Only a taken branch or JAL validates its encoded target. An untaken branch does not fault because its unused target is misaligned or outside memory.

At a valid control resolution:

1\. Clear younger F and D.

2\. Set fetch PC to resolved next PC.

3\. Allow the branch/JAL into M.

4\. Resume fetching on the following cycle.

For JAL, result\[0\]=U32(E.pc+16).

## **9.5 Priority is based on instruction age**

A younger decode error or HALT must not override an older EX branch/fault.

| Priority | Event | Action |
| :---- | :---- | :---- |
| 1 | Reset | Clear control and pipeline state; suppress effects |
| 2 | Valid EX fault | Kill faulting bundle and younger work; drain older M/W |
| 3 | Valid EX HALT | Kill HALT and younger work; drain older M/W |
| 4 | Valid EX branch/JAL resolution | Redirect and clear younger work |
| 5 | Existing drain/STOP mode | No new issue or fetch |
| 6 | Decode load-use stall | Hold D; bubble E; advance older work |
| 7 | Normal | Advance according to space equations |

Decode faults and HALT are carried into EX before initiating terminal handling. This makes event ordering explicit.

# **10\. HALT, faults, and retirement**

## **10.1 Fault codes**

These numeric assignments are an **IMPLEMENTATION CHOICE** for diagnostics under P1.

| Code | Name | Detection |
| :---- | :---- | :---- |
| 0 | NONE | No fault |
| 1 | ILLEGAL\_ENCODING | Unsupported 32-bit word |
| 2 | ILLEGAL\_SLOT | Valid operation in unsupported slot |
| 3 | CONTROL\_PARTNER | Non-NOP partner of control/HALT |
| 4 | DUPLICATE\_DEST | Multiple writes to nonzero destination |
| 5 | CROSS\_SLOT\_DEP | Cross-slot write/read overlap |
| 6 | FETCH\_ALIGN | Invalid fetch-PC alignment |
| 7 | FETCH\_RANGE | Invalid fetch-PC range |
| 8 | DATA\_ALIGN | Invalid LW/SW alignment |
| 9 | DATA\_RANGE | Invalid LW/SW range |
| A | TARGET\_ALIGN | Invalid taken control target alignment |
| B | TARGET\_RANGE | Invalid taken control target range |
| C…F | Reserved | Must not be emitted |

Within one bundle:

1\. Existing fetch fault has priority.

2\. Encoding error.

3\. Slot error.

4\. Control-partner error.

5\. Duplicate destination.

6\. Cross-slot dependency.

7\. Runtime alignment before runtime range.

fault\_slots is the union of participating slots for the selected fault category. Fetch faults use 0000; S0 runtime faults use 0001.

## **10.2 Fault behavior**

A fault token reaches EX in program order. During that EX interval:

• It must generate no memory request.

• It must generate no register writes.

• It must not enter M as valid work.

• Younger F/D work is discarded.

• Older M/W bundles continue.

On the event edge, capture diagnostic fields and enter DRAIN\_FAULT.

faulted becomes one only at an edge where drain mode is active and **E, M, and W are already invalid before the edge**. Then enter STOP.

This deliberately conservative drain rule may add one empty cycle but removes ambiguity about final effects.

## **10.3 HALT behavior**

HALT is recognized in D as a barrier and handled in EX.

At the HALT event edge:

• Stop fetch and issue.

• Discard younger work.

• Save the HALT bundle PC.

• Enter DRAIN\_HALT.

• Do not send HALT to M.

When E/M/W are empty before an edge, set halted=1, enter STOP, and hold architectural PC at the HALT address.

A normal HALT does not set faulted.

## **10.4 Retirement and architectural PC**

A normal W bundle retires at the edge where its GPR writes occur. Retirement applies even to all-NOP and branch bundles.

At retirement:

architectural\_pc \= W.next\_pc  
During terminal completion:

architectural\_pc \= saved HALT/fault PC  
Stores physically update RAM one edge before retirement. This is permitted only because P1 has no external memory observer, no late memory errors, and all younger faults preserve older stores.

If externally visible atomic bundle commit becomes required, D10 must change.

# **11\. Complete module-interface specification**

## **11.1 Common interface rules**

Every port listed below is part of the contract.

• \_i: input.

• \_o: output.

• All stateful modules use clk\_i and active-low rst\_n.

• Reset assertion is asynchronous; release is synchronized by reset\_sync.

• Unless otherwise stated, control/data ports use the core clock domain.

• Combinational modules have no internal registers and no independent reset/stall/flush behavior.

• Wrappers own no hidden state beyond explicitly listed child modules and local state.

• Illegal architectural instructions are handled through decode/fault records.

• Broken internal protocols are assertion failures, not silently reinterpreted instructions.

## **11.2 vliw\_pkg**

This is a package, not a module. It has **no ports or state**.

It defines:

• All constants and enums in Section 7\.

• fault\_t, decode\_t, d\_packet\_t, e\_packet\_t, m\_packet\_t, w\_packet\_t, and producer\_t.

• XLEN=32, LANES=4, REG\_COUNT=32, BUNDLE\_BITS=128.

• NOP\_WORD=0x00000013, proposed HALT\_WORD=0x0000000B.

• Memory-depth parameter names and diagnostic codes.

## **11.3 Program\_Counter**

| Signal | Dir | Width | Meaning/timing |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| redirect\_i | In | 1 | Replace PC at edge |
| redirect\_pc\_i | In | 32 | Redirect/terminal address |
| step\_i | In | 1 | Advance one bundle at edge |
| pc\_o | Out | 32 | Current fetch address |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| pc\_q | 32 | 0 | Redirect or step | Redirect address wins; otherwise U32(pc\_q+16); otherwise hold |

The core checks address validity; this module stores the requested value without masking alignment bits.

## **11.4 IF\_ID\_reg**

| Signal | Dir | Width | Meaning/timing |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| clear\_i, load\_i | In | 1 each | Section 7.10 priority |
| packet\_i | In | 202 | Next D record |
| packet\_o | Out | 202 | Stored D record |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| packet\_q | 202 | All zero | Clear/load | Section 7.10 |

## **11.5 main\_decoder**

| Signal | Dir | Width | Meaning/timing |
| :---- | :---- | :---- | :---- |
| instr\_i | In | 32 | Complete operation |
| tag\_o | Out | 5 | Instruction identity |
| legal\_o | Out | 1 | Exact supported encoding |

Tag assignments:

0 NOP, 1 ADD, 2 SUB, 3 AND, 4 OR, 5 XOR, 6 SLT,  
7 SLL, 8 SRL, 9 ADDI, 10 LUI, 11 LW, 12 SW,  
13 BEQ, 14 BNE, 15 JAL, 16 HALT, 31 INVALID.  
No state. Match Section 3 exactly. Any unmatched word produces tag=31, legal=0.

## **11.6 ALU\_decoder**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| tag\_i | In | 5 | Decoded identity |
| alu\_op\_o | Out | 4 | ALU selection |

No state.

• Arithmetic tags map to their named operation.

• LUI maps to PASS\_B.

• ADDI/LW/SW map to ADD.

• Branch/JAL targets are calculated separately in the core.

• NOP, HALT, invalid, and other unused tags output ADD; associated validity prevents effects.

## **11.7 Imm\_Gen**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| instr\_i | In | 32 | Encoded operation |
| imm\_sel\_i | In | 3 | I/S/B/U/J/NONE |
| imm\_o | Out | 32 | Expanded immediate |

No state. Implements Section 3.3. NONE or reserved selector outputs zero.

## **11.8 control\_unit**

Four instances.

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| instr\_i | In | 32 | One slot operation |
| dec\_o | Out | 62 | Complete decode\_t |

No state. Instantiates main\_decoder, ALU\_decoder, and Imm\_Gen.

Mapping:

| Tag class | Sources | write\_rd | b\_imm | Memory/control |
| :---- | :---- | :---- | :---- | :---- |
| Register ALU | A/B | 1 | 0 | None |
| ADDI | A | 1 | 1 | None |
| LUI | None | 1 | 1 | None |
| LW | A | 1 | 1 | LW |
| SW | A/B | 0 | 1 | SW |
| BEQ/BNE | A/B | 0 | 0 | Matching control |
| JAL | None | 1 | 0 | JAL |
| HALT | None | 0 | 0 | halt=1 |
| NOP | None | 0 | 0 | active=0 |

active=1 for every supported non-NOP operation, even when its destination is x0. Slot legality is checked separately.

## **11.9 bundle\_checker**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| dec\_i | In | 4 × 62 | Four decoded slots |
| fault\_o | Out | 41 | Static bundle fault or zero |

No state. Implements B01–B10 and fault-category priority. It examines actual source-use flags, not every encoded register field.

## **11.10 RegisterFile**

| Signal | Dir | Width | Meaning/timing |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| raddr\_i | In | 8 × 5 | Read addresses |
| rdata\_o | Out | 8 × 32 | Combinational values with WB bypass |
| wen\_i | In | 4 × 1 | Write enables |
| waddr\_i | In | 4 × 5 | Destinations |
| wdata\_i | In | 4 × 32 | Values captured at edge |
| collision\_o | Out | 1 | Duplicate nonzero enabled destination |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| regs\_q\[0\] | 32 | 0 | Never | Zero |
| regs\_q\[1…31\] | 31 × 32 | 0 | Matching write and no collision | Selected write value; otherwise hold |

Collision behavior is defined in Section 8.1.

## **11.11 ID\_EX\_reg**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| clear\_i, load\_i | In | 1 each | Register control |
| packet\_i | In | 578 | Next E record |
| packet\_o | Out | 578 | Stored E record |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| packet\_q | 578 | Zero | Clear/load | Section 7.10 |

## **11.12 forward\_unit**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| src\_used\_i | In | 8 | Operand-use flags |
| src\_addr\_i | In | 8 × 5 | EX source registers |
| src\_saved\_i | In | 8 × 32 | ID/EX captured operands |
| m\_prod\_i | In | 4 × 39 | MEM producers |
| w\_prod\_i | In | 4 × 39 | WB producers |
| operand\_o | Out | 8 × 32 | Forwarded operands |
| blocked\_o | Out | 8 | Matching youngest producer not ready |
| select\_o | Out | 8 × 4 | Debug selection |

Selection encoding:

0 \= saved operand or forced zero  
1…4 \= MEM lane 0…3  
5…8 \= WB lane 0…3  
9 \= blocked  
10…15 \= reserved  
No state. On blocked input, return zero and assert blocked. The core asserts that a valid executing bundle is never blocked.

## **11.13 hazard\_detect**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| d\_valid\_i | In | 1 | D contains work |
| d\_fault\_i | In | 1 | D already faulting |
| d\_dec\_i | In | 4 × 62 | D source-use information |
| e\_valid\_i | In | 1 | E contains work |
| e\_fault\_i | In | 1 | E already faulting |
| e\_load\_i | In | 1 | E S0 is LW |
| e\_rd\_i | In | 5 | Load destination |
| stall\_o | Out | 1 | Whole-bundle decode stall |
| match\_o | Out | 8 | Matching source mask |

No state. Implements Section 8.3 exactly.

## **11.14 ALU**

Four instances.

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| alu\_op\_i | In | 4 | Operation selector |
| a\_i, b\_i | In | 32 each | Operands |
| result\_o | Out | 32 | Combinational result |

No state. Arithmetic implements Section 2\.

Unsupported selector returns zero and triggers a simulation assertion when used by valid active work. Existing unused ALU functions may remain physically implemented, but the decoder must not expose them as supported ISA operations.

## **11.15 Branch\_Comp**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| a\_i, b\_i | In | 32 each | Forwarded S0 register values |
| eq\_o | Out | 1 | a\_i \== b\_i |

No state. Only equality is required by the selected ISA. The old less-than output can be removed or retained as an unused implementation detail.

## **11.16 Branch\_Resolve**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| ctrl\_op\_i | In | 2 | NONE/BEQ/BNE/JAL |
| eq\_i | In | 1 | Comparison result |
| is\_control\_o | Out | 1 | Control instruction |
| taken\_o | Out | 1 | Taken decision |

No state.

| ctrl\_op | is\_control | taken |
| :---- | :---- | :---- |
| NONE | 0 | 0 |
| BEQ | 1 | eq |
| BNE | 1 | \!eq |
| JAL | 1 | 1 |

The core computes target and checks its address.

## **11.17 EX\_MEM\_reg**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| clear\_i, load\_i | In | 1 each | Register control |
| packet\_i | In | 388 | Next M record |
| packet\_o | Out | 388 | Stored M record |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| packet\_q | 388 | Zero | Clear/load | Section 7.10 |

An EX fault/HALT produces an invalid input record. An older valid M record must still advance to W.

## **11.18 load\_store\_unit**

P1 uses a combinational LSU; the memories hold response state.

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| e\_valid\_i | In | 1 | Valid EX candidate |
| e\_mem\_op\_i | In | 2 | NONE/LW/SW |
| e\_addr\_i | In | 32 | Computed effective address |
| e\_fault\_o | Out | 41 | Alignment/range fault |
| m\_valid\_i | In | 1 | Valid accepted M bundle |
| m\_load\_i, m\_store\_i | In | 1 each | Memory class |
| m\_addr\_i, m\_store\_data\_i | In | 32 each | M request data |
| req\_o | Out | 1 | Memory request for current edge |
| write\_o | Out | 1 | Store when request asserted |
| addr\_o, wdata\_o | Out | 32 each | Byte address and word data |

Parameter: DMEM\_WORDS.

No internal state. req\_o \= m\_valid\_i AND (m\_load\_i OR m\_store\_i) while reset is released. write\_o \= req\_o AND m\_store\_i.

The core supplies zero/invalid M inputs while reset is active. Both load and store asserted is an internal assertion failure; suppress the request.

## **11.19 MEM\_WB\_reg**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| clear\_i, load\_i | In | 1 each | Register control |
| packet\_i | In | 388 | Metadata/results from M |
| packet\_o | Out | 388 | W metadata/results |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| packet\_q | 388 | Zero | Clear/load | Section 7.10 |

There is deliberately no registered load-data input. Load data arrives from DMEM’s registered output in the W interval.

## **11.20 writeback\_unit**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| rst\_n | In | 1 | Suppress effects during reset |
| packet\_i | In | 388 | W record |
| load\_data\_i | In | 32 | Registered DMEM result |
| wen\_o | Out | 4 | Final write enables |
| waddr\_o | Out | 4 × 5 | Destinations |
| wdata\_o | Out | 4 × 32 | Final values |
| producer\_o | Out | 4 × 39 | WB forwarding records |
| retire\_o | Out | 388 | Retirement record with final result values |

No state.

• wdata\[0\] \= load\_data when W is load; otherwise W result.

• Other lanes use W result.

• wen\[s\] \= rst\_n AND W.valid AND W.wen\[s\] AND rd\[s\]\!=0.

• retire.valid \= rst\_n AND W.valid.

• retire.result\[\] contains final writeback data.

• Every valid WB producer is ready.

## **11.21 pipeline\_control**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| f\_valid\_i, d\_valid\_i | In | 1 each | Frontend occupancy |
| d\_barrier\_i | In | 1 | D fault/control/HALT barrier |
| d\_stall\_i | In | 1 | Load-use stall |
| e\_valid\_i, m\_valid\_i, w\_valid\_i | In | 1 each | Drain occupancy |
| e\_control\_i | In | 1 | Valid nonfaulting branch/JAL event |
| e\_next\_pc\_i | In | 32 | Resolved next PC |
| e\_terminal\_i | In | 2 | NONE/HALT/FAULT event |
| e\_pc\_i | In | 32 | Event bundle address |
| e\_fault\_i | In | 41 | Selected fault |
| create\_f\_o, move\_f\_d\_o, issue\_d\_o | Out | 1 each | Section 9 equations |
| clear\_f\_o, clear\_d\_o | Out | 1 each | Discard frontend work |
| redirect\_o | Out | 1 | PC replacement |
| redirect\_pc\_o | Out | 32 | Branch next PC or terminal PC |
| mode\_o | Out | 2 | RUN/drain/STOP |
| halted\_o, faulted\_o | Out | 1 each | Sticky terminal status |
| stop\_pc\_o | Out | 32 | HALT/fault bundle PC |
| fault\_o | Out | 41 | Saved diagnostic record |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| mode\_q | 2 | RUN | Event/drain completion | State transitions below |
| stop\_pc\_q | 32 | 0 | Terminal event | EX PC |
| fault\_q | 41 | 0 | Fault event | Selected EX fault |
| halted\_q | 1 | 0 | Empty HALT drain | Set 1 |
| faulted\_q | 1 | 0 | Empty fault drain | Set 1 |

Transitions:

RUN \+ FAULT event → DRAIN\_FAULT  
RUN \+ HALT event  → DRAIN\_HALT  
RUN \+ control    → RUN, redirect  
DRAIN\_\* \+ E/M/W empty → STOP  
STOP → STOP until reset  
Branch control events and terminal events are mutually exclusive after fault selection.

## **11.22 IMEM**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i | In | 1 | Read clock |
| req\_i | In | 1 | Accept read at edge |
| addr\_i | In | 32 | Valid bundle byte address |
| rdata\_o | Out | 128 | Registered result; holds without request |

Parameters: IMEM\_BUNDLES, IMEM\_INIT\_FILE.

| State | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| memory\[\] | Depth × 128 | No core reset | Image loading only | Initialized from image |
| rdata\_q | 128 | Unspecified | req\_i | memory\[addr\_i\>\>4\]; otherwise hold |

No rst\_n port is required. Fetch metadata validity is reset, so an unspecified output register is never consumed as valid work.

Invalid requests violate the internal interface and must assert in simulation. Address faults are generated before requests reach IMEM.

## **11.23 DMEM**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i | In | 1 | Access clock |
| req\_i | In | 1 | Accept one access at edge |
| write\_i | In | 1 | Store rather than load |
| addr\_i | In | 32 | Checked byte address |
| wdata\_i | In | 32 | Full-word store data |
| rdata\_o | Out | 32 | Registered load result |

Parameters: DMEM\_WORDS, DMEM\_INIT\_FILE.

| State | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| memory\[\] | Depth × 32 | No core reset | req && write | Selected word=wdata |
| rdata\_q | 32 | Unspecified | req && \!write | Selected word; otherwise hold |

A store does not update rdata\_q. One port cannot load and store on the same edge.

## **11.24 performance\_counters**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Clock/reset |
| run\_enable\_i | In | 1 | Count elapsed execution |
| issue\_i | In | 1 | Bundle accepted into E |
| retire\_i | In | 388 | Successful retired bundle |
| stall\_i | In | 1 | Decode dependency stall |
| control\_redirect\_i | In | 1 | Completed branch/JAL resolution |
| taken\_i | In | 1 | Redirect represents taken transfer |
| counter\_o | Out | 8 × 64 | Counter values |

| Index/register | Width | Reset | Increment condition/value |
| :---- | :---- | :---- | :---- |
| 0 cycles\_q | 64 | 0 | run\_enable: \+1 |
| 1 issued\_q | 64 | 0 | issue: \+1 |
| 2 retired\_q | 64 | 0 | retire.valid: \+1 |
| 3 useful\_q | 64 | 0 | Retirement: popcount(active) |
| 4 stall\_q | 64 | 0 | stall: \+1 |
| 5 load\_stall\_q | 64 | 0 | Same as stall in P1 |
| 6 taken\_q | 64 | 0 | control\_redirect && taken: \+1 |
| 7 memory\_q | 64 | 0 | Retirement with load/store: \+1 |

All counters wrap modulo 2^64. No software reset or read instruction.

cycles includes fetch fill, stalls, and drain, through the edge that sets terminal status. It stops on following edges.

Useful operations exclude exact NOP and HALT. Branches, stores, and active instructions writing x0 count when retired. Faulting bundles do not count as useful.

## **11.25 VLIW\_Core**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Core clock/reset |
| imem\_req\_o | Out | 1 | Synchronous fetch request |
| imem\_addr\_o | Out | 32 | Bundle byte address |
| imem\_rdata\_i | In | 128 | Held synchronous response |
| dmem\_req\_o, dmem\_write\_o | Out | 1 each | Data request |
| dmem\_addr\_o, dmem\_wdata\_o | Out | 32 each | Data request payload |
| dmem\_rdata\_i | In | 32 | Synchronous load result |
| halted\_o, faulted\_o | Out | 1 each | Terminal status |
| fault\_pc\_o | Out | 32 | Fault address in program |
| fault\_o | Out | 41 | Diagnostics |
| arch\_pc\_o | Out | 32 | Committed/terminal PC |
| retire\_o | Out | 388 | Retirement record |
| issue\_o, stall\_o | Out | 1 each | Measurement events |
| control\_redirect\_o, taken\_o | Out | 1 each | Control events |

Parameters: IMEM\_BUNDLES, DMEM\_WORDS.

Additional local state:

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| f\_valid\_q | 1 | 0 | Clear/create/move | Clear wins; create sets 1; move without create clears |
| f\_pc\_q | 32 | 0 | create\_F | Current fetch PC |
| f\_fault\_q | 41 | 0 | Clear/create | Checked fetch fault or zero |
| arch\_pc\_q | 32 | 0 | Terminal completion or retirement | Terminal PC wins; otherwise W next PC |

Other state belongs to the instantiated modules.

Core combinational wiring also owns:

• PC+16 and control-target addition.

• Selection of runtime fault versus carried fault.

• ALU operand muxes.

• MEM producer construction.

• Assembly of E/M records.

• Suppression of side effects during reset.

## **11.26 VLIW\_System**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i, rst\_n | In | 1 each | Synchronized system clock/reset |
| halted\_o, faulted\_o | Out | 1 each | Core status |
| fault\_pc\_o | Out | 32 | Fault PC |
| fault\_o | Out | 41 | Fault diagnostics |
| arch\_pc\_o | Out | 32 | Debug PC |
| counter\_o | Out | 8 × 64 | Counters |
| retire\_o | Out | 388 | Verification/debug trace |

Parameters: memory depths and image filenames.

No local sequential state. Instantiates VLIW\_Core, IMEM, DMEM, and counters. Memory-depth parameters must be identical across core and memories.

## **11.27 reset\_sync**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i | In | 1 | Core clock |
| arst\_n\_i | In | 1 | External asynchronous active-low reset |
| rst\_n\_o | Out | 1 | Asynchronous assertion, synchronized release |

| Register | Width | Reset | Enable | Next-state rule |
| :---- | :---- | :---- | :---- | :---- |
| sync1\_q | 1 | 0 | Every rising edge | 1 |
| sync2\_q | 1 | 0 | Every rising edge | Previous sync1\_q |

rst\_n\_o=sync2\_q. Synchronizer placement attributes are an implementation choice.

## **11.28 FPGA\_Top**

| Signal | Dir | Width | Meaning |
| :---- | :---- | :---- | :---- |
| clk\_i | In | 1 | Board clock used directly |
| reset\_n\_i | In | 1 | External reset |
| halted\_o, faulted\_o | Out | 1 each | Status pins/debug signals |
| fault\_code\_o | Out | 4 | Fault code |

No local state beyond reset\_sync and VLIW\_System.

Clock pin, clock period, reset polarity adaptation, FPGA part, and physical status-pin assignments remain board decisions. A PLL, UART, or host loader is not silently included.

# **12\. Connection ownership table**

| Producer | Consumer | Connection |
| :---- | :---- | :---- |
| Program\_Counter | Core fetch checker, IMEM | Current byte PC |
| IMEM \+ core F metadata | IF\_ID\_reg | Matching bundle and PC |
| IF\_ID\_reg | Four control units, bundle checker | Encoded operations |
| Control units | RegisterFile | Eight source addresses |
| RegisterFile | ID\_EX\_reg | WB-bypassed operands |
| ID\_EX\_reg | Forwarding, ALUs, branch logic, LSU checks | EX work |
| EX\_MEM\_reg | Forwarding | Four MEM producers |
| Writeback unit | Forwarding and RegisterFile | Four final WB values |
| Forwarding | ALUs, branch comparator, store data | Resolved source values |
| LSU EX checker | Core fault selection | Runtime memory fault |
| Branch resolver \+ core target checker | Pipeline control | Control event or target fault |
| EX\_MEM\_reg | LSU request path and MEM\_WB\_reg | Memory request and metadata |
| DMEM output | Writeback unit | Load data aligned with W |
| Writeback unit | RegisterFile, counters, trace | Writes and retirement |
| Pipeline control | PC, F/D controls, issue gating | Advance/kill/drain decisions |

No module may independently invent a second stall or flush policy.

# **14\. Assembler, scheduler, and reference-model Contracts**

## **14.1 Assembly syntax**

| Item | Contract |
| :---- | :---- |
| Registers | x0 through x31; no ABI aliases initially |
| Mnemonics | Case-insensitive |
| Labels | Case-sensitive; identifier starts with letter or underscore |
| Comments | \# to end of line |
| Numbers | Signed decimal or 0x hexadecimal |
| Register ALU | ADD rd, rs1, rs2 |
| Immediate | ADDI rd, rs1, imm |
| LUI | LUI rd, imm20; accepted raw field 0…0xFFFFF |
| Load | LW rd, offset(rs1) |
| Store | SW rs2, offset(rs1) |
| Branch | BEQ rs1, rs2, label |
| Jump | JAL rd, label |
| NOP/HALT | No operands |
| Manual bundle | { op0 | op1 | op2 | op3 } |

No implicit slot filling in manual mode: all four operations must be written.

A source file selects either sequential scheduling mode or manual-bundle mode. Mixing modes is rejected.

Branch/JAL numeric operands, if supported, mean **signed byte displacements**, never bundle counts. No pseudo-instructions other than NOP are required.

## **14.2 Output formats**

| Output | Contents |
| :---- | :---- |
| Instruction image | One 128-bit hexadecimal bundle per line |
| Data image | One 32-bit hexadecimal word per line |
| Listing | Bundle PC, slot number, instruction word, source line |
| Label map | Label to final bundle byte address |
| Diagnostics | Filename, line, slot where applicable, error category |

Unspecified instruction locations are filled with all-NOP bundles. Unspecified data words are zero-filled in the generated image.

The assembler rejects:

• Unsupported instructions.

• Operand-count/type errors.

• Out-of-range immediates.

• Undefined/duplicate labels.

• Misaligned or out-of-range static control targets.

• Illegal bundles.

## **14.3 Scheduler**

The first scheduler guarantees legal schedules, not optimal schedules.

It must:

1\. Split source into basic blocks.

2\. Preserve RAW, WAR, and WAW dependencies.

3\. Preserve all memory-operation ordering.

4\. Keep branch/JAL/HALT at block boundaries.

5\. Respect slot capabilities.

6\. Use ALU spacing 1 and load spacing 2 under P1.

7\. Emit exact NOPs for unused slots.

8\. Recalculate labels after bundle formation.

9\. Run an independent legality/timing checker.

For initial fault-sensitive testing, use manual bundles. Reordering operations before a fault can change which earlier source operations have executed; arbitrary scalar fault-state equivalence must not be assumed.

## **14.4 Reference models**

| Model | Required behavior |
| :---- | :---- |
| Sequential source model | Validate normal algorithm results before scheduling |
| Bundle architectural model | Validate encodings, bundle rules, simultaneous reads, target/address checks, HALT, and faults |
| RTL comparison | Compare final GPRs, full data memory, terminal status, and terminal PC |
| Retirement comparison | Compare successful bundles and final write values in order |

The bundle model validates all effects before modifying architectural state. This is the oracle for faulting bundles.

For JAL and label-dependent programs, the source model must use the assembler’s final bundle-address mapping when comparing link values.

# **15\. Verification and acceptance tables**

| Area | Required checks |
| :---- | :---- |
| Encoding | Every supported instruction; all excluded funct3/funct7 combinations |
| ALU | Zero, all ones, signed boundaries, wraparound, shifts 0/31 and high shift bits |
| Register file | Every read port, four distinct writes, x0, WB bypass, collision suppression |
| Bundle checker | Ten legal/illegal examples plus all slot permutations |
| Forwarding | Every producer lane to every consumer lane, both operands, M and W |
| Priority | Newer MEM producer overrides older WB producer |
| Loads | Consumer after 0/1/2 intervening bundles; load to x0 still faults when invalid |
| Stores | Forwarded address/data; exactly one physical write |
| Branches | Taken/not taken; dependent operands; no wrong-path effects |
| Fault age | Older EX fault versus younger HALT or illegal instruction |
| Fetch | Held response during D stall; consume old response while requesting next |
| Memory | Boundary addresses, misalignment, no address aliasing through truncation |
| HALT | Older load/store/ALU complete; no younger side effects |
| Reset | During execution and drain; no post-reset stale writes |
| Random programs | Fixed seeds; bundle model versus RTL |
| Scheduler | Independent schedule checker; final-state equivalence for legal nonfaulting programs |
| FPGA | Same images and outputs as simulation; post-route timing met |

Required assertions:

x0 always reads zero.  
Invalid W cannot write a register.  
Invalid M cannot request memory.  
Faulting E cannot produce valid M.  
A flushed bundle cannot retire.  
Enabled nonzero WB destinations are distinct.  
Valid EX work never has blocked forwarding operands.  
Every accepted store causes exactly one memory write.  
A load response is paired with its own W metadata.  
HALT/fault status implies E, M, and W are empty.  
STOP produces no fetch, issue, store, or register write.  
Acceptance requires all directed tests and a documented seeded-random regression to pass. FPGA acceptance additionally requires a named device, clock constraint, verified operating frequency, and reproducible program/data images.

Performance reporting must include elapsed cycles, useful operations, stalls, code bytes, LUTs, FFs, BRAMs, DSPs, and post-route timing.

Useful IPC \= useful retired operations / cycles  
Slot utilization \= useful retired operations / (4 × cycles)  
Execution time \= cycles / operating frequency  
Speedup \= scalar execution time / VLIW execution time  
The scalar comparison must use the same workload and data, equivalent operation semantics, and clearly documented memory timing. Run both at a common safe frequency and also report each at its own verified frequency.

