package worldofcake;

class Scale {
    public var pattern:Array<Int>;

    public function new(pattern:Array<Int>) {
        this.pattern = pattern;
    }

    public function transform(note:Int):Int {
        var newNote = note;
        while (pattern[newNote % 12] == 0) {
            newNote++;
        }
        return newNote;
    }
} 