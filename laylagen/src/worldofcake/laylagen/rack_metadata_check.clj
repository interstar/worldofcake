(ns worldofcake.laylagen.rack-metadata-check
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.string :as str]))

(defn- parse-args [args]
  (loop [remaining args options {}]
    (if (empty? remaining)
      options
      (let [[flag value & more] remaining]
        (when-not value
          (throw (ex-info (str "Missing value for " flag) {})))
        (recur more (assoc options flag value))))))

(defn- fail [message detail]
  {:ok? false :message message :detail detail})

(defn- read-file [path]
  (slurp (io/file path)))

(defn- output-entries [metadata]
  (for [group (get-in metadata [:patch-bay :groups])
        output (:outputs group)]
    (assoc output :group-key (:key group))))

(defn- contains-token? [content token]
  (str/includes? content token))

(defn- check-token [kind content token]
  (when-not (contains-token? content token)
    (fail (str "Missing " kind) token)))

(defn- check-all-tokens [kind content tokens detail]
  (let [missing (remove #(contains-token? content %) tokens)]
    (when (seq missing)
      (fail (str "Missing " kind) {:expected detail :missing (vec missing)}))))

(defn- output-id-enum-body [hpp]
  (second (re-find #"(?s)enum\s+OutputIds\s*\{(.*?)NUM_OUTPUTS" hpp)))

(defn- declared-output-ids [hpp]
  (let [body (output-id-enum-body hpp)]
    (when-not body
      (throw (ex-info "Could not find enum OutputIds body" {})))
    (->> (re-seq #"\b[A-Z][A-Z0-9_]*_OUTPUT\b" body)
         distinct
         vec)))

(defn- decimal-token [n]
  (let [d (double n)]
    (if (== d (Math/floor d))
      (str (long d))
      (str d))))

(defn- svg-circle-token [socket]
  (str "cx=\"" (decimal-token (:x socket)) "\" cy=\"" (decimal-token (:y socket)) "\""))

(defn- svg-circle-tokens [socket]
  [(svg-circle-token socket)
   (str "cx=\"" (String/format java.util.Locale/ROOT "%.4f" (to-array [(double (:x socket))]))
        "\" cy=\"" (String/format java.util.Locale/ROOT "%.4f" (to-array [(double (:y socket))])) "\"")])

(defn- check-svg-socket [svg output]
  (when-let [socket (:socket-mm output)]
    (when-not (some #(contains-token? svg %) (svg-circle-tokens socket))
      (fail "Missing SVG socket coordinate" {:expected (svg-circle-tokens socket)}))))

(defn- check-cpp-socket [cpp output]
  (when-let [socket (:socket-mm output)]
    (let [tokens (or (:cpp-coordinate-fragments output)
                     [(decimal-token (:x socket)) (decimal-token (:y socket))])]
      (check-all-tokens "C++ socket coordinate fragments" cpp tokens {:cpp-id (:cpp-id output)
                                                                       :socket-mm socket}))))

(defn- check-output [hpp cpp generated svg output]
  (let [config-fragments (or (:config-label-fragments output) [(:config-label output)])
        config-source (str cpp "\n" generated)]
    (remove nil?
            [(check-token "C++ OutputId" hpp (:cpp-id output))
             (check-all-tokens "generated/configOutput label fragments" config-source config-fragments (:config-label output))
             (check-token "SVG placeholder label" svg (:svg-label output))
             (check-svg-socket svg output)
             (check-cpp-socket cpp output)])))

(defn- check-output-count [hpp outputs]
  (let [declared (declared-output-ids hpp)]
    (when-not (= (count declared) (count outputs))
      (fail "Output count mismatch" {:metadata (count outputs)
                                      :cpp (count declared)
                                      :cpp-output-ids declared}))))

(defn- check-output-order [hpp outputs]
  (let [declared (declared-output-ids hpp)
        expected (mapv :cpp-id outputs)]
    (when-not (= declared expected)
      (fail "OutputId order mismatch" {:metadata expected
                                        :cpp declared}))))

(defn- check-metadata [metadata module-dir generated-root]
  (let [;; Rack source filenames are still app-specific by case, so infer them from module slug.
        slug (get-in metadata [:module :slug])
        app (name (:app metadata))
        source-base (or slug (throw (ex-info "Missing :module :slug" {})))
        hpp (read-file (io/file module-dir "src" (str source-base ".hpp")))
        source-cpp (read-file (io/file module-dir "src" (str source-base ".cpp")))
        generated (if generated-root
                    (let [path (io/file generated-root "worldofcake" "generated" "rack" app (str source-base "RackOutputsGenerated.h"))]
                      (if (.isFile path) (read-file path) ""))
                    "")
        generated-layout (if generated-root
                           (let [path (io/file generated-root "worldofcake" "generated" "rack" app (str source-base "RackLayoutGenerated.h"))]
                             (if (.isFile path) (read-file path) ""))
                           "")
        svg-path (io/file module-dir "generated" (str source-base ".svg"))
        svg (if (.isFile svg-path)
              (read-file svg-path)
              (read-file (io/file module-dir "res" (str source-base ".svg"))))
        cpp (str source-cpp "\n" generated-layout)
        outputs (vec (output-entries metadata))]
    (concat
     (when (empty? outputs)
       [(fail "Metadata has no outputs" (:app metadata))])
     [(check-output-count hpp outputs)
      (check-output-order hpp outputs)]
     (mapcat #(check-output hpp cpp generated svg %) outputs))))

(defn -main [& args]
  (try
    (let [options (parse-args args)
          metadata-path (get options "--metadata")
          module-dir (get options "--module-dir")
          generated-root (get options "--generated-root")]
      (when-not (and metadata-path module-dir)
        (throw (ex-info "Usage: rack-metadata-check --metadata FILE --module-dir DIR [--generated-root DIR]" {})))
      (let [metadata (edn/read-string (slurp metadata-path))
            failures (vec (remove nil? (check-metadata metadata module-dir generated-root)))]
        (if (seq failures)
          (do
            (binding [*out* *err*]
              (println "Rack metadata check failed for" metadata-path)
              (doseq [failure failures]
                (println "-" (:message failure) ":" (:detail failure))))
            (System/exit 1))
          (println "Rack metadata check passed for" metadata-path "(" (count (output-entries metadata)) "outputs )"))))
    (catch Exception e
      (binding [*out* *err*]
        (println "Rack metadata check failed:" (.getMessage e)))
      (System/exit 1))))
