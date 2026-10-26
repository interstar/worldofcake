package worldofcake;

/**
    One continuous control a sequencer publishes: an abstract value from 0 to 1,
    plus its MIDI routing. Apps declare their outputs in EDN (`:outputs`) and set
    values through `SequencerCore.setControlOutput`. The core turns changes into
    MIDI CC events; native hosts turn the published value into what their world
    uses (a VST parameter, Rack CV).
**/
class ControlOutput {
    public var id(default, null):String;
    public var label(default, null):String;
    public var channel(default, null):Int;
    public var ccNumber(default, null):Int;
    /** Latest value the model set, 0..1. */
    public var value(default, null):Float = 0.0;
    /** Value hosts see: follows `value` while output is open, holds while muted or paused. */
    public var published(default, null):Float = 0.0;
    /** 7-bit value last sent as a CC, or -1 to send the next value whatever it is. */
    var sentCc:Int = -1;

    public function new(id:String, label:String, channel:Int, ccNumber:Int) {
        this.id = id;
        this.label = label;
        this.channel = channel;
        this.ccNumber = ccNumber;
    }

    /**
        Record a new value. When output is open it is published, and the result
        is the 7-bit CC value to send, or -1 when that is unchanged.
    **/
    public function update(newValue:Float, open:Bool):Int {
        if (!Math.isFinite(newValue)) return -1;
        value = Math.max(0.0, Math.min(1.0, newValue));
        if (!open) return -1;
        published = value;
        var cc = Math.round(value * 127);
        if (cc == sentCc) return -1;
        sentCc = cc;
        return cc;
    }

    /** Send the CC on a different MIDI channel (1..16) from now on. */
    public function setChannel(newChannel:Int):Void {
        var clamped = Std.int(Math.max(1, Math.min(16, newChannel)));
        if (clamped == channel) return;
        channel = clamped;
        sentCc = -1;
    }

    /** After an output boundary the receiver may have missed values: resend on the next update. */
    public function forgetSent():Void {
        sentCc = -1;
    }
}
