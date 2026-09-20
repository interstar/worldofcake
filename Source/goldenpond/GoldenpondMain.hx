package goldenpond;

import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class GoldenpondMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld return new GoldenpondWorld();
    override private function panelWidth():Float return GoldenpondLayout.PANEL_WIDTH;
    override private function panelHeight():Float return GoldenpondLayout.PANEL_HEIGHT;
}
