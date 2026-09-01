(ns worldofcake.laylagen.core-test
  (:require [clojure.test :refer [deftest is testing]]
            [worldofcake.laylagen.core :as generator]))

(def base-config
  {:generator-version 1
   :application {:id "test" :package "gbloink" :generated-package "generated.test"
                 :composition-class "CompositionGenerated" :layout-class "LayoutGenerated"}
   :geometry {:panel-width 930.0 :panel-height 600.0 :outer-padding 50.0
              :root-gap 20.0 :nested-gap 10.0}
   :components {"playarea" {:kind :play-area :uid-expression "Gbloink.PLAY_AREA_UID"
                            :local-width 700.0 :local-height 500.0}
                "redspeed" {:kind :slider :uid 10 :minimum 0.5 :maximum 4.0 :default 2.0
                            :vertical true :colour "0xFF0000"}
                "greenspeed" {:kind :slider :uid 11 :minimum 0.5 :maximum 4.0 :default 2.0
                              :vertical true :colour "0x00FF00"}
                "bluespeed" {:kind :slider :uid 12 :minimum 0.5 :maximum 4.0 :default 2.0
                             :vertical true :colour "0x0000FF"}}})

(def layout "<playarea/gbloinkplayarea(70) <redspeed/speedslider greenspeed/speedslider bluespeed/speedslider>(11)>")

(deftest geometry-preserves-gbloink-composition
  (let [result (generator/parse-and-generate layout base-config)
        geometry (read-string (get-in result [:files "generated/test/geometry.edn"]))
        leaves (letfn [(walk [n] (if (= :leaf (:node-type n)) [n] (mapcat walk (:children n))))]
                 (into {} (map (juxt :id identity) (walk geometry))))]
    (is (= 50.0 (get-in leaves ["playarea" :x])))
    (is (= 700.0 (get-in leaves ["playarea" :width])))
    (is (= 500.0 (get-in leaves ["playarea" :height])))
    (is (= [770.0 810.0 850.0] (mapv #(get-in leaves [% :x]) ["redspeed" "greenspeed" "bluespeed"])))
    (is (= [30.0 30.0 30.0] (mapv #(get-in leaves [% :width]) ["redspeed" "greenspeed" "bluespeed"])))))

(deftest deterministic-generated-files
  (let [a (generator/parse-and-generate layout base-config)
        b (generator/parse-and-generate layout base-config)]
    (is (= a b))
    (is (= #{"generated/test/LayoutGenerated.hx"
             "generated/test/CompositionGenerated.hx"
             "generated/test/geometry.edn"}
           (set (keys (:files a)))))
    (is (re-find #"Do not edit directly" (get-in a [:files "generated/test/LayoutGenerated.hx"])))
    (is (re-find #"new Slider" (get-in a [:files "generated/test/CompositionGenerated.hx"])))))

(deftest quoted-ids-and-safe-symbols
  (is (= "multi_word_label" (generator/safe-symbol "Multi Word Label")))
  (is (= "component_12_speed" (generator/safe-symbol "12 Speed"))))

(deftest rejects-missing-and-unknown-components
  (is (thrown-with-msg? clojure.lang.ExceptionInfo #"Missing component configuration"
                        (generator/parse-and-generate "[unknown/custom]" (assoc base-config :components {}))))
  (is (thrown-with-msg? clojure.lang.ExceptionInfo #"Unused component configuration"
                        (generator/parse-and-generate "[playarea/gbloinkplayarea]" base-config))))

(deftest rejects-target-symbol-collisions
  (let [config (assoc base-config :components
                      {"a-b" {:kind :slider} "a_b" {:kind :slider}})]
    (is (thrown-with-msg? clojure.lang.ExceptionInfo #"Target-symbol collision"
                          (generator/parse-and-generate "[a-b/slider a_b/slider]" config)))))

(def timeslider-layout
  "<[cc1label/label(20) cc1track/timeslidertrack(504)] [cc2label/label(20) cc2track/timeslidertrack(504)] [cc3label/label(20) cc3track/timeslidertrack(504)] [cc4label/label(20) cc4track/timeslidertrack(504)]>")

(def timeslider-components
  (into {}
        (mapcat (fn [n]
                  [[(str "cc" n "label") {:kind :drawn-label :text (str "CC" n)}]
                   [(str "cc" n "track") {:kind :timeslider-track :channel 1 :cc-number n}]])
                (range 1 5))))

(def timeslider-config
  {:generator-version 1
   :application {:id "timeslider" :package "timeslider" :generated-package "generated.timeslider"
                 :composition-kind :timeslider :composition-class "TimeSliderCompositionGenerated"
                 :layout-class "TimeSliderLayoutGenerated"}
   :geometry {:panel-width 800.0 :panel-height 600.0
              :padding-left 24.0 :padding-right 24.0 :padding-top 28.0 :padding-bottom 48.0
              :root-gap 12.0 :nested-gap 0.0}
   :sequencer {:minimum-travel-time 120.0 :maximum-travel-time 0.5}
   :components timeslider-components})

(deftest timeslider-proves-second-consumer
  (let [result (generator/parse-and-generate timeslider-layout timeslider-config)
        geometry (read-string (get-in result [:files "generated/timeslider/geometry.edn"]))
        leaves (letfn [(walk [n] (if (= :leaf (:node-type n)) [n] (mapcat walk (:children n))))]
                 (into {} (map (juxt :id identity) (walk geometry))))
        composition (get-in result [:files "generated/timeslider/TimeSliderCompositionGenerated.hx"])]
    (is (= [24.0 215.0 406.0 597.0]
           (mapv #(get-in leaves [(str "cc" % "track") :x]) (range 1 5))))
    (is (= 48.0 (get-in leaves ["cc1track" :y])))
    (is (= 179.0 (get-in leaves ["cc1track" :width])))
    (is (= 504.0 (get-in leaves ["cc1track" :height])))
    (is (= 28.0 (get-in leaves ["cc1label" :y])))
    (is (re-find #"buildTracks" composition))
    (is (re-find #"TRACK_COUNT:Int = 4" composition))
    (is (= 4 (count (re-seq #"new TimeSlider\(" composition))))))

(def standard-panel-layout
  "<playarea/custom(600) [controltop/spacer(30) <redspeed/speedslider(3) greenspeed/speedslider(3) bluespeed/speedslider(3) speedend/spacer(2)>(150) controlmiddle/spacer(50) <channel/channelslider(12) channelend/spacer(1)>(30) controlbottom/spacer(340)](140)>")

(defn standard-panel-config [app-name play-hint]
  {:generator-version 1
   :application {:id app-name :package app-name :generated-package (str "generated." app-name)
                 :composition-kind :worldofcake-components :composition-class "CompositionGenerated"
                 :layout-class "LayoutGenerated" :sequencer-class "Sequencer" :view-class "View"}
   :geometry {:panel-width 800.0 :panel-height 640.0
              :padding-left 20.0 :padding-right 20.0 :padding-top 20.0 :padding-bottom 20.0
              :root-gap 20.0 :nested-gap 0.0 :gaps-by-depth {0 20.0 1 0.0 2 10.0}}
   :components {"playarea" {:kind :play-area :uid-expression "Sequencer.PLAY_AREA_UID"
                            :local-min-x 0.0 :local-min-y 0.0 :local-max-x 600.0 :local-max-y 600.0}
                "redspeed" {:kind :slider :uid 10 :minimum 1.0 :maximum 8.0 :default 2.0 :vertical true :colour "0xFF0000"}
                "greenspeed" {:kind :slider :uid 11 :minimum 1.0 :maximum 8.0 :default 2.0 :vertical true :colour "0x00FF00"}
                "bluespeed" {:kind :slider :uid 12 :minimum 1.0 :maximum 8.0 :default 2.0 :vertical true :colour "0x0000FF"}
                "channel" {:kind :slider :uid 20 :minimum 1.0 :maximum 14.0 :default 7.0 :vertical false :colour "0x808080" :view-hook "setChannelSlider"}
                "controltop" {:kind :spacer} "controlmiddle" {:kind :spacer}
                "controlbottom" {:kind :spacer} "speedend" {:kind :spacer} "channelend" {:kind :spacer}}})

(deftest standard-worldofcake-panel-reuse
  (doseq [app ["kdiagram" "tileland"]]
    (let [result (generator/parse-and-generate standard-panel-layout (standard-panel-config app "custom"))
          geometry (read-string (get-in result [:files (str "generated/" app "/geometry.edn")]))
          leaves (letfn [(walk [n] (if (= :leaf (:node-type n)) [n] (mapcat walk (:children n))))]
                   (into {} (map (juxt :id identity) (walk geometry))))
          composition (get-in result [:files (str "generated/" app "/CompositionGenerated.hx")])]
      (is (= [20.0 20.0 600.0 600.0]
             (mapv #(get-in leaves ["playarea" %]) [:x :y :width :height])))
      (is (= [640.0 680.0 720.0]
             (mapv #(get-in leaves [% :x]) ["redspeed" "greenspeed" "bluespeed"])))
      (is (= [50.0 150.0] (mapv #(get-in leaves ["redspeed" %]) [:y :height])))
      (is (= [640.0 250.0 120.0 30.0]
             (mapv #(get-in leaves ["channel" %]) [:x :y :width :height])))
      (is (= 4 (count (re-seq #"new Slider\(" composition))))
      (is (re-find #"view\.setChannelSlider" composition)))))

(deftest semantic-select-generation
  (let [config {:generator-version 1
                :application {:id "selecttest" :package "selecttest" :generated-package "generated.selecttest"
                              :composition-kind :worldofcake-components :composition-class "CompositionGenerated"
                              :layout-class "LayoutGenerated" :sequencer-class "Sequencer" :view-class "View"}
                :geometry {:panel-width 120.0 :panel-height 40.0 :outer-padding 0.0 :root-gap 0.0 :nested-gap 0.0}
                :components {"choice" {:kind :semantic-select :uid 30 :default-index 1 :presentation "segmented"
                                       :choices [{:value 0 :label "One" :colour "0xFF0000"}
                                                 {:value 1 :label "Two" :colour "0x00FF00"}]}}}
        result (generator/parse-and-generate "<choice/semanticselect>" config)
        composition (get-in result [:files "generated/selecttest/CompositionGenerated.hx"])]
    (is (re-find #"new SemanticSelect" composition))
    (is (re-find #"\[\"One\", \"Two\"\]" composition))
    (is (re-find #"\"segmented\"" composition))))
