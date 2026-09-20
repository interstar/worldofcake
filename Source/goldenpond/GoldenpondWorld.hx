package goldenpond;

import generated.goldenpond.GoldenpondCompositionGenerated;
import worldofcake.LocalPoint;
import worldofcake.ui.ComponentWorldBase;

class GoldenpondWorld extends ComponentWorldBase {
    private var sequencer:GoldenpondSequencer;

    public function new() {
        super(GoldenpondLayout.WINDOW_WIDTH, GoldenpondLayout.WINDOW_HEIGHT,
            GoldenpondLayout.PANEL_WIDTH, GoldenpondLayout.PANEL_HEIGHT);
        sequencer = new GoldenpondSequencer();
        var view = new GoldenpondView(sequencer, getWindowToPanelMapper());
        setView(view);
        setComponents(GoldenpondCompositionGenerated.build(sequencer, getWindowToPanelMapper(), view));
    }

    override public function getSequencer():GoldenpondSequencer return sequencer;
}
