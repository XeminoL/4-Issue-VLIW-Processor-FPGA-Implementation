# Verification plan

[Project overview](../README.md) · [Specification](../SPEC.md) · [Architecture](architecture.md) · [Decisions](decisions.md)

This document organizes implementation bring-up and the evidence needed to establish correctness. The mandatory coverage and assertions are defined in `SPEC.md`, Section 15; this plan does not replace that checklist.

**Current status:** 11 package contract checks pass via `python scripts/check_package.py` with Python 3.10.0 and pyslang 11.0.0. See the README for setup. Coverage includes encodings, constants, widths, field packing, lane order, and zero payloads. M/W widths follow decision D11. CPU tests, reference models, full regression, and FPGA validation remain pending. The stages below are planned work, not claims of passing coverage.

## Bring-up stages

| Stage | Work | Evidence before moving on |
| --- | --- | --- |
| 1. Instruction and bundle behavior | Validate decode, immediates, ALU, register file, and bundle legality independently | Directed unit results covering legal cases and rejection boundaries from Sections 2–4 and 8 |
| 2. Pipeline and memory timing | Integrate pipeline registers, fetch holding, synchronous RAMs, and writeback | Cycle traces proving the Section 6 timing contract and correct response/metadata pairing |
| 3. Dependencies and control | Exercise forwarding, load-use stalls, store operands, and branch/JAL redirects | Producer/consumer lane coverage and evidence of no wrong-path side effects |
| 4. Terminal behavior | Exercise faults, HALT, reset, and competing events | Older effects complete; faulting and younger effects are absent; terminal diagnostics and PC match |
| 5. Program comparison | Run directed programs and reproducible random programs against the bundle model | Matching retirement sequences and final architectural state, with seeds and inputs retained |
| 6. Scheduling and FPGA | Validate scheduled programs, then deploy to a selected target | Independent schedule checks, program equivalence, hardware outputs, and post-route timing evidence |

Unit and pipeline tests belong in `tb/`; reusable workloads belong in `programs/`. Generated images, logs, and waveforms belong in `build/`. Use the filenames and division of responsibilities from specification Section 1 when adding these components.

## Choose the right oracle

The sequential source model checks normal algorithm results before scheduling. The bundle architectural model checks the actual encoded program, including simultaneous operand reads, legality, and faults. It validates all effects before changing state and is the oracle for faulting bundles.

Compare successful RTL retirements in order, including their final register values. At terminal completion, compare all GPRs, full data memory, terminal status, and architectural PC. For fault tests, also check the saved fault PC, category, slot mask, and bad address against the specification.

Observe physical memory requests separately: a store writes at the MEM-to-WB edge and retires later. A final-state comparison alone cannot prove that it wrote exactly once or that a transient wrong-path write never occurred.

Use manual bundles for initial fault-sensitive tests. Scheduling may change which operations precede a fault, so scalar fault-state equivalence is not a general oracle. For JAL and label-dependent programs, comparisons must use the assembler's final bundle-address mapping. See specification Section 14.

## Directed scenarios that expose integration errors

| Scenario | What to observe |
| --- | --- |
| Decode stalls with an existing fetch response | The response and PC stay paired and are consumed once |
| MEM and WB both match an EX source | MEM wins; an unready MEM load never exposes stale WB data |
| Load followed by a dependent bundle | One decode stall, an EX bubble, then WB forwarding |
| Dependent branch or store | Forwarding reaches comparison, address, and store-data paths |
| Faulting load/store with independent ALU partners | Neither the memory operation nor any partner commits |
| Older EX fault with younger decode HALT/error | The older event determines terminal state |
| HALT behind a load, store, or ALU bundle | Older work finishes before terminal status; HALT never enters MEM |
| Untaken branch with an invalid unused target | No target fault; sequential execution continues |
| Boundary or misaligned memory address | Check before indexing; no aliasing or invalid RAM request |
| Reset during execution or drain | No stale writeback or memory request; RAM contents remain preserved |

These scenarios supplement the complete Section 15 matrix, including encoding negatives, all forwarding lanes and operands, x0 behavior, register-file collisions, and slot permutations.

## Assertions and failure diagnosis

Implement the required Section 15 assertions alongside the relevant interfaces. They cover validity-gated side effects, x0, unique destinations, forwarding readiness, store multiplicity, load pairing, flushes, and terminal quiescence. Assertions should identify the cycle, bundle PC, stage, and lane where applicable.

When a test fails, inspect in this order:

1. Instruction words and slot ordering.
2. Decoder outputs and source-use flags.
3. Bundle legality and selected fault.
4. Pipeline valid bits and bundle PCs.
5. Forwarding matches and readiness.
6. Hazard detection and bubble insertion.
7. Memory request/response timing.
8. Retirement and terminal state.

Reduce the failure to a small directed program before changing multiple modules. Keep the failing seed and generated images so a random failure can become a permanent regression case.

## Reproducible regression evidence

Each documented regression run should identify:

- Source revision or equivalent source snapshot, simulator/tool versions, and exact invocation.
- Memory depths, image files, program mode, and other build configuration.
- Directed test names and outcomes, random seeds and program counts, and timeout limits.
- Expected and actual terminal states, with mismatch details for failed comparisons.
- Locations of logs, traces, and waveforms needed to reproduce failures.

A timeout is a failure to reach the expected terminal state, not a successful run. Fixed seeds make failures reproducible; assertions and model comparisons determine whether they pass. Record measured coverage without treating an unrun case as covered.

## Acceptance and performance

Functional acceptance requires all directed tests and a documented seeded-random regression to pass, as specified in Section 15. FPGA acceptance additionally requires a named device, clock constraint, verified operating frequency, and reproducible images. No acceptance stage is currently complete.

Report performance only alongside correctness evidence. Include elapsed cycles, useful operations, stalls, code size, device resources, and post-route timing. Apply the specification's counter definitions and comparison methodology: useful operations exclude NOP and HALT, and elapsed time includes pipeline fill and drain. A scalar comparison must use equivalent semantics, the same workload and data, and documented memory timing.

Add tested commands here and in the README once the runner and toolchain are available; do not substitute unverified example commands for a working procedure.
