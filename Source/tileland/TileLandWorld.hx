package tileland;

import generated.tileland.TileLandCompositionGenerated;
import worldofcake.ui.ComponentWorldBase;

class TileLandWorld extends ComponentWorldBase {
    private var sequencer:TileLandSequencer;
    public function new() {
        super(TileLandLayout.WINDOW_WIDTH, TileLandLayout.WINDOW_HEIGHT, TileLandLayout.PANEL_WIDTH, TileLandLayout.PANEL_HEIGHT);
        sequencer = new TileLandSequencer();
        var view = new TileLandView(sequencer, getWindowToPanelMapper());
        setView(view);
        setComponents(TileLandCompositionGenerated.build(sequencer, getWindowToPanelMapper(), view));
    }

    override public function handleKeyPressed(key:String):Void sequencer.keyPressed(TileLandSequencer.PLAY_AREA_UID, key);
    public function getSequencer():TileLandSequencer return sequencer;
}
