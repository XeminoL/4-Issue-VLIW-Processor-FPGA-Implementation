# Architecture guide

[Project overview](../README.md) · [Specification](../SPEC.md) · [Verification](verification.md) · [Decisions](decisions.md)

This guide explains the intended design and the boundaries between its components. It describes the specified P1 design, not completed RTL. Exact encodings, packet layouts, ports, and cycle equations remain in `SPEC.md`.

## The bundle is the unit of execution

A bundle contains four operations whose operands are read before that bundle's writes. Software must place independent operations together: there is no forwarding between slots of the same bundle. A legality failure rejects every operation in that bundle.

Slot 0 supports memory and control as well as arithmetic. Slots 1–3 support arithmetic and NOP. A load or store may have independent arithmetic partners; a branch, JAL, or HALT must have only exact NOP partners.

Manual assembly lists slots in the order `{ op0 | op1 | op2 | op3 }`. A hexadecimal memory-image line instead places slot 3 at the most significant end and slot 0 at the least significant end. Keep this distinction visible when diagnosing encoding problems. See specification Sections 2–4 and 14 for the authoritative formats.

## System boundaries

```text
FPGA_Top
  +-- reset_sync
  +-- VLIW_System
        +-- VLIW_Core <--> IMEM
        |      |
        |      +--------> DMEM
        |      <--------- registered load data
        +-- performance_counters
```

`VLIW_Core` owns execution and the checked memory-request interfaces. `VLIW_System` connects the core, memories, and counters with consistent memory-depth parameters. `FPGA_Top` supplies the board boundary and reset synchronization. Board pin assignments and timing constraints are separate implementation choices.

Inside the core, decode interprets instructions, the bundle checker validates their combination, execution computes results, and the load/store unit checks data addresses and presents accepted memory requests. `pipeline_control` owns movement, barriers, redirects, and drain decisions; individual units must not invent competing stall or flush policies. Module contracts and connection ownership are in specification Sections 11–12.

## Pipeline flow

```text
Fetch PC -> synchronous IMEM + held response metadata
         -> IF/ID -> decode and register read
         -> ID/EX -> execute
         -> EX/MEM -> synchronous data access
         -> MEM/WB metadata + registered DMEM output -> writeback
```

The frontend holds an instruction response and its matching PC when decode cannot accept it. The held response consists of core metadata and IMEM's registered output. Consuming that response and requesting the next one can happen at the same edge: IF/ID samples the old output before the memory produces its new response.

Decode captures register operands into ID/EX. Execute resolves forwarded operands, computes arithmetic and addresses, and resolves control flow. Only nonfaulting, non-HALT bundles enter EX/MEM. Writeback commits register results and produces the successful retirement trace.

Synchronous load timing is central to this design. MEM/WB captures metadata at the data-memory access edge; DMEM produces the corresponding load value after that edge. Writeback uses that registered output directly. Capturing the new load value into MEM/WB at the same edge would pair metadata with stale data. Use specification Sections 6–7 for the full timing and storage contracts.

## Dependencies across bundles

The register file provides eight reads and four writes, including write-through bypass for simultaneous writeback and decode reads. In execute, forwarding chooses the newest matching producer: MEM before WB, then the captured operand. These resolved operands also feed branch comparison and store data.

ALU results are available from MEM; loads become available in WB. An immediately dependent load consumer waits one cycle in decode while a bubble enters execute and older work advances. An unready matching MEM load must block selection rather than expose an older WB value for the same register. The interlock should prevent such a blocked operand from reaching valid execution. See specification Section 8.

## Control flow and terminal events

Branches, JAL, HALT, and fault tokens form decode barriers. They prevent younger work from advancing while the event proceeds to execute. Branches and JAL resolve in execute, discard younger frontend work, and select the next fetch address. JAL's link is the following bundle address, PC + 16.

Faults and HALT initiate a drain instead of immediate shutdown. The stopping bundle never enters MEM; older MEM/WB work completes. Terminal status is asserted after the specified empty-pipeline condition, and the architectural PC identifies the stopping bundle. Fetch PC is a separate, speculative state and must not be used as the committed PC.

Event ordering follows instruction age. A younger decode error or HALT cannot override an older execute event. Fault category selection and exact drain/redirect priorities are defined in specification Sections 9–10.

## Memory effects and observation

Fetch, effective addresses, and taken control targets are checked before RAM indexing, preventing out-of-range addresses from aliasing valid storage. Core reset clears execution state but preserves memory contents; input images determine initial RAM contents.

A store physically writes memory before its bundle's WB retirement edge. Verification must observe both the memory request and retirement rather than assuming all effects happen at WB. Runtime validation in execute prevents a faulting memory operation and its arithmetic partners from producing side effects.

The retirement trace, terminal diagnostics, architectural PC, and counters provide the intended observation points. Their exact meanings are specified in Sections 5, 10, and 11. The [verification plan](verification.md) explains how to use them together.
