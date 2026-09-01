package kdiagram;

import generated.kdiagram.KDiagramCompositionGenerated;
import worldofcake.ui.ComponentWorldBase;

class KDiagramWorld extends ComponentWorldBase {
    private var sequencer:KDiagramSequencer;
    public function new() {
        super(KDiagramLayout.WINDOW_WIDTH, KDiagramLayout.WINDOW_HEIGHT, KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT);
        sequencer = new KDiagramSequencer();
        var view = new KDiagramView(sequencer, getWindowToPanelMapper());
        setView(view);
        setComponents(KDiagramCompositionGenerated.build(sequencer, getWindowToPanelMapper(), view));
    }

    override public function handleKeyPressed(key:String):Void sequencer.keyPressed(KDiagramSequencer.PLAY_AREA_UID, key);
    override public function getSequencer():KDiagramSequencer return sequencer;
}
