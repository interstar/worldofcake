package kdiagram;

/** Score symbols. Numeric values are stable in patches and native snapshots. */
enum abstract NodeType(Int) to Int {
    var Circle = 0;
    var Triangle = 1;
    var Square = 2;
    var Terminus = 3;

    public static function fromInt(value:Int):NodeType {
        return switch (value) { case 1: Triangle; case 2: Square; case 3: Terminus; default: Circle; };
    }
}
