package worldofcake;

/** Target-neutral lifecycle state for a constructed sequencer model. */
typedef ModelStatus = {
    var ready:Bool;
    /** Changes when persisted/project state is replaced or imported. */
    var stateRevision:Int;
};
