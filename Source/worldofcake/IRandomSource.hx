package worldofcake;

/** Injectable random source so models can be repeatable in tests without making normal runs predictable. */
interface IRandomSource {
    function nextFloat():Float;
}
