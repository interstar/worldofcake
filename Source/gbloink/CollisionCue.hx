package gbloink;

/** Cosmetic collision history, independent of MIDI output and never serialized. */
typedef CollisionCue = {
    var serial:Int;
    var time:Float;
    var x:Float;
    var y:Float;
    var velocity:Int;
    var colour:Int;
    /** 0 wall, 1 block, 2 ball-to-ball. */
    var kind:Int;
    var ballId:Int;
    /** Struck block's transient ID, or -1 for wall/ball contacts. */
    var blockId:Int;
}
