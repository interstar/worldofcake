(ns worldofcake.laylagen.targets
  "Resolves one app for one target: `apps/<app>/app.edn` with the target's overlay
  (`<target>.edn`, following `:extends`) deep-merged on top, and the target's layout
  (`<target>.layla`, or the nearest one up the `:extends` chain). See docs/APP_TARGETS.md."
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.string :as str]))

(defn deep-merge
  "Merge `overlay` over `base`. Maps merge key by key, recursively; any other value in the
  overlay replaces the base's. A key whose overlay value is nil is removed."
  [base overlay]
  (if (and (map? base) (map? overlay))
    (reduce-kv (fn [merged k v]
                 (cond
                   (nil? v) (dissoc merged k)
                   (contains? merged k) (assoc merged k (deep-merge (get merged k) v))
                   :else (assoc merged k v)))
               base
               overlay)
    overlay))

(defn- read-edn [file]
  (edn/read-string (slurp file)))

;; Repetition. A component or output with `:repeat :lanes` stands for one copy per
;; n = 1 .. (:lanes (:model config)). In a copy, "{n}" in any string becomes n, the value
;; :n becomes the number n, and [:palette :lanes] becomes the n-th colour of
;; (:lanes (:palettes config)), cycling. Each copy carries :repeat-index n.

(defn- substitute [value n palettes]
  (cond
    (string? value) (str/replace value "{n}" (str n))
    (= value :n) n
    (and (vector? value) (= :palette (first value)))
    (let [palette (get palettes (second value))]
      (when (empty? palette)
        (throw (ex-info (str "No palette " (second value)) {:palette (second value)})))
      (nth palette (mod (dec n) (count palette))))
    (map? value) (into {} (for [[k v] value] [k (substitute v n palettes)]))
    (vector? value) (mapv #(substitute % n palettes) value)
    :else value))

(defn- repeat-count [config repeat-key]
  (let [n (get-in config [:model repeat-key])]
    (when-not (and (int? n) (pos? n))
      (throw (ex-info (str ":repeat " repeat-key " needs a positive integer at [:model " repeat-key "]") {:repeat repeat-key})))
    n))

(defn- copies [config spec]
  (for [n (range 1 (inc (repeat-count config (:repeat spec))))]
    [n (-> (dissoc spec :repeat) (substitute n (:palettes config)) (assoc :repeat-index n))]))

(defn expand-repeats
  "Expand every `:repeat` component and output (see above). A config without repeats is unchanged."
  [config]
  (cond-> config
    (:components config)
    (update :components
            (fn [components]
              (into {} (mapcat (fn [[id spec]]
                                 (if (:repeat spec)
                                   (for [[n copy] (copies config spec)] [(str/replace id "{n}" (str n)) copy])
                                   [[id spec]]))
                               components))))
    (:outputs config)
    (update :outputs
            (fn [outputs]
              (vec (mapcat (fn [output]
                             (if (:repeat output)
                               (map (comp #(dissoc % :repeat-index) second) (copies config output))
                               [output]))
                           outputs))))))

;; Model references. A component value [:model k] becomes (k (:model config)), so a play area's
;; local space can name the model's world size instead of repeating it.

(defn resolve-model-refs
  "Replace every [:model k] in components with the model's value for k."
  [config]
  (let [model (:model config)
        resolve (fn resolve [value]
                  (cond
                    (and (vector? value) (= :model (first value)) (= 2 (count value)))
                    (if (contains? model (second value))
                      (get model (second value))
                      (throw (ex-info (str "No [:model " (second value) "] for reference") {:key (second value)})))
                    (map? value) (into {} (for [[k v] value] [k (resolve v)]))
                    (vector? value) (mapv resolve value)
                    :else value))]
    (cond-> config
      (:components config) (update :components resolve))))

(defn- target-file [app-dir target extension]
  (io/file app-dir (str (name target) extension)))

(defn- overlay-chain
  "The target and its `:extends` ancestors, nearest first."
  [app-dir target]
  (loop [target (keyword (name target)) chain []]
    (when (some #{target} chain)
      (throw (ex-info (str "Cyclic :extends through " target) {:chain chain})))
    (let [file (target-file app-dir target ".edn")]
      (when-not (.isFile file)
        (throw (ex-info (str "No overlay for target " (name target) ": " (.getPath file)) {:target target})))
      (let [overlay (read-edn file)
            chain (conj chain target)]
        (if-let [parent (:extends overlay)]
          (recur (keyword (name parent)) chain)
          chain)))))

(defn resolve-target
  "Resolved config and layout source for one app directory and target. Returns
  {:config merged-config, :layla layout-source-or-nil, :chain [target parent ...]}."
  [app-dir target]
  (let [app-file (io/file app-dir "app.edn")]
    (when-not (.isFile app-file)
      (throw (ex-info (str "No app definition: " (.getPath app-file)) {:app-dir app-dir})))
    (let [chain (overlay-chain app-dir target)
          overlay (reduce (fn [merged t] (deep-merge merged (dissoc (read-edn (target-file app-dir t ".edn")) :extends)))
                          {}
                          (reverse chain))
          layout (some (fn [t] (let [f (target-file app-dir t ".layla")] (when (.isFile f) (slurp f)))) chain)]
      {:config (resolve-model-refs (expand-repeats (deep-merge (read-edn app-file) overlay)))
       :layla layout
       :chain chain})))

(defn source-from-options
  "Config and layout from command-line options: either `--app DIR --target T`, or the
  legacy single files given by `config-flag` and (when non-nil) `layout-flag`."
  [options config-flag layout-flag]
  (if-let [app-dir (get options "--app")]
    (let [target (or (get options "--target")
                     (throw (ex-info "--app needs --target" {})))
          {:keys [config layla]} (resolve-target app-dir target)]
      (when (and layout-flag (nil? layla))
        (throw (ex-info (str "No layout for target " target " in " app-dir) {})))
      {:config config :layla layla})
    (let [config-path (get options config-flag)
          layout-path (when layout-flag (get options layout-flag))]
      (when-not (and config-path (or (nil? layout-flag) layout-path))
        (throw (ex-info (str "Give --app DIR --target T, or " config-flag " FILE"
                             (when layout-flag (str " and " layout-flag " FILE"))) {})))
      {:config (resolve-model-refs (expand-repeats (read-edn config-path)))
       :layla (when layout-path (slurp layout-path))})))
