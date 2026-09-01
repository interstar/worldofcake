package gbloink;

import generated.gbloink.GbloinkCompositionGenerated;
import worldofcake.LocalPoint;
import worldofcake.ui.ComponentWorldBase;

class GbloinkWorld extends ComponentWorldBase {
    private var sequencer:Gbloink;
    public function new() {
        super(GbloinkLayout.WINDOW_WIDTH, GbloinkLayout.WINDOW_HEIGHT, GbloinkLayout.PANEL_WIDTH, GbloinkLayout.PANEL_HEIGHT);
        sequencer = new Gbloink(new LocalPoint(GbloinkLayout.LOCAL_WIDTH, GbloinkLayout.LOCAL_HEIGHT));
        var view = new GbloinkView(sequencer, getWindowToPanelMapper());
        setView(view);
        setComponents(GbloinkCompositionGenerated.build(sequencer, getWindowToPanelMapper(), view));
    }

    override public function getSequencer():Gbloink return sequencer;

    override public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(Gbloink.PLAY_AREA_UID, key);
    }
}
