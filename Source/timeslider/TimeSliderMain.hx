package timeslider;

import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class TimeSliderMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld {
        return new TimeSliderWorld();
    }

    override private function panelWidth():Float {
        return TimeSliderLayout.PANEL_WIDTH;
    }

    override private function panelHeight():Float {
        return TimeSliderLayout.PANEL_HEIGHT;
    }
}
