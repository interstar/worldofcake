package zewp;

import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class ZewpMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld {
        return new ZewpWorld();
    }

    override private function panelWidth():Float {
        return ZewpLayout.PANEL_WIDTH;
    }

    override private function panelHeight():Float {
        return ZewpLayout.PANEL_HEIGHT;
    }
}
