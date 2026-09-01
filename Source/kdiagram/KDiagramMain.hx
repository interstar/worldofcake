package kdiagram;

import openfl.events.KeyboardEvent;
import worldofcake.ui.ISequencerWorld;
import worldofcake.ui.OpenFLAppBase;

class KDiagramMain extends OpenFLAppBase {
    override private function createWorld():ISequencerWorld {
        return new KDiagramWorld();
    }

    override private function panelWidth():Float {
        return KDiagramLayout.PANEL_WIDTH;
    }

    override private function panelHeight():Float {
        return KDiagramLayout.PANEL_HEIGHT;
    }

    override private function usesKeyboard():Bool {
        return true;
    }

    override private function keyFromEvent(e:KeyboardEvent):String {
        return switch (e.keyCode) {
            case 49: "1";
            case 50: "2";
            case 51: "3";
            case 32: " ";
            case 219: "[";
            case 221: "]";
            case _: String.fromCharCode(e.charCode);
        };
    }
}
