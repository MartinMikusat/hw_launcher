"""Validate the shared embedded font without installing it or accessing the network."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent / "fonts"
assert hashlib.sha256((root / "JetBrainsMono-Regular.woff2").read_bytes()).hexdigest() == "a9cb1cd82332b23a47e3a1239d25d13c86d16c4220695e34b243effa999f45f2", "JetBrains Mono checksum differs; verify the regular face and its provenance"
assert (root / "OFL.md").is_file(), "The font license must accompany the shared asset"
print("shared font: passed")
