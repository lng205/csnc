#!/usr/bin/env python3
"""
Plot CS vs RS encoder/decoder resource utilization as a grouped bar chart.

Inputs can be Vivado utilization .rpt files or a simple markdown summary line like:
  rs_enc_0: LUT=47, REG=92, BRAM_18K=0, URAM=0, DSP=0

Usage examples:
  python scripts/plot_utilization.py \
    --label CS-ENC --in vivado_cs_dual/enc_utilization.rpt \
    --label CS-DEC --in vivado_cs_dual/dec_utilization.rpt \
    --label RS-ENC --in verilog/zu3eg_rs_resources.md --grep rs_enc_0 \
    --label RS-DEC --in verilog/zu3eg_rs_resources.md --grep rs_dec_0 \
    --out reports/cs_rs_util.svg --csv reports/cs_rs_util.csv --title "ZU3EG L=11 K=5 M=3"

If matplotlib is not installed, prints a text table instead.
"""
from __future__ import annotations
import argparse
import os
import re
from typing import Dict, List, Optional, Tuple


Metric = Dict[str, int]


def parse_vivado_rpt(path: str) -> Metric:
    text = open(path, 'r', encoding='utf-8', errors='ignore').read()
    lut = 0
    ff = 0
    bram18 = 0
    dsp = 0

    # Sum LUT primitives LUT1..LUT6 as an approximation of total LUT usage
    for m in re.finditer(r"\|\s*LUT(\d)\s*\|\s*(\d+)\s*\|", text):
        lut += int(m.group(2))

    # Sum FF primitives
    for name in ("FDRE", "FDSE", "FDCE", "FDPE", "FDRE_1", "FDSE_1"):
        for m in re.finditer(rf"\|\s*{name}\s*\|\s*(\d+)\s*\|", text):
            ff += int(m.group(1))

    # BRAM_18K lines (often appear in top tables)
    m = re.search(r"BRAM_18K\s*\|\s*(\d+)", text)
    if m:
        bram18 = int(m.group(1))

    # DSP48
    m = re.search(r"DSP48\w*\s*\|\s*(\d+)", text)
    if m:
        dsp = int(m.group(1))

    return {"LUT": lut, "REG": ff, "BRAM_18K": bram18, "DSP": dsp}


def parse_md_line(line: str) -> Optional[Metric]:
    # e.g., "rs_enc_0: LUT=47, REG=92, BRAM_18K=0, URAM=0, DSP=0"
    if "LUT=" not in line:
        return None
    kv = dict(re.findall(r"(LUT|REG|BRAM_18K|DSP)\s*=\s*(\d+)", line))
    if not kv:
        return None
    return {k: int(v) for k, v in kv.items()}


def parse_md(path: str, grep: Optional[str]) -> Metric:
    lines = open(path, 'r', encoding='utf-8', errors='ignore').read().splitlines()
    cand: List[Tuple[int, Metric]] = []
    for i, ln in enumerate(lines):
        if grep and grep not in ln:
            continue
        m = parse_md_line(ln)
        if m:
            cand.append((i, m))
    if not cand:
        raise ValueError(f"No utilization line found in {path} (grep={grep})")
    # Choose the first match
    return cand[0][1]


def load_metric(path: str, grep: Optional[str]) -> Metric:
    ext = os.path.splitext(path)[1].lower()
    if ext == '.rpt':
        return parse_vivado_rpt(path)
    else:
        return parse_md(path, grep)


def _write_csv(path: str, labels: List[str], data: Dict[str, Metric], meta: Optional[Dict[str, str]] = None) -> None:
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    cols = ["label", "LUT", "REG", "BRAM_18K", "DSP"]
    with open(path, 'w', encoding='utf-8') as f:
        # optional metadata header as comments
        if meta:
            for k, v in meta.items():
                f.write(f"# {k}: {v}\n")
        f.write(",".join(cols) + "\n")
        for lab in labels:
            row = data[lab]
            f.write(
                f"{lab},{row.get('LUT',0)},{row.get('REG',0)},{row.get('BRAM_18K',0)},{row.get('DSP',0)}\n"
            )


def _colorblind_palette(n: int) -> List[str]:
    base = ["#0072B2", "#D55E00", "#009E73", "#CC79A7", "#F0E442", "#56B4E9", "#E69F00", "#000000"]
    if n <= len(base):
        return base[:n]
    # repeat if needed
    out = []
    i = 0
    while len(out) < n:
        out.append(base[i % len(base)])
        i += 1
    return out


def _write_svg(path: str, labels: List[str], data: Dict[str, Metric], title: str = "") -> None:
    cols = ["LUT", "REG", "BRAM_18K", "DSP"]
    # canvas
    W, H = 900, 520
    margin = dict(l=80, r=80, t=70, b=70)
    plot_w = W - margin['l'] - margin['r']
    plot_h = H - margin['t'] - margin['b']
    groups = len(cols)
    series = len(labels)
    gap_g = 20
    bar_w = max(8, int((plot_w - (groups + 1) * gap_g) / groups / max(1, series) - 6))
    max_val = 0
    for lab in labels:
        for c in cols:
            max_val = max(max_val, data[lab].get(c, 0))
    if max_val <= 0:
        max_val = 1
    colors = _colorblind_palette(series)

    def y_to_svg(v: float) -> float:
        return margin['t'] + plot_h - (v / max_val) * plot_h

    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n')
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n')
        # title
        if title:
            f.write(f'<text x="{W/2}" y="{margin["t"]-25}" text-anchor="middle" font-family="Arial" font-size="18">{title}</text>\n')
        # axes (full box)
        left = margin['l']
        bottom = H - margin['b']
        right = W - margin['r']
        top = margin['t']
        f.write(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{bottom}" stroke="#000" stroke-width="1.5"/>\n')
        f.write(f'<line x1="{left}" y1="{bottom}" x2="{right}" y2="{bottom}" stroke="#000" stroke-width="1.5"/>\n')
        f.write(f'<line x1="{right}" y1="{bottom}" x2="{right}" y2="{top}" stroke="#000" stroke-width="1.5"/>\n')
        f.write(f'<line x1="{right}" y1="{top}" x2="{left}" y2="{top}" stroke="#000" stroke-width="1.5"/>\n')
        # y grid and labels (5 ticks)
        ticks = 5
        for i in range(ticks + 1):
            v = max_val * i / ticks
            y = y_to_svg(v)
            f.write(f'<line x1="{left}" y1="{y}" x2="{W - margin["r"]}" y2="{y}" stroke="#ddd" stroke-width="1"/>\n')
            f.write(f'<text x="{left-10}" y="{y+4}" text-anchor="end" font-family="Arial" font-size="12">{int(v)}</text>\n')
        # x labels and bars
        group_w = (plot_w - (groups + 1) * gap_g) / groups if groups else plot_w
        for gi, cat in enumerate(cols):
            gx = left + gap_g + gi * (group_w + gap_g)
            # category label
            f.write(f'<text x="{gx + group_w/2}" y="{bottom+20}" text-anchor="middle" font-family="Arial" font-size="12">{cat}</text>\n')
            for si, lab in enumerate(labels):
                val = data[lab].get(cat, 0)
                x = gx + si * (bar_w + 6) + (group_w - (bar_w + 6) * series + 6) / 2
                y = y_to_svg(val)
                h = bottom - y
                f.write(f'<rect x="{x}" y="{y}" width="{bar_w}" height="{h}" fill="{colors[si]}" />\n')
        # legend placed inside axes (top-right) with background box
        box_w = 140
        box_h = 18*len(labels) + 8
        lx, ly = right - box_w - 10, top + 10
        f.write(f'<rect x="{lx-8}" y="{ly-8}" width="{box_w}" height="{box_h+16}" fill="#ffffff" stroke="#000" stroke-width="0.5" rx="6" ry="6" opacity="0.95"/>\n')
        for i, lab in enumerate(labels):
            f.write(f'<rect x="{lx}" y="{ly + i*18}" width="12" height="12" fill="{colors[i]}" />\n')
            f.write(f'<text x="{lx+18}" y="{ly + i*18 + 11}" font-family="Arial" font-size="12">{lab}</text>\n')
        f.write('</svg>')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--label', action='append', dest='labels', required=True, help='Legend label for input (repeatable)')
    ap.add_argument('--in', dest='inputs', action='append', required=True, help='Path to utilization .rpt or .md (repeatable)')
    ap.add_argument('--grep', dest='greps', action='append', help='Optional substring to select a line in .md (repeatable)')
    ap.add_argument('--out', required=True, help='Output figure path (.png or .svg)')
    ap.add_argument('--csv', required=False, help='Optional CSV output path')
    ap.add_argument('--title', required=False, default='', help='Figure title (optional)')
    args = ap.parse_args()

    labels = args.labels
    inputs = args.inputs
    greps_in = args.greps or []
    if len(greps_in) < len(inputs):
        greps = greps_in + [None] * (len(inputs) - len(greps_in))
    else:
        greps = greps_in[:len(inputs)]
    if not (len(labels) == len(inputs)):
        raise SystemExit('labels and inputs must have equal counts')

    data: Dict[str, Metric] = {}
    for lab, path, g in zip(labels, inputs, greps):
        data[lab] = load_metric(path, g)

    # Always write CSV if requested
    if args.csv:
        _write_csv(args.csv, labels, data, meta={"device": "xczu3eg-sbva484-1-e"})

    # Try to plot with matplotlib; otherwise write SVG
    use_svg = args.out.lower().endswith('.svg')
    try:
        if not use_svg:
            import matplotlib.pyplot as plt  # type: ignore
            import numpy as np  # type: ignore
        else:
            raise ImportError('force svg')
    except Exception:
        # Fallback SVG
        _write_svg(args.out if use_svg else os.path.splitext(args.out)[0] + '.svg', labels, data, title=args.title)
        print('Saved (SVG):', args.out if use_svg else os.path.splitext(args.out)[0] + '.svg')
        return

    cols = ["LUT", "REG", "BRAM_18K", "DSP"]
    x = np.arange(len(cols))
    width = 0.8 / max(1, len(labels))

    fig, ax = plt.subplots(figsize=(6.5, 3.8), dpi=300)
    palette = _colorblind_palette(len(labels))
    for i, lab in enumerate(labels):
        y = [data[lab].get(c, 0) for c in cols]
        ax.bar(x + i * width, y, width=width, label=lab, color=palette[i])

    ax.set_xticks(x + width * (len(labels) - 1) / 2)
    ax.set_xticklabels(cols)
    ax.set_ylabel('Count')
    if args.title:
        ax.set_title(args.title)
    ax.grid(True, axis='y', linestyle='--', alpha=0.4)
    ax.legend()
    fig.tight_layout()

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    fig.savefig(args.out)
    print(f'Saved: {args.out}')


if __name__ == '__main__':
    main()


