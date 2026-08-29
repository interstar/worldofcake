package worldofcake;

class NoteCalculator {
    public var scales:Map<String,Scale>;
    public var current:String;

    public function new() {
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
        var raw = Math.floor(((400 - y) / 6) + 30);
        return scales.get(current).transform(raw);
    }
} 