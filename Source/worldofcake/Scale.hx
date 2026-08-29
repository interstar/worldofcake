package worldofcake;

class Scale {
    public var pattern:Array<Int>;

    public function new(pattern:Array<Int>) {
        this.pattern = pattern;
    }

    public function transform(note:Int):Int {
        var newNote = note;
        var guard = 0;
        while (pattern[newNote % 12] == 0) {
            newNote++;
            if (++guard > 24) {
                return note;
            }
        }
        return newNote;
    }
} 