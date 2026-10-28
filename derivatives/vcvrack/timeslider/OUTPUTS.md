# TimeSlider — outputs

The Rack socket metadata for this module is in `apps/timeslider/rack.edn`. It records output IDs, labels, voltage laws, and patch-bay geometry for checker/generator use.


Four **CV** jacks (CC1…CC4 top-to-bottom in widget order).

- **Voltage:** MIDI-style CC value **0…127** mapped linearly to **0…10 V** (unipolar).
- **Update:** Continuous; reflects each track’s **current** position even when it is not moving.

Internal mapping matches `TimeSliderSequencer`: channel **1**, controller numbers **1–4** (for reference if you bridge events to MIDI).
