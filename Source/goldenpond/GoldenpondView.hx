package goldenpond;

import generated.goldenpond.GoldenpondControlIdsGenerated;
import worldofcake.CoordinateMapper;
import worldofcake.SequenceSnapshot;
import worldofcake.ui.ControlValueViewBase;
import worldofcake.ui.PianoRoll;
import worldofcake.ui.PlayArea;
import worldofcake.ui.PanelStatus;
import worldofcake.ui.TextInput;
import worldofcake.ui.SemanticSelect;

class GoldenpondView extends ControlValueViewBase {
    private var sequencer:GoldenpondSequencer;
    private var playArea:PlayArea;
    private var pianoRoll:PianoRoll;
    private var status:PanelStatus;
    private var correctionTargetSelect:SemanticSelect;
    private var keySelect:SemanticSelect;
    private var modeSelect:SemanticSelect;

    public function new(sequencer:GoldenpondSequencer, _mapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
    }

    public function setPlayArea(value:PlayArea):Void {
        playArea = value;
        addChild(value);
        var size = value.getSize();
        pianoRoll = new PianoRoll(value.panelLengthToWindowLength(size.x), value.panelLengthToWindowLength(size.y));
        value.addChild(pianoRoll);
        redrawScore();
    }

    public function addTextInput(value:TextInput):Void addChild(value);
    public function setStatus(value:PanelStatus):Void {
        status = value;
        addChild(value);
        updateStatus();
    }

    public function setCorrectionTargetSelect(value:SemanticSelect):Void {
        correctionTargetSelect = value;
        addChild(value);
        value.setSelectedIndex(sequencer.getCorrectionTarget());
    }

    public function setKeySelect(value:SemanticSelect):Void {
        keySelect = value;
        addChild(value);
        value.setSelectedIndex(sequencer.getKeyIndex());
    }

    public function setModeSelect(value:SemanticSelect):Void {
        modeSelect = value;
        addChild(value);
        value.setSelectedIndex(sequencer.getModeIndex());
    }

    override public function redrawDirty():Void {
        if (sequencer.consumeDirty()) redrawScore();
    }

    private function redrawScore():Void {
        if (pianoRoll == null) return;
        if (correctionTargetSelect != null) correctionTargetSelect.setSelectedIndex(sequencer.getCorrectionTarget());
        if (keySelect != null) keySelect.setSelectedIndex(sequencer.getKeyIndex());
        if (modeSelect != null) modeSelect.setSelectedIndex(sequencer.getModeIndex());
        pianoRoll.setScore(sequencer.getSnapshot());
        pianoRoll.setZoom(sequencer.getPianoRollZoom());
        pianoRoll.setPositionTicks(sequencer.getLoopPositionTicks());
        updateStatus();
    }

    private function updateStatus():Void {
        if (status == null) return;
        status.setText(sequencer.lastCompileError == null ? "" : "Error: " + sequencer.lastCompileError);
    }
}
