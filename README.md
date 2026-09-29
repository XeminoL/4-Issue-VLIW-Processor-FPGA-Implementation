# 4-Issue VLIW Processor

A specification-driven project to build a 32-bit, four-issue Very Long Instruction Word (VLIW) processor in SystemVerilog, together with assembly tools, reference models, and verification tests.

Software groups independent operations into a 128-bit bundle. The processor executes bundles through an in-order pipeline, with up to four operations per bundle. The goal is a correct, reproducible implementation before performance optimization.

## Project status

The shared package is implemented. Workspace setup and package contract checks are available; other RTL, software tools, and integration testbenches remain placeholders. CPU simulation and FPGA results are not yet available.

## Setup and package checks

From the repository root, using Python 3.10 or newer:

```powershell
python scripts/setup_workspace.py
python -m pip install --target build/python -r scripts/requirements.txt
python scripts/check_package.py
```

Setup creates missing workload and output directories without overwriting files.
The checker runs 11 contract checks using slang constant evaluation: architecture
constants, memory defaults, exact special words, control encodings, fault codes,
instruction tags, forwarding selections, record widths, field packing, lane
order, and zero payloads. Verified with Python 3.10.0 and pyslang 11.0.0.
It resolves paths relative to the script, so checks also work outside the root.

The M/W packet fields total 288 bits, although SPEC.md states 388 bits. The
package preserves the listed fields without padding; see decision D11.
This is package validation, not CPU simulation. Full regression, random-program
generation, and FPGA build automation remain pending implementation and target
selection.


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
