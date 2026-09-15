(ns worldofcake.laylagen.main
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.string :as str]
            [worldofcake.laylagen.core :as generator]))

(defn- parse-args [args]
  (loop [remaining args options {}]
    (if (empty? remaining)
      options
      (let [[flag & tail] remaining]
        (if (= flag "--check")
          (recur tail (assoc options flag true))
          (let [[value & more] tail]
            (when-not value (throw (ex-info (str "Missing value for " flag) {})))
            (recur more (assoc options flag value))))))))

(defn- safe-output-file [output-dir relative]
  (let [root (.getCanonicalFile (io/file output-dir))
        target (.getCanonicalFile (io/file root relative))
        root-path (str (.getPath root) java.io.File/separator)]
    (when-not (str/starts-with? (.getPath target) root-path)
      (throw (ex-info "Generated output path escapes output directory" {:path relative})))
    target))

(defn- current? [target content]
  (and (.isFile target) (= content (slurp target))))

(defn write-or-check! [files output-dir check?]
  (let [stale (->> files
                   (keep (fn [[relative content]]
                           (let [target (safe-output-file output-dir relative)]
                             (when-not (current? target content)
                               (if check?
                                 relative
                                 (do (.mkdirs (.getParentFile target))
                                     (spit target content)
                                     nil))))))
                   vec)]
    (when (seq stale)
      (throw (ex-info (str "Generated output is stale: " (str/join ", " stale)) {:stale stale})))
    (count files)))

(defn -main [& args]
  (try
    (let [options (parse-args args)
          input (get options "--input")
          config-path (get options "--config")
          output (get options "--output")]
      (when-not (and input config-path output)
        (throw (ex-info "Usage: generate --input FILE --config FILE --output DIRECTORY [--native-output DIRECTORY] [--check]" {})))
      (let [native-output (get options "--native-output")
            result (generator/parse-and-generate (slurp input) (edn/read-string (slurp config-path)))
            haxe-count (write-or-check! (:files result) output (boolean (get options "--check")))
            native-count (if native-output
                           (write-or-check! (:native-files result) native-output (boolean (get options "--check")))
                           0)
            total (+ haxe-count native-count)]
        (println (if (get options "--check") "Checked" "Generated") total "files in" output
                 (if native-output (str "and " native-output) ""))))
    (catch Exception e
      (binding [*out* *err*]
        (println "WorldOfCake Layla generation failed:" (.getMessage e)))
      (System/exit 1))))
