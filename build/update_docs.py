from pathlib import Path
root = Path(".")
p = root / "rtl/common/vliw_pkg.sv"
s = p.read_text().replace("localparam integer", "localparam int unsigned").replace("parameter integer", "parameter int unsigned")
s = s.replace("    // Faulting/HALT bundles never enter M; there is no fault/terminal field.", "    // SPEC 7.7 fields sum to 288 bits, despite its stated 388-bit total.\n    // Preserve the field list without invented padding (docs/decisions.md D11).\n    // Faulting/HALT bundles never enter M; there is no fault/terminal field.")
p.write_text(s.rstrip() + "\n")
p = root / "README.md"
s = p.read_text()
start = s.index("The repository currently contains")
end = s.index("\n\n## Start here", start)
s = s[:start] + "The shared package in `rtl/common/vliw_pkg.sv` is implemented and has passing contract checks. Other RTL, software tools, and integration testbenches remain empty placeholders. CPU simulation and FPGA results are not yet available.\n\n## Workspace setup and package checks\n\nRun from the repository root with Python 3.10 or newer:\n\n```powershell\npython scripts/setup_workspace.py\npython -m pip install --target build/python pyslang==11.0.0\npython scripts/check_package.py\n```\n\nVerified with Python 3.10.0 and pyslang 11.0.0. The checker uses SystemVerilog constant evaluation to verify encodings, record widths, field packing, lane order, and zero payloads. It does not simulate the CPU. Compile the package before modules that import it.\n\n**Specification discrepancy:** the M/W field lists sum to 288 bits, while the specification states 388 bits. The package preserves the listed fields without padding; see decision D11 before implementing downstream interfaces.\n\nThe installed Icarus Verilog 12.0 development build fails on the packed decode-record array, so it is not the package validation tool." + s[end:]
p.write_text(s)
p = root / "docs/verification.md"
s = p.read_text().replace("**Current status:** no executable tests, reference models, regression scripts, or verification results are present.", "**Current status:** package contract checks pass with Python 3.10.0 and pyslang 11.0.0. Run `python scripts/check_package.py` after the README setup steps. Coverage includes all defined enum values, exact NOP/HALT words, record widths and field packing, lane/operand ordering, and zero payloads. M/W widths use the field-derived 288 bits (decision D11). No CPU behavior, reference-model comparison, or FPGA validation has run.")
p.write_text(s)
p = root / "docs/decisions.md"
with p.open("a") as f:
    f.write("""
## 2026-09-29 — Package bring-up

### D11 — M/W packet width discrepancy (implemented; specification clarification pending)

SPEC Sections 7.7 and 7.8 list fields totaling 288 bits:
1 + 32 + 32 + 4 + 20 + 4 + 128 + 1 + 1 + 32 + 32 + 1.
Their stated totals and downstream interface tables instead say 388 bits.
The package preserves the exact field list and order, with no invented padding
or extra state. Both packet types are therefore 288 bits; W aliases M.
This is an explicit interpretation of inconsistent requirements, not a claim
that both widths can be satisfied. Resolve the specification discrepancy
before implementing fixed-width downstream ports. The contract test checks
every field's packed position as well as the total.

### D12 — Package defaults and validation (accepted for package bring-up)

Memory-depth defaults are the minimum legal values: IMEM_BUNDLES=1 and
DMEM_WORDS=1. These are fallback values, not selected application/board sizes.
Modules must propagate configured depths consistently and recompute byte
limits with widened arithmetic; package byte limits describe package defaults.

Python 3.10.0 with pyslang 11.0.0 successfully elaborates and constant-evaluates
the package contract checks in scripts/check_package.py, using tb/tb_vliw_pkg.sv.
The installed Icarus 12.0 development build crashes when assigning the packed
decode-record array and reports an incorrect E packet width in a workaround.
No pipeline simulator is selected by this package-only check. Dependencies and
generated output stay in build/. Existing application environment configuration
is preserved.
""")
