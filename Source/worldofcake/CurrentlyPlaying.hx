package worldofcake;

/** Tracks explicit MIDI note lifetimes for lifecycle cleanup. */
class CurrentlyPlaying {
    var counts:Map<String, Int> = new Map();

    public function new() {}

    public function noteOn(channel:Int, note:Int):Void {
        var key = channel + ":" + note;
        counts.set(key, counts.exists(key) ? counts.get(key) + 1 : 1);
    }

    /** Returns false when no such note is sounding (nothing to release). */
    public function noteOff(channel:Int, note:Int):Bool {
        var key = channel + ":" + note;
        if (!counts.exists(key)) return false;
        var count = counts.get(key) - 1;
        if (count <= 0) counts.remove(key); else counts.set(key, count);
        return true;
    }

    /** Append one note-off for every outstanding note-on and clear state. */
    public function flush(time:Float, output:Array<Event>):Void {
        for (key in counts.keys()) {
            var parts = key.split(":");
            var channel = Std.parseInt(parts[0]);
            var note = Std.parseInt(parts[1]);
            var count = counts.get(key);
            for (i in 0...count) output.push(new Event(time, NoteOff, channel, note, 0));
        }
        counts = new Map();
    }
}
