(ns worldofcake.laylagen.targets-test
  (:require [clojure.test :refer [deftest is]]
            [worldofcake.laylagen.core :as generator]
            [worldofcake.laylagen.targets :as targets]))

(deftest overlays-merge-deeply
  (is (= {:a {:b 1 :c 3} :d [9]}
         (targets/deep-merge {:a {:b 1 :c 2} :d [1 2] :e 5} {:a {:c 3} :d [9] :e nil}))))

(def lanes-config
  {:model {:lanes 3}
   :palettes {:lanes ["0x111111" "0x222222"]}
   :components {"lane{n}track" {:repeat :lanes :kind :timeslider-track :colour [:palette :lanes]
                                :label "Lane {n}" :label-control "lane{n}label"}
                "lane{n}label" {:repeat :lanes :kind :text-input :default "Lane {n}"}
                "reset" {:kind :button :label "Reset"}}
   :outputs [{:repeat :lanes :id "lane{n}" :label "Lane {n}" :channel 1 :cc :n}]})

(deftest repeats-expand-per-lane
  (let [expanded (targets/expand-repeats lanes-config)
        components (:components expanded)]
    (is (= #{"lane1track" "lane2track" "lane3track" "lane1label" "lane2label" "lane3label" "reset"}
           (set (keys components))))
    (is (= {:kind :timeslider-track :colour "0x111111" :label "Lane 3" :label-control "lane3label" :repeat-index 3}
           (get components "lane3track"))
        "{n} is substituted, the palette cycles, and the copy knows its index")
    (is (= "0x222222" (get-in components ["lane2track" :colour])))
    (is (= [{:id "lane1" :label "Lane 1" :channel 1 :cc 1}
            {:id "lane2" :label "Lane 2" :channel 1 :cc 2}
            {:id "lane3" :label "Lane 3" :channel 1 :cc 3}]
           (:outputs expanded)))
    (is (= {:components {"x" {:kind :button}}} (targets/expand-repeats {:components {"x" {:kind :button}}}))
        "a config without repeats is unchanged")))

(deftest repeats-need-a-model-count
  (is (thrown-with-msg? clojure.lang.ExceptionInfo #"positive integer"
                        (targets/expand-repeats (dissoc lanes-config :model)))))

(def model-only-config
  (-> lanes-config
      (assoc :model {:lanes 2}
             :application {:id "timeslider" :package "timeslider" :generated-package "generated.timeslider"
                           :composition-kind :timeslider :composition-class "TimeSliderCompositionGenerated"
                           :layout-class "TimeSliderLayoutGenerated"}
             :sequencer {:minimum-travel-time 120.0 :maximum-travel-time 0.5})
      targets/expand-repeats))

(deftest model-only-generation-has-no-layout
  (let [result (generator/generate-model model-only-config)
        files (:files result)
        tracks (get files "generated/timeslider/TimeSliderTracksGenerated.hx")
        ids (get files "generated/timeslider/TimeSliderControlIdsGenerated.hx")
        metadata (get-in result [:native-files "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"])]
    (is (= #{"generated/timeslider/TimeSliderTracksGenerated.hx" "generated/timeslider/TimeSliderControlIdsGenerated.hx"
             "generated/timeslider/TimeSliderModelGenerated.hx"}
           (set (keys files)))
        "no layout or composition classes")
    (is (not-any? #(re-find #"juce/" %) (keys (:native-files result))))
    ;; Model order: plain components by ID, then each repeat copy in lane order.
    (is (re-find #"RESET:Int = 1" ids))
    (is (re-find #"LANE1LABEL:Int = 2" ids))
    (is (re-find #"LANE1TRACK:Int = 3" ids))
    (is (re-find #"LANE2LABEL:Int = 4" ids))
    (is (re-find #"LANE2TRACK:Int = 5" ids))
    (is (re-find #"TRACK_COUNT:Int = 2" tracks))
    (is (re-find #"TRACK_UIDS\(default, never\):Array<Int> = \[ControlIds.LANE1TRACK, ControlIds.LANE2TRACK\]" tracks))
    (is (re-find #"constexpr std::size_t kLaneCount = 2" metadata))))

(deftest model-constants-are-generated-for-every-target
  (let [result (generator/generate-model model-only-config)
        model (get-in result [:files "generated/timeslider/TimeSliderModelGenerated.hx"])
        metadata (get-in result [:native-files "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"])]
    (is (re-find #"public static inline var LANES:Int = 2;" model))
    (is (re-find #"PALETTE_LANES\(default, never\):Array<Int> = \[0x111111, 0x222222\]" model))
    (is (re-find #"namespace model \{
constexpr int kLanes = 2;" metadata))
    (is (re-find #"std::array<std::uint32_t, 2> kPaletteLanes\{\{0x111111, 0x222222\}\}" metadata))))

(deftest model-references-resolve
  (is (= {:model {:world-width 600} :components {"playarea" {:kind :play-area :local-width 600}}}
         (targets/resolve-model-refs {:model {:world-width 600}
                                      :components {"playarea" {:kind :play-area :local-width [:model :world-width]}}})))
  (is (thrown-with-msg? clojure.lang.ExceptionInfo #"No \[:model :depth\]"
                        (targets/resolve-model-refs {:model {} :components {"x" {:a [:model :depth]}}}))))

(deftest migrated-worlds-come-from-the-model
  (doseq [[app width height] [["zewp" 600 560] ["tileland" 600 600]]]
    (doseq [target [:openfl :rack]]
      (let [{:keys [config]} (targets/resolve-target (str "apps/" app) target)]
        (is (= [width height] ((juxt :world-width :world-height) (:model config))) [app target])))
    (let [{:keys [config]} (targets/resolve-target (str "apps/" app) :openfl)]
      (is (= [width height] ((juxt :local-width :local-height) (get-in config [:components "playarea"])))
          "the OpenFL play area's local space is the model's world"))))
