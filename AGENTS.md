# VLIW Implementation Agent Rules

## 1. Project Mission

You are implementing a **4-Issue VLIW Processor** in SystemVerilog according to the provided implementation specification.

Your primary goals:

- Build a functionally correct VLIW CPU.
- Follow the specification exactly before optimizing.
- Preserve architectural behavior and timing contracts.
- Avoid introducing unsupported ISA features.
- Prioritize correctness, verification, and maintainability.

Do not redesign the architecture unless explicitly requested.

---

# 2. Source of Truth

The specification document is the highest authority.

When making implementation decisions:

1. Follow the specification.
2. Do not rely on assumptions from standard RISC-V behavior if they conflict with this project.
3. Do not add features outside the defined ISA.
4. If something is ambiguous:
   - Prefer the simplest implementation.
   - Keep behavior deterministic.
   - Document the decision.

---

# 3. Required Project Structure

Maintain the expected organization:

```
vliw/
├── rtl/
│   ├── common/
│   ├── core/
│   ├── memory/
│   └── system/
├── tools/
├── tb/
├── programs/
├── scripts/
├── constraints/
├── docs/
└── build/
```

Do not randomly move files or merge modules.

Each module should have a clear responsibility.

---

# 4. Architecture Overview

The processor is:

- 32-bit architecture.
- 4 instruction slots per bundle.
- Bundle width: 128 bits.
- Slot numbering:

```
Slot 3 | Slot 2 | Slot 1 | Slot 0
127:96 | 95:64  | 63:32  | 31:0
```

Important:

- Slot 0 is the control/memory slot.
- Slots 1-3 cannot contain control-flow or memory instructions.
- A bundle is the unit of execution.
- PC advances by one bundle (16 bytes).

---

# 5. ISA Restrictions

Supported instructions only:

## Arithmetic

- ADD
- SUB
- AND
- OR
- XOR
- SLT
- SLL
- SRL

## Immediate

- ADDI
- LUI

## Memory

- LW
- SW

## Control

- BEQ
- BNE
- JAL
- HALT

## Special

- NOP

Do NOT implement:

- Multiplication
- CSR
- Interrupts
- JALR
- AUIPC
- Byte/halfword operations
- Unsupported immediate instructions

---

# 6. Encoding Rules

Instruction decoding must strictly validate:

- Opcode
- funct3
- funct7
- Exact NOP encoding
- Exact HALT encoding

Illegal instructions must not be partially decoded.

Important:

- `0x00000000` is illegal.
- Writing x0 does not make an instruction illegal.
- Only writes to x0 are ignored architecturally.

---

# 7. Bundle Legality Rules

Every bundle must pass legality checking.

Implement these rules:

## B01

Every slot must contain a legal instruction.

## B02

Only Slot 0 may contain:

- LW
- SW
- BEQ
- BNE
- JAL
- HALT

## B03

Control instructions require:

```
S1 = NOP
S2 = NOP
S3 = NOP
```

## B04

No two slots may write the same non-zero register.

## B05

No slot may read a register written by another slot in the same bundle.

## B06

x0 dependencies are ignored.

## B07

An instruction may read and write the same register internally.

## B08

All operands are captured before bundle writes occur.

## B09

No same-bundle forwarding.

## B10

Any violation rejects the entire bundle.

---

# 8. Pipeline Requirements

Pipeline stages:

```
Fetch
 ↓
IF/ID
 ↓
Decode/Register Read
 ↓
ID/EX
 ↓
Execute
 ↓
EX/MEM
 ↓
Memory
 ↓
MEM/WB
 ↓
Writeback
```

Maintain the timing contract.

Do not shorten or bypass pipeline stages unless explicitly requested.

---

# 9. Memory Rules

## Instruction Memory

- Synchronous.
- Bundle width = 128 bits.
- Holds output when no request occurs.
- Does not reset contents.

## Data Memory

- Word based.
- Little endian.
- Only LW/SW supported.

Address checks happen before RAM indexing.

Validate:

Fetch:

```
PC[3:0] == 0
PC < IMEM size
```

Data:

```
EA[1:0] == 0
EA < DMEM size
```

---

# 10. Register File Rules

Register file:

- 32 registers.
- 32-bit width.
- 8 read ports.
- 4 write ports.

Rules:

Register x0:

```
Read -> always 0
Write -> ignored
```

Same-cycle write/read requires write-through bypass.

If two writes target the same non-zero register:

- Suppress all writes.
- Raise collision signal.

---

# 11. Forwarding Rules

Forwarding priority:

1. MEM stage
2. WB stage
3. Stored operand

MEM has priority over WB.

Forward:

- ALU results
- ADDI results
- LUI results
- JAL link values

Load values are only available in WB.

---

# 12. Hazard Rules

Implement:

## RAW hazards

Solved by:

- Forwarding
- Load-use stall

## Load-use stall condition

A stall occurs when:

- Decode instruction uses a register.
- Execute stage contains LW.
- Destination register matches source register.
- Destination is not x0.

During stall:

- Hold decode.
- Insert bubble into execute.
- Allow older instructions to continue.

---

# 13. Control Flow Rules

Branches and JAL:

- Resolve in EX stage.
- Redirect fetch after resolution.

Branch:

```
taken target = PC + immediate
```

Not taken:

```
PC + 16
```

JAL:

Writes:

```
rd = PC + 16
```

---

# 14. HALT Behavior

HALT is not immediately stopping execution.

Required behavior:

1. Detect HALT.
2. Stop younger instructions.
3. Allow older instructions to finish.
4. Drain pipeline.
5. Assert halted.
6. Keep architectural PC at HALT address.

HALT must not enter memory stage.

---

# 15. Fault Handling

Faults must:

- Preserve older instructions.
- Kill younger instructions.
- Prevent side effects from the faulting instruction.
- Drain pipeline.
- Save diagnostic information.

Fault categories:

- Illegal encoding.
- Illegal slot usage.
- Control partner violation.
- Duplicate destination.
- Cross-slot dependency.
- Fetch alignment.
- Fetch range.
- Data alignment.
- Data range.
- Target alignment.
- Target range.

---

# 16. Coding Rules

When writing SystemVerilog:

## Always

- Use explicit widths.
- Avoid implicit casting.
- Assign every combinational output.
- Keep reset behavior deterministic.
- Use packages for shared definitions.

## Avoid

- Hidden state.
- Large monolithic always blocks.
- Magic numbers.
- Unsupported features.
- Changing interfaces.

---

# 17. Verification Strategy

Before adding optimizations:

1. Make unit tests pass.
2. Verify instruction decoding.
3. Verify bundle legality.
4. Verify pipeline movement.
5. Verify hazards.
6. Verify memory behavior.
7. Verify HALT/fault handling.

Create tests for:

- Legal bundles.
- Illegal bundles.
- Dependency hazards.
- Load-use stalls.
- Branch redirects.
- Memory faults.
- HALT draining.

---

# 18. Debugging Priority

When debugging failures:

Check in this order:

1. Instruction encoding.
2. Decoder output.
3. Bundle legality.
4. Pipeline valid bits.
5. Register forwarding.
6. Hazard detection.
7. Memory timing.
8. Retirement behavior.

Do not immediately modify multiple modules.

---

# 19. Implementation Philosophy

The implementation should be:

- Specification-driven.
- Modular.
- Easy to verify.
- Easy to debug.
- Deterministic.

Correctness is more important than performance.

Do not optimize until functional behavior is proven.