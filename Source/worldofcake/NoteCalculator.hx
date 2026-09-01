package worldofcake;

class NoteCalculator {
    public var scales:Map<String,Scale>;
    public var current:String;
    private var playAreaHeight:Float;
    private var lowNote:Int;
    private var noteSpan:Float;

    public function new(playAreaHeight:Float = 400.0, lowNote:Int = 30, noteSpan:Float = 400.0 / 6.0) {
        this.playAreaHeight = playAreaHeight > 0 ? playAreaHeight : 400.0;
        this.lowNote = lowNote;
        this.noteSpan = noteSpan;
        scales = new Map<String,Scale>();
        // 12 semitone slots + octave duplicate (index 12); 1 = allowed, 0 = snap up in `Scale.transform`.
        scales.set("chromatic", new Scale([1,1,1,1,1,1,1,1,1,1,1,1,1]));
        scales.set("major", new Scale([1,0,1,0,1,1,0,1,0,1,0,1,1]));
        scales.set("minor", new Scale([1,0,1,1,0,1,0,1,1,0,1,0,1]));
        scales.set("harmonic_minor", new Scale([1,0,1,1,0,1,0,1,1,0,0,1,1]));
        scales.set("melodic_minor", new Scale([1,0,1,1,0,1,0,1,0,1,0,1,1]));
        scales.set("minor_blues", new Scale([1,0,0,1,0,1,1,1,0,0,1,0,1]));
        current = "chromatic";
    }

    public function setCurrent(scaleName:String):Void {
        if (scales.exists(scaleName)) {
            current = scaleName;
        }
    }

    public function transform(y:Float):Int {
        var boundedY = Math.max(0, Math.min(playAreaHeight, y));
        var raw = Math.floor(((playAreaHeight - boundedY) / playAreaHeight) * noteSpan + lowNote);
        return scales.get(current).transform(raw);
    }
} 