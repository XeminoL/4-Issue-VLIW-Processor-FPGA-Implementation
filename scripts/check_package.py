"""Elaborate and constant-evaluate the package contract; no CPU simulation."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "build" / "python"))

def main():
    try:
        import pyslang
        from pyslang import ast, syntax
    except ImportError:
        sys.exit("Install dependency from the project root: python -m pip install --target build/python -r scripts/requirements.txt")
    comp = ast.Compilation()
    for path in ("rtl/common/vliw_pkg.sv", "tb/tb_vliw_pkg.sv"):
        source = ROOT / path
        if not source.is_file():
            sys.exit(f"Missing required source: {source}")
        comp.addSyntaxTree(syntax.SyntaxTree.fromFile(str(source)))
    root = comp.getRoot()
    diagnostics = comp.getAllDiagnostics()
    if any(d.isError() for d in diagnostics):
        print(pyslang.DiagnosticEngine.reportAll(comp.sourceManager, diagnostics))
        return 1
    test = next(t for t in root.topInstances if t.name == "tb_vliw_pkg")
    checks = [s for s in test.body if s.name.startswith("CHECK_")]
    if not checks:
        sys.exit("No package checks found.")
    failed = [s.name for s in checks if str(s.value) != "1'b1"]
    if failed:
        sys.exit("FAIL: " + ", ".join(failed))
    print(f"PASS: {len(checks)} package contract checks (slang constant evaluation).")
    print("No CPU simulation or FPGA validation performed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
