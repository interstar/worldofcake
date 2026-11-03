(ns worldofcake.laylagen.rack-layout-generate
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.string :as str]
            [layla.core :as layla]
            [worldofcake.laylagen.core :as layout]
            [worldofcake.laylagen.targets :as targets]
            [worldofcake.laylagen.svg-text :as svg-text]
            [worldofcake.laylagen.icons :as icons]))

(defn- parse-args [args]
  (loop [remaining args options {}]
    (if (empty? remaining)
      options
      (let [[flag & tail] remaining]
        (if (= flag "--check")
          (recur tail (assoc options flag true))
          (let [[value & more] tail]
            (when-not value
              (throw (ex-info (str "Missing value for " flag) {})))
            (recur more (assoc options flag value))))))))

(defn- leaves [node]
  (if (= :leaf (:node-type node))
    [node]
    (mapcat leaves (:children node))))

(defn- parse-layout [source]
  (let [parsed (layla/parse-intent source)]
    (when-not (:success parsed)
      (throw (ex-info (:error parsed) {:errors (:errors parsed)})))
    (:data parsed)))

(defn- fmt [value]
  (String/format java.util.Locale/ROOT "%.4f" (to-array [(double value)])))

(defn- esc [value]
  (-> (str value)
      (str/replace "&" "&amp;")
      (str/replace "<" "&lt;")
      (str/replace ">" "&gt;")
      (str/replace "\"" "&quot;")))

(defn- cpp-name [id]
  (let [parts (remove str/blank? (str/split (layout/safe-symbol id) #"_"))]
    (str/join "" (map #(str (str/upper-case (subs % 0 1)) (subs % 1)) parts))))

(defn- output-entries [metadata]
  (vec (for [group (get-in metadata [:patch-bay :groups])
             output (:outputs group)]
         output)))

(defn- input-entries [metadata]
  (vec (for [group (get-in metadata [:patch-bay :groups])
             input (:inputs group)]
         input)))

(defn- correction-output-entries [metadata]
  (vec (for [group (get-in metadata [:patch-bay :groups])
             :when (= :correction (:key group))
             output (:outputs group)]
         output)))

(defn panel-labels
  "Static panel labels in millimetres, ready for build-time SVG outlining."
  [metadata placed]
    (let [specs (:rack-components metadata)
          groups (get-in metadata [:patch-bay :groups])
          patch (get-in metadata [:patch-bay :bounds-mm])]
      (vec (concat
        (for [node (leaves placed)
              :let [spec (get specs (:id node))
                    control? (contains? #{:knob :toggle :button :text-input} (:kind spec))
                    text (when (and (not= false (:show-label spec)) (not (:icon spec)))
                           (or (:text spec) (:svg-label spec) (when control? (:label spec))))
                    beside? (and control? (not= :below (:caption-position spec)))
                    anchor (or (:anchor spec) (if (or beside? (= :title (:kind spec))) :start :middle))]
              :when text]
          {:id (:id node) :anchor anchor :colour (or (:text-colour spec) "#3a3f48")
           :x (+ (:x node) (case anchor :start 1.5 :end (- (:width node) 1.5) (/ (:width node) 2)))
           :y (+ (:y node) (/ (:height node) 2) (if (= :below (:caption-position spec)) 5.0 0.0))
           :size (or (:font-size-mm spec) (if (= :title (:kind spec)) 3.8 2.4)) :text text})
        (for [column (get-in metadata [:patch-bay :columns])]
          {:id (str "patch-column-" (name (:key column)))
           :x (:x-mm column) :y (get-in metadata [:patch-bay :header-y-mm] 17.5)
           :size 2.3 :text (:label column)})
        (for [group groups :let [b (:bounds-mm group)] :when (:label group)]
          {:id (str "patch-group-" (name (:key group)))
           :x (+ (:x b) (/ (:width b) 2)) :y (+ (:y b) (:height b) -2.2)
           :size 2.1 :text (:label group)})
        (mapcat (fn [group]
                  (when (:inputs group)
                    (let [b (:bounds-mm group)]
                      (for [[suffix y text] [["in" (+ (:y b) 6) "IN"] ["out" (+ (:y b) (:height b) -2) "OUT"]]]
                        {:id (str "patch-" (name (:key group)) "-" suffix) :anchor :start
                         :x (+ (:x b) 0.9) :y y :size 1.5 :text text})))) groups)
        (when patch
          [{:id "patch-title" :x (+ (:x patch) (/ (:width patch) 2)) :y (+ (:y patch) (:height patch) 6)
            :size 2.5 :text (get-in metadata [:patch-bay :title] "Outputs")}])))))

(defn- render-cpp [metadata placed]
  (let [specs (:rack-components metadata)
        panel (:panel (get-in metadata [:module]))
        nodes (into {} (map (juxt :id identity) (leaves placed)))
        controls (->> nodes
                      (keep (fn [[id node]]
                              (when (contains? #{:knob :toggle :button :text-input} (:kind (get specs id)))
                                [id node])))
                      (sort-by first))
        outputs (output-entries metadata)
        inputs (input-entries metadata)
        correction-outputs (correction-output-entries metadata)]
    (str "// Generated by WorldOfCake Rack Layla/EDN. Do not edit directly.\n"
         "#pragma once\n\n"
         "namespace worldofcake { namespace rack { namespace " (name (:app metadata)) " {\n"
         "struct RackRect { float x; float y; float width; float height; };\n"
         "struct RackPoint { float x; float y; };\n"
         "constexpr float kPanelWidth = " (fmt (:width-mm panel)) "f;\n"
         "constexpr float kPanelHeight = " (fmt (:height-mm panel)) "f;\n"
         (apply str
                (for [[id node] controls]
                  (let [name (cpp-name id)]
                    (str "constexpr RackPoint k" name "Center{" (fmt (+ (:x node) (/ (:width node) 2))) "f, "
                         (fmt (+ (:y node) (/ (:height node) 2))) "f};\n"))))
         (let [node (get nodes "playarea")]
           (str "constexpr RackRect kPlayarea{" (fmt (:x node)) "f, " (fmt (:y node)) "f, "
                (fmt (:width node)) "f, " (fmt (:height node)) "f};\n"))
         "constexpr int kLayoutInputCount = " (count inputs) ";\n"
         "constexpr RackPoint kInputPositions[kLayoutInputCount] = {\n"
         (apply str (for [input inputs]
                      (let [p (:socket-mm input)]
                        (str "    {" (fmt (:x p)) "f, " (fmt (:y p)) "f},\n"))))
         "};\n"
         "constexpr int kLayoutOutputCount = " (count outputs) ";\n"
         "constexpr RackPoint kOutputPositions[kLayoutOutputCount] = {\n"
         (apply str (for [output outputs]
                      (let [p (:socket-mm output)]
                        (str "    {" (fmt (:x p)) "f, " (fmt (:y p)) "f},\n"))))
         "};\n"
         "constexpr RackPoint kCorrectionOutputPositions[" (count correction-outputs) "] = {\n"
         (apply str (for [output correction-outputs]
                      (let [p (:socket-mm output)]
                        (str "    {" (fmt (:x p)) "f, " (fmt (:y p)) "f},\n"))))
         "};\n"
         "}}} // namespace worldofcake::rack::" (name (:app metadata)) "\n")))

(defn- svg-colour [colour]
  (str "#" (str/replace colour #"^0x" "")))

(defn- svg-icon
  "An icon from the shared icon set, scaled into a size-mm square centred on (cx, cy)."
  [icon cx cy size-mm]
  (let [{:keys [path dots]} (icons/svg-path (icons/icon-ops icon))
        scale (/ size-mm 16.0)]
    (str "    <g transform=\"translate(" (fmt (- cx (/ size-mm 2))) " " (fmt (- cy (/ size-mm 2))) ") scale(" (fmt scale) ")\">"
         "<path d=\"" path "\" fill=\"none\" stroke=\"#4a453c\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
         (apply str (for [[x y r] dots] (str "<circle cx=\"" (fmt x) "\" cy=\"" (fmt y) "\" r=\"" (fmt r) "\" fill=\"#4a453c\"/>")))
         "</g>\n")))

(defn- render-svg-base [metadata placed]
  (let [specs (:rack-components metadata)
        panel (:panel (get-in metadata [:module]))
        nodes (into {} (map (juxt :id identity) (leaves placed)))
        play (get nodes "playarea")
        outputs (output-entries metadata)
        inputs (input-entries metadata)]
    (str "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
         "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:inkscape=\"http://www.inkscape.org/namespaces/inkscape\" width=\"" (:width-mm panel) "mm\" height=\"" (:height-mm panel) "mm\" viewBox=\"0 0 " (:width-mm panel) " " (:height-mm panel) "\">\n"
         "  <rect width=\"" (:width-mm panel) "\" height=\"" (:height-mm panel) "\" fill=\"" (or (:fill panel) "#ebe6dc") "\"/>\n"
         "  <rect x=\"" (fmt (:x play)) "\" y=\"" (fmt (:y play)) "\" width=\"" (fmt (:width play)) "\" height=\"" (fmt (:height play)) "\" rx=\"0.9\" fill=\"#12141a\" stroke=\"#656a76\" stroke-width=\"0.8\"/>\n"
         (apply str
                (for [{:keys [label x y width height fill fill-alpha border border-alpha]} (layout/boxes placed specs)]
                  (str "  <rect id=\"box-" (esc label) "\" x=\"" (fmt x) "\" y=\"" (fmt y) "\" width=\"" (fmt width) "\" height=\"" (fmt height) "\" rx=\"1.4\" fill=\"" (svg-colour (or fill "0xFFFFFF")) "\" fill-opacity=\"" (fmt (or fill-alpha 1.0)) "\""
                       (if border
                         (str " stroke=\"" (svg-colour border) "\" stroke-opacity=\"" (fmt (or border-alpha 1.0)) "\" stroke-width=\"0.45\"")
                         "")
                       "/>\n")))
         "  <g id=\"panel-icons\">\n"
         (apply str
                (for [[id node] nodes
                      :let [spec (get specs id)]
                      :when (:icon spec)]
                  (svg-icon (:icon spec) (+ (:x node) 3.0) (+ (:y node) (/ (:height node) 2)) 3.6)))
         "  </g>\n"
         "  <g id=\"patch-bay\">\n"
         (apply str
                (for [group (get-in metadata [:patch-bay :groups])]
                  (let [b (:bounds-mm group)]
                    (str "    <g id=\"outs-" (name (:key group)) "\">\n"
                         "      <rect x=\"" (fmt (:x b)) "\" y=\"" (fmt (:y b)) "\" width=\"" (fmt (:width b)) "\" height=\"" (fmt (:height b)) "\" rx=\"1.4\" fill=\"" (:fill group) "\" fill-opacity=\"0.09\" stroke=\"" (:color group) "\" stroke-width=\"0.45\"/>\n"
                         "    </g>\n"))))
         "  </g>\n"
         "  <g inkscape:label=\"components\" style=\"display:none\">\n"
         (apply str
                (for [input inputs
                      :let [p (:socket-mm input)]]
                  (str "    <circle cx=\"" (fmt (:x p)) "\" cy=\"" (fmt (:y p)) "\" r=\"3\" inkscape:label=\"" (esc (:svg-label input)) "\"/>\n")))
         (apply str
                (for [output outputs
                      :let [p (:socket-mm output)]]
                  (str "    <circle cx=\"" (fmt (:x p)) "\" cy=\"" (fmt (:y p)) "\" r=\"3\" inkscape:label=\"" (esc (:svg-label output)) "\"/>\n")))
         "  </g>\n"
         "</svg>\n")))

(defn- render-svg [metadata placed]
  (let [svg (render-svg-base metadata placed)]
      (str/replace svg "</svg>"
                   (str "<g id=\"panel-text\">\n"
                        (apply str (map svg-text/text-path (panel-labels metadata placed)))
                        "</g>\n</svg>"))))

(defn- safe-output [root relative]
  (let [base (.getCanonicalFile (io/file root))
        target (.getCanonicalFile (io/file base relative))
        prefix (str (.getPath base) java.io.File/separator)]
    (when-not (str/starts-with? (.getPath target) prefix)
      (throw (ex-info "Generated output escapes output directory" {:path relative})))
    target))

(defn- write-or-check! [root relative content check?]
  (let [target (safe-output root relative)]
    (if check?
      (when-not (and (.isFile target) (= content (slurp target)))
        (throw (ex-info (str "Generated Rack layout is stale: " relative) {})))
      (do (.mkdirs (.getParentFile target)) (spit target content)))))

(defn -main [& args]
  (try
    (let [options (parse-args args)
          output (get options "--output")
          native-output (get options "--native-output")
          check? (contains? options "--check")]
      (when-not (and output native-output)
        (throw (ex-info "Usage: rack-layout-generate (--app DIR --target rack | --input FILE --config FILE) --output DIRECTORY --native-output DIRECTORY [--check]" {})))
      (let [{metadata :config layla :layla} (targets/source-from-options options "--config" "--input")
            document (parse-layout layla)
            root (get-in document [:root])
            placed (layout/calculate-geometry root (:geometry metadata) (:rack-components metadata))
            svg-path (str "generated/" (get-in metadata [:application :panel-svg]))
            header-path (str "worldofcake/generated/rack/" (name (:app metadata)) "/" (get-in metadata [:module :slug]) "RackLayoutGenerated.h")]
        (write-or-check! output svg-path (render-svg metadata placed) check?)
        (write-or-check! native-output header-path (render-cpp metadata placed) check?)
        (println (if check? "Checked" "Generated") svg-path "and" header-path)))
    (catch Exception e
      (binding [*out* *err*]
        (println "Rack layout generation failed:" (.getMessage e)))
      (System/exit 1))))
