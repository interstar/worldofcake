package worldofcake;

/** A concrete note in a compiled, host-independent score. Times are ticks. */
class SequenceNote {
    public var partId:Int;
    public var pitch:Int;
    public var velocity:Int;
    public var startTick:Float;
    public var durationTicks:Float;

    public function new(partId:Int, pitch:Int, startTick:Float, durationTicks:Float, velocity:Int = 100) {
        if (!Math.isFinite(startTick) || startTick < 0) throw "SequenceNote startTick must be finite and non-negative";
        if (!Math.isFinite(durationTicks) || durationTicks < 0) throw "SequenceNote durationTicks must be finite and non-negative";
        if (pitch < 0 || pitch > 127) throw "SequenceNote pitch must be between 0 and 127";
        if (velocity < 0 || velocity > 127) throw "SequenceNote velocity must be between 0 and 127";
        this.partId = partId;
        this.pitch = pitch;
        this.velocity = velocity;
        this.startTick = startTick;
        this.durationTicks = durationTicks;
    }

    public function endTick():Float {
        return startTick + durationTicks;
    }
}
