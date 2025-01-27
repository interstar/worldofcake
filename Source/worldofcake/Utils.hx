package worldofcake;

class Utils {
    public static function randomInt(min:Int, max:Int):Int {
        return min + Math.floor(Math.random() * (max - min + 1));
    }
}

