package zewp;

import generated.zewp.ZewpCompositionGenerated;
import worldofcake.ui.ComponentWorldBase;

class ZewpWorld extends ComponentWorldBase {
    private var sequencer:ZewpSequencer;
    public function new() {
        super(ZewpLayout.WINDOW_WIDTH, ZewpLayout.WINDOW_HEIGHT, ZewpLayout.PANEL_WIDTH, ZewpLayout.PANEL_HEIGHT);
        sequencer = new ZewpSequencer(Std.int(ZewpLayout.PLAY_AREA_WIDTH), Std.int(ZewpLayout.PLAY_AREA_HEIGHT));
        var view = new ZewpView(sequencer, getWindowToPanelMapper());
        setView(view);
        setComponents(ZewpCompositionGenerated.build(sequencer, getWindowToPanelMapper(), view));
    }

    override public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(ZewpSequencer.PLAY_AREA_UID, key);
    }

    public function getSequencer():ZewpSequencer {
        return sequencer;
    }
}
