package worldofcake;

/**
    Small Park-Miller generator for deterministic fixtures across Haxe targets.
    Float storage keeps the exact integer arithmetic within IEEE-754's safe range.
**/
class SeededRandomSource implements IRandomSource {
    private static inline var MODULUS:Float = 2147483647.0;
    private static inline var MULTIPLIER:Float = 16807.0;

    private var state:Float;

    public function new(seed:Int) {
        var normalized = seed % 2147483647;
        if (normalized <= 0) {
            normalized += 2147483646;
        }
        state = normalized;
    }

    public function nextFloat():Float {
        state = (state * MULTIPLIER) % MODULUS;
        return state / MODULUS;
    }
}
