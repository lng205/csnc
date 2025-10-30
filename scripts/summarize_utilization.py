#!/usr/bin/env python3
"""
Parse Vivado report_utilization .rpt and emit a concise Markdown summary.

Usage:
  python scripts/summarize_utilization.py \
    --rpt vivado_rs_synth/utilization.rpt \
    --out verilog/zu3eg_rs_resources.md \
    --device xczu3eg-sbva484-1-e

The script extracts totals and, if present, per-instance rows for rs_enc_0 / rs_dec_0.
"""
from __future__ import annotations
import argparse
import re
from pathlib import Path


def parse_utilization_rpt(text: str) -> dict:
    data = {
        "total": {},
        "instances": {},
    }
    # Totals section typically has a table with keywords like CLB LUTs, LUT as Logic, Register, BRAM_18K, URAM, DSPs
    # We will capture a few common metrics by name across lines.
    totals = {}
    for line in text.splitlines():
        line = line.strip()
        # e.g., | CLB LUTs* |  123 |  ...
        m = re.match(r"\|\s*(CLB LUTs\*?|LUT as Logic|LUT as Memory|Register|CLB Registers|BRAM_18K|URAM|DSPs)\s*\|\s*([0-9,]+)\s*\|", line)
        if m:
            key = m.group(1)
            val = int(m.group(2).replace(",", ""))
            totals[key] = val
    data["total"] = totals

    # Hierarchical instance table rows often look like:
    # | Instance | Module | ... | LUT | REG | BRAM_18K | URAM | DSP |
    # We look for rows starting with rs_enc_0 or rs_dec_0 to map selected fields.
    for line in text.splitlines():
        if not line.strip().startswith('|'):
            continue
        parts = [p.strip() for p in line.strip().split('|') if p.strip()]
        # Expected columns: Instance, Module, Total LUTs, Logic LUTs, LUTRAMs, SRLs, FFs, RAMB36, RAMB18, URAM, DSP Blocks
        if len(parts) >= 11 and parts[0] in ("u_enc", "u_dec", "rs_enc_0", "rs_dec_0"):
            inst = parts[0]
            # Normalize to rs_enc_0 / rs_dec_0 keys
            name = "rs_enc_0" if "enc" in inst else "rs_dec_0"
            try:
                lut = int(parts[2].replace(',', ''))
                ff = int(parts[6].replace(',', ''))
                ramb18 = int(parts[8].replace(',', ''))
                uram = int(parts[9].replace(',', ''))
                dsp = int(parts[10].replace(',', ''))
            except ValueError:
                continue
            data["instances"][name] = {"LUT": lut, "REG": ff, "BRAM_18K": ramb18, "URAM": uram, "DSP": dsp}
    return data


def render_markdown(data: dict, device: str, rpt_path: Path) -> str:
    lines = []
    lines.append(f"# ZU3EG RS 资源汇总（合成后）")
    lines.append("")
    lines.append(f"- 设备：`{device}`；报告：`{rpt_path.as_posix()}`")
    if data.get("total"):
        t = data["total"]
        lines.append("- 总体资源（Top）:")
        for k in ("CLB LUTs", "LUT as Logic", "LUT as Memory", "CLB Registers", "BRAM_18K", "URAM", "DSPs"):
            if k in t:
                lines.append(f"  - {k}: {t[k]}")
    if data.get("instances"):
        lines.append("")
        lines.append("- 关键实例：")
        for inst in ("rs_enc_0", "rs_dec_0"):
            if inst in data["instances"]:
                r = data["instances"][inst]
                lines.append(f"  - {inst}: LUT={r['LUT']}, REG={r['REG']}, BRAM_18K={r['BRAM_18K']}, URAM={r['URAM']}, DSP={r['DSP']}")
    lines.append("")
    lines.append("说明：上表来自 report_utilization 的综合估计；若需时序/Fmax，请添加时钟约束后运行实现或时序估计。")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rpt", required=True, help="Path to utilization.rpt")
    ap.add_argument("--out", required=True, help="Output markdown path")
    ap.add_argument("--device", required=True, help="Device/part name, e.g., xczu3eg-sbva484-1-e")
    args = ap.parse_args()

    rpt_path = Path(args.rpt)
    text = rpt_path.read_text(encoding="utf-8", errors="ignore")
    data = parse_utilization_rpt(text)
    md = render_markdown(data, args.device, rpt_path)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md, encoding="utf-8")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
