# Decision record

[Project overview](../README.md) · [Specification](../SPEC.md) · [Architecture](architecture.md) · [Verification](verification.md)

This record separates choices already established by the specification from unresolved implementation choices. It does not authorize architectural changes. `SPEC.md` remains authoritative, including where it labels a selected behavior an implementation choice.

## Established baseline

The entries below summarize existing P1 commitments and their implementation consequences; they are not newly approved design changes.

| ID | Established choice | Consequence | Specification reference |
| --- | --- | --- | --- |
| D01 | Fixed four-slot bundles with slot 0 handling memory/control | Tools and RTL must agree on slot order, bundle addresses, and whole-bundle legality | Sections 2–4 |
| D02 | Conservative cross-slot read/write exclusion | The checker rejects both orderings of cross-slot overlap; scheduling cannot rely on same-bundle forwarding | Section 4.1 |
| D03 | P1 synchronous-memory pipeline with held fetch response | Preserve the named pipeline boundaries and align load data with WB metadata | Sections 6–7, 9.1 |
| D04 | MEM-before-WB forwarding with a load-use interlock | Newer unready load data cannot be replaced by an older matching result | Section 8 |
| D05 | Decode barriers and EX resolution | Control and terminal events obey instruction age; younger decode events cannot override older EX events | Section 9 |
| D06 | HALT/fault drain with explicit terminal diagnostics | Older work completes, the stopping bundle does not enter MEM, and terminal PC names that bundle | Section 10 |
| D07 | Numeric diagnostic fault codes selected in the specification | Share the specified mapping across RTL, models, and test reports rather than inventing separate mappings | Section 10.1 |
| D08 | Core reset preserves RAM contents | Tests and builds must supply reproducible images; reset is not a memory initializer | Sections 5, 11.22–11.23 |
| D09 | Initial scheduler favors legality over optimal packing | Preserve dependencies and memory order, then validate output independently | Section 14.3 |

## Open implementation choices

No selection is recorded for the following items. Resolve them when the relevant implementation work begins, and record the evidence needed to reproduce the choice.

| Item | What needs to be decided | Completion evidence |
| --- | --- | --- |
| Simulation and checking tools | Simulator, supported SystemVerilog features, lint/assertion tooling, and versions | Working unit and pipeline test commands with recorded versions |
| Software environment | Python version, dependencies, and command-line entry points for tools and regression | Reproducible setup and a successful documented run |
| Memory configuration | Concrete IMEM/DMEM depths and input images for each test or target | Shared configuration used consistently by tools, core, and RAMs |
| Regression budget | Fixed seed set, random-program count, and timeout policy | Documented coverage rationale and repeatable regression report |
| FPGA target | Board, device, clock pin/period, reset adaptation, and status pins | Checked-in constraints and post-route timing results |
| Synthesis details | Tool versions and device-specific attributes where needed | Equivalent functional behavior and synthesis/implementation evidence |
| Optional numeric control operands | Whether assembly accepts numeric branch/JAL displacements | Explicit parser behavior and tests; if accepted, operands are signed byte displacements per Section 14.1 |

Open choices must stay within the existing contracts. For example, selecting a board does not implicitly add a PLL, UART, or host loader; selecting a simulator does not permit shortening the pipeline.

## Maintaining this record

When resolving an open item, add a dated entry with a stable ID, status, context, selected option, rationale, consequences, and links to the implementation or verification evidence. Mark replaced decisions as superseded instead of deleting their history. Do not mark a proposal as accepted or verified before that status is supported.

If a choice would change architectural behavior, obtain an explicit scope change and update the specification before relying on it in implementation. For an ambiguity within the existing scope, prefer the simplest deterministic interpretation, document the affected specification section and reasoning, and add a focused test.

Keep encodings, interface tables, cycle equations, and the full acceptance matrix in `SPEC.md`. This record should explain why a choice was made and what it affects, without becoming a second specification.
