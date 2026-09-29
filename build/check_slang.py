from pathlib import Path
import sys
sys.path.insert(0, str(Path("build/python").resolve()))
import pyslang
from pyslang import ast, syntax
c = ast.Compilation()
for p in ["rtl/common/vliw_pkg.sv", "tb/tb_vliw_pkg.sv"]:
    c.addSyntaxTree(syntax.SyntaxTree.fromFile(p))
print(pyslang.DiagnosticEngine.reportAll(c.sourceManager, c.getAllDiagnostics()))
pkg = c.getPackage("vliw_pkg")
print([(s.name, str(s.kind)) for s in pkg][:8])
print([(s.name, s.targetType.bitWidth) for s in pkg if s.name.endswith("_packet_t")])
