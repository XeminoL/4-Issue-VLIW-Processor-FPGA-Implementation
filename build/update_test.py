from pathlib import Path
p = Path("tb/tb_vliw_pkg.sv")
s = p.read_text().replace("$bits(m) == 388 && $bits(w) == 388", "$bits(m) == 288 && $bits(w) == 288")
s = s.replace("        e = {1'b1,32'h20,62'd3,62'd2,62'd1,dec,256'd0,41'd0};", "        e.dec = {62'd3,62'd2,62'd1,dec};")
p.write_text(s)
