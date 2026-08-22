#!/usr/bin/env python3
# convert-palette.py
import re, sys, json

path, label, *aliases = sys.argv[1:]
text = open(path).read()
colors = dict(re.findall(
    r'property\s+color\s+(\w+)\s*:\s*"(#[0-9a-fA-F]+)"', text
))

print(json.dumps({
    "label": label,
    "aliases": aliases,
    "colors": colors
}, indent=2))
