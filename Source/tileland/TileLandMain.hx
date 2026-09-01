package tileland;

import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class TileLandMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld {
        return new TileLandWorld();
    }

    override private function panelWidth():Float {
        return TileLandLayout.PANEL_WIDTH;
    }

    override private function panelHeight():Float {
        return TileLandLayout.PANEL_HEIGHT;
    }

    override private function usesKeyboard():Bool {
        return true;
    }
}
