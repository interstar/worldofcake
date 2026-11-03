(ns worldofcake.laylagen.gbloink-rack-test
  (:require [clojure.test :refer [deftest is]]
            [layla.core :as layla]
            [worldofcake.laylagen.core :as core]
            [worldofcake.laylagen.targets :as targets]
            [worldofcake.laylagen.svg-text :as svg-text]
            [clojure.java.io :as io]
            [worldofcake.laylagen.rack-layout-generate :as rack]))

(defn fixture []
  (let [{:keys [config layla]} (targets/resolve-target "apps/gbloink" :rack)
        root (get-in (layla/parse-intent layla) [:data :root])]
    [config (core/calculate-geometry root (:geometry config) (:rack-components config))]))
(defn leaves [node]
  (if (= :leaf (:node-type node)) [node] (mapcat leaves (:children node))))
(defn near [a b] (< (Math/abs (- a b)) 0.00001))

(deftest rack-layout-keeps-world-and-voice-alignment
  (let [[config placed] (fixture)
        nodes (into {} (map (juxt :id identity) (leaves placed)))
        world (nodes "playarea")]
    (is (near (/ (:width world) (:height world)) 1.4))
    (doseq [[speed volume group] (map vector ["redspeed" "greenspeed" "bluespeed"]
                                    ["redvelocity" "greenvelocity" "bluevelocity"]
                                    (get-in config [:patch-bay :groups]))]
      (let [a (nodes speed) b (nodes volume)]
        (is (near (+ (:y a) (/ (:height a) 2)) (:y-mm group)))
        (is (near (:y a) (:y b)))
        (is (>= (:width a) 16))))
    (is (= 9 (count (mapcat :outputs (get-in config [:patch-bay :groups])))))
    (doseq [id ["reset" "pause" "mute" "edge-notes"]]
      (is (>= (:width (nodes id)) 9)))))

(deftest labels-are-complete-svg-artwork
  (let [[config placed] (fixture)
        labels (rack/panel-labels config placed)
        texts (set (map :text labels))
        cpp (#'rack/render-cpp config placed)
        svg (#'rack/render-svg config placed)]
    (doseq [text ["Speed" "Volume" "Scale" "Note length" "Reset" "Pause" "Mute" "Walls"]]
      (is (contains? texts text))
      (is (not (.contains cpp (pr-str text))))
      (is (.contains svg (str "data-text=\"" text "\""))))
    (is (not (.contains cpp "kPanelLabels")))
    (is (.contains svg "id=\"panel-text\""))
    (is (not (.contains svg "<text")))
    (is (= [121.92 8.0] ((juxt :x :y) (first labels))))
    (is (= 16 (count labels)))
    (is (= svg (#'rack/render-svg config placed)))))

(deftest outlines-are-stable-and-font-errors-are-explicit
  (let [label {:id "sample" :text "Volume & O" :x 30 :y 10 :size 2.7}
        expected (svg-text/text-path label)
        previous (java.util.Locale/getDefault)]
    (is (.contains expected "data-text=\"Volume &amp; O\""))
    (is (.contains expected "Q"))
    (try
      (java.util.Locale/setDefault java.util.Locale/GERMANY)
      (is (= expected (svg-text/text-path label)))
      (finally (java.util.Locale/setDefault previous)))
    (is (thrown-with-msg? clojure.lang.ExceptionInfo #"Missing glyph.*U\+0378"
                         (svg-text/text-path (assoc label :text "\u0378"))))))

(deftest every-rack-panel-outlines-static-text
  (doseq [app ["gbloink" "timeslider" "kdiagram" "tileland" "zewp" "goldenpond"]]
    (let [options (if (.isFile (io/file "apps" app "app.edn"))
                    {"--app" (str "apps/" app) "--target" "rack"}
                    {"--config" (str "layouts/rack/" app ".edn") "--input" (str "layouts/rack/" app ".layla")})
          {:keys [config layla]} (targets/source-from-options options "--config" "--input")
          placed (core/calculate-geometry (get-in (layla/parse-intent layla) [:data :root])
                                         (:geometry config) (:rack-components config))
          svg (#'rack/render-svg config placed)]
      (is (not (.contains svg "<text")) app)
      (is (.contains svg "id=\"panel-text\"" ) app))))
