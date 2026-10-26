package worldofcake;

/**
    Kinds of musical event a sequencer publishes. An abstract over Int: typed in
    Haxe, a plain integer at the native bridge (`PreparedEvent::type`).
**/
enum abstract EventType(Int) to Int {
    /** data1 = channel, data2 = note, data3 = velocity. */
    var NoteOn = 0;
    /** data1 = channel, data2 = controller number, data3 = 7-bit value. */
    var ControlChange = 1;
    /** data1 = channel, data2 = note. */
    var NoteOff = 2;
}
