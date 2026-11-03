public final class WorldOfCakeLaylagenMain {
    private WorldOfCakeLaylagenMain() {
    }

    public static void main(String[] args) throws Exception {
        String[] clojureArgs = new String[args.length + 2];
        clojureArgs[0] = "-m";
        clojureArgs[1] = "worldofcake.laylagen.main";
        System.arraycopy(args, 0, clojureArgs, 2, args.length);
        Class<?> clojureMain = Class.forName("clojure.main");
        clojureMain.getMethod("main", String[].class).invoke(null, (Object) clojureArgs);
    }
}
