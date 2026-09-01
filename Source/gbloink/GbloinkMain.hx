package gbloink;

import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class GbloinkMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld {
        return new GbloinkWorld();
    }

    override private function panelWidth():Float {
        return GbloinkLayout.PANEL_WIDTH;
    }

    override private function panelHeight():Float {
        return GbloinkLayout.PANEL_HEIGHT;
    }
}
