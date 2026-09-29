# 4-Issue VLIW Processor

A specification-driven project to build a 32-bit, four-issue Very Long Instruction Word (VLIW) processor in SystemVerilog, together with assembly tools, reference models, and verification tests.

Software groups independent operations into a 128-bit bundle. The processor executes bundles through an in-order pipeline, with up to four operations per bundle. The goal is a correct, reproducible implementation before performance optimization.

## Project status

The repository currently contains the specification and supporting documentation. The implementation directories are scaffolded, but RTL, software tools, testbenches, and build scripts are not yet present. Simulation and FPGA results are therefore not available, and there is no runnable build command yet.

## Start here

| Document | Read it to understand |
| --- | --- |
| [Architecture guide](docs/architecture.md) | How the major components fit together and how a bundle moves through the machine |
| [Implementation specification](SPEC.md) | Exact ISA semantics, encodings, timing, interfaces, fault rules, and acceptance requirements |
| [Verification plan](docs/verification.md) | How to bring up the implementation, compare results, and collect acceptance evidence |
| [Decision record](docs/decisions.md) | Which choices are already fixed and which implementation or board choices remain open |
| [Agent rules](AGENTS.md) | Repository-specific instructions for implementation agents |

Read the architecture guide for orientation, then the relevant sections of `SPEC.md` before implementing a component. **`SPEC.md` is the source of truth.** These supporting documents explain the project and its workflow; they do not replace its detailed contracts.

## What the processor does

- Executes four 32-bit instruction slots per bundle, advancing sequentially by 16 bytes.
- Provides 32 general-purpose registers; x0 always reads as zero.
- Supports a small integer ISA: register arithmetic/logic, ADDI, LUI, LW/SW, BEQ/BNE, JAL, NOP, and HALT.
- Reserves slot 0 for memory and control operations. Branches, jumps, and HALT require NOPs in the other slots.
- Uses synchronous instruction and data memories, forwarding, and a load-use interlock.
- Rejects illegal bundles as a whole and drains older work before reporting HALT or a fault.

Supported standard instructions use RV32I field layouts, but this is a custom bundle architecture, not a general-purpose RV32I core. Bundle addressing, JAL link values, slot restrictions, and HALT follow this project's specification. Multiplication, interrupts, CSRs, and byte/halfword accesses are outside the current scope.

## Repository layout

Paths below are relative to this repository's root; `vliw/` in the specification denotes the project root.

| Path | Intended contents |
| --- | --- |
| `rtl/common/` | Shared types and constants |
| `rtl/core/` | Datapath, pipeline registers, decode, hazards, and control |
| `rtl/memory/` | Synchronous instruction and data memories |
| `rtl/system/` | Core integration, counters, reset synchronization, and FPGA wrapper |
| `tools/` | Assembler, disassembler, scheduler, and reference models |
| `tb/` | Unit and integration testbenches and pipeline assertions |
| `programs/` | Instruction tests, pipeline tests, and benchmarks |
| `scripts/` | Regression, random-program generation, and FPGA build automation |
| `constraints/` | Device-specific pin and timing constraints |
| `docs/` | Architecture, verification, and decision guides |
| `build/` | Generated memory images, simulation outputs, and implementation results |

The exact module and tool breakdown is in `SPEC.md`, Section 1.

## Development path

1. Establish the shared definitions and instruction/bundle models from the specification.
2. Implement and test individual units before integrating the pipeline.
3. Verify synchronous memory timing, forwarding, stalls, redirects, and terminal draining.
4. Compare directed and seeded-random programs against the bundle reference model.
5. Select an FPGA target and validate timing only after functional acceptance.

Use the [verification plan](docs/verification.md) for the evidence required at each step. Record unresolved choices in the [decision record](docs/decisions.md). When executable tooling is added, update this README with tested setup and run commands and their required versions.
