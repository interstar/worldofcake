package worldofcake.bridge;

import worldofcake.ISequencer;

/**
    Shared native-facing lifecycle for one sequencer model. Concrete harnesses
    construct their app model, pass it here, and add only app-specific calls.
**/
class SequencerHarness {
    var sequencer:ISequencer;

    public function new(sequencer:ISequencer) this.sequencer = sequencer;

    public function destroy():Void sequencer = null;
    public function modelReady():Bool return sequencer != null && sequencer.getModelStatus().ready;
    public function stateRevision():Int return sequencer == null ? 0 : sequencer.getModelStatus().stateRevision;
    public function advanceTime(delta:Float):Void if (sequencer != null) sequencer.advanceTime(delta);
    public function resyncTime(elapsedSeconds:Float):Void if (sequencer != null) sequencer.resyncTime(elapsedSeconds);
    public function resetTransport():Void if (sequencer != null) sequencer.resetTransport();
    public function setTransportRunning(value:Bool):Void if (sequencer != null) sequencer.setTransportRunning(value);
    public function reset():Void if (sequencer != null) sequencer.reset();
    public function setPaused(value:Bool):Void if (sequencer != null) sequencer.setPaused(value);
    public function setMuted(value:Bool):Void if (sequencer != null) sequencer.setMuted(value);
    public function paused():Bool return sequencer != null && sequencer.isPaused();
    public function muted():Bool return sequencer != null && sequencer.isMuted();
    public function controlOutputCount():Int return sequencer == null ? 0 : sequencer.getControlOutputs().length;
    /** Published value (0..1) of a control output; 0 when there is no such output. */
    public function controlOutputValue(index:Int):Float {
        if (sequencer == null) return 0.0;
        var outputs = sequencer.getControlOutputs();
        return index < 0 || index >= outputs.length ? 0.0 : outputs[index].published;
    }
    public function logicalTime():Float return sequencer == null ? 0.0 : sequencer.getLogicalTime();
    public function exportStateJson():String return sequencer == null ? "{}" : sequencer.exportStateJson();
    public function importStateJson(json:String):Void if (sequencer != null) sequencer.importStateJson(json);
}
