#!/usr/bin/env python3
"""Marks risks as fixed in quality/risk-register.json and refreshes the matrix.

    quality/fix.py R-01 R-02 --note "what changed"

The traceability gate then refuses the change unless an enforced, tested
criterion backs each risk, so this cannot be used to paper over an open one.
"""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
path = root / "quality" / "risk-register.json"
args = sys.argv[1:]
note = None
if "--note" in args:
    i = args.index("--note")
    note = args[i + 1]
    args = args[:i] + args[i + 2:]

data = json.loads(path.read_text())
known = {r["id"]: r for r in data["risks"]}
for rid in args:
    if rid not in known:
        sys.exit(f"{rid} is not in the register")
    known[rid]["status"] = "fixed"
    if note:
        known[rid]["fix"] = note
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
sys.exit(subprocess.call(["node", "quality/gate/traceability.mjs", "--write"], cwd=root))
