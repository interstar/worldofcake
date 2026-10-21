# Zewp (VCV Rack) — outputs

The Rack socket metadata for this module is `layouts/rack/zewp.edn`. It records output IDs, labels, voltage laws, and patch-bay geometry for checker/generator use.


Zewp has a dynamically adjustable population, but Rack ports are fixed. The
module therefore exposes six stable slots. Slots above the current population
publish 0 V and a low gate; adding or removing Zewps never changes port
identity or disconnects a patch cable.

Each slot has three outputs:

- **X**: horizontal position, 0–10 V from the left to right edge.
- **Y**: vertical position, 0–10 V from the top to bottom edge.
- **In-front gate**: 10 V while the Zewp sees another glyph or block ahead,
  otherwise 0 V.

The first six Zewps retain stable slot identity. Zewp population control ranges
from 0 to 40; slots 7–40 are currently visual/control-only and have no Rack
outputs.
