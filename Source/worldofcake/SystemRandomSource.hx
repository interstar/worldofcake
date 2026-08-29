package worldofcake;

/** Production randomness backed by Haxe's normal runtime random source. */
class SystemRandomSource implements IRandomSource {
    public function new() {}

    public function nextFloat():Float {
        return Math.random();
    }
}
