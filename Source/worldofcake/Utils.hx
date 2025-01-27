package worldofcake;


class Scale {
    public var pattern:Array<Int>;

    public function new(pattern:Array<Int>) {
        this.pattern = pattern;
    }

    /**
     * Move up from 'note' until pattern[note % 12] == 1
     */
    public function transform(note:Int):Int {
        var newNote = note;
        while (pattern[newNote % 12] == 0) {
            newNote++;
        }
        return newNote;
    }
}




class NoteCalculator {
    public var scales:Map<String,Scale>;
    public var current:String;

    public function new() {
        scales = new Map<String,Scale>();
        scales.set("chromatic", new Scale([1,1,1,1,1,1,1,1,1,1,1,1,1]));
        scales.set("major",     new Scale([1,0,1,0,1,1,0,1,0,1,0,1,1]));
        scales.set("minor",     new Scale([1,0,1,1,0,1,0,1,1,0,0,1,1]));
        // etc. add more if needed
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


class Utils {

    public static function randomInt(min:Int, max:Int):Int {
        return min + Math.floor(Math.random() * (max - min + 1));
    };

    public static var NoteCalculator = NoteCalculator;
    public static var Scale = Scale;
}

