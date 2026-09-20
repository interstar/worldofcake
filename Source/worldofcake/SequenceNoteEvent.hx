package worldofcake;

/** A scheduled note transition. timestampTicks is absolute player time. */
class SequenceNoteEvent {
    public static inline var NOTE_ON:Int = 0;
    public static inline var NOTE_OFF:Int = 1;

    public var timestampTicks:Float;
    public var type:Int;
    public var partId:Int;
    public var pitch:Int;
    public var velocity:Int;

    public function new(timestampTicks:Float, type:Int, partId:Int, pitch:Int, velocity:Int) {
        this.timestampTicks = timestampTicks;
        this.type = type;
        this.partId = partId;
        this.pitch = pitch;
        this.velocity = velocity;
    }
}
