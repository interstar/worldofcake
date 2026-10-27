(ns woc.editor.test-runner
  (:require [clojure.test :refer :all]
            [clojure.edn :as edn]
            [clojure.java.io :as io]
            [layla.core :as layla]
            [worldofcake.laylagen.core :as generator]
            [woc.editor.model :as model]
            [woc.editor.edn :as panel-edn]
            [woc.editor.server :as server]))

(deftest production-geometry-parity
  (doseq [app model/apps]
    (testing app
      (let [pair (server/read-panel app)
            config (edn/read-string (:edn pair))
            expected (generator/calculate-geometry (:root (:data (layla/parse-intent (:layla pair))))
                                                  (:geometry config) (:components config))
            actual (:placed (model/panel (:layla pair) config))]
        (is (= expected actual) "Every container and leaf rectangle matches production")))))

(deftest invalid-edits
  (let [pair (server/read-panel "gbloink") config (edn/read-string (:edn pair))]
    (is (thrown? Exception (model/panel "[broken" config)))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:geometry :outer-padding] 10000))))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:components "redspeed" :minimum] 0))))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:components "redspeed" :kind] :unknown))))
    (is (thrown? Exception (model/panel (:layla pair) (update config :components dissoc "redspeed"))))
    (is (thrown? Exception (server/file-for "../gbloink" "edn")))))

(deftest complete-edn
  (is (= {:a 1} (panel-edn/read-one "{:a 1} ;; a trailing comment\n")))
  (is (thrown? Exception (panel-edn/read-one "{:a 1} broken")))
  (is (thrown? Exception (panel-edn/read-one "{:a 1} }")))
  (is (thrown? Exception (panel-edn/read-one "; empty"))))

(deftest choice-range-support
  (let [pair (server/read-panel "timeslider")
        config (edn/read-string (:edn pair))
        expanded (:config (model/panel (:layla pair) config))
        channel (get-in expanded [:components "lane1channel"])
        cc (get-in expanded [:components "lane1cc"])]
    (is (= 16 (count (:choices channel))))
    (is (= {:value 1 :label "Ch 1"} (first (:choices channel))))
    (is (= {:value 16 :label "Ch 16"} (last (:choices channel))))
    (is (= 128 (count (:choices cc))))
    (is (= {:value 1 :label "CC 1"} (nth (:choices cc) (:default-index cc))))
    (is (nil? (:choice-range channel)))
    (when-let [production-expand (ns-resolve 'worldofcake.laylagen.core 'expand-specs)]
      (is (= (production-expand config) expanded)))
    (is (thrown? Exception (model/expand-specs {:components {"bad" {:choice-range {:from 16 :to 1}}}})))))

(deftest save-roundtrip-and-conflict
  ;; Exercise the real save path only against a temporary repository, never user files.
  (let [temp (.toFile (java.nio.file.Files/createTempDirectory "woc-panel-editor-test" (make-array java.nio.file.attribute.FileAttribute 0)))
        layout (io/file temp "layouts/openfl") pair (server/read-panel "gbloink")]
    (.mkdirs layout)
    (try
      (with-redefs [server/root temp]
        (spit (server/file-for "gbloink" "layla") (:layla pair) :encoding "UTF-8")
        (spit (server/file-for "gbloink" "edn") (:edn pair) :encoding "UTF-8")
        (let [before (server/read-panel "gbloink")
              edited (update before :edn str "\n;; roundtrip ✓\n")
              saved (server/save-panel! "gbloink" edited)]
          (is (= (:edn edited) (:edn saved)))
          (is (not= (:revision before) (:revision saved)))
          (is (= 409 (:status (ex-data (try (server/save-panel! "gbloink" before) (catch Exception e e))))))
          (is (thrown? Exception (server/save-panel! "gbloink" (assoc saved :layla "[invalid"))))
          (is (= saved (server/read-panel "gbloink")))) )
      (finally
        (doseq [file (reverse (file-seq temp))] (.delete file))))))

(defn -main [& _]
  (println "Layla parser source:" (str (io/resource "layla/core.cljc")))
  (let [result (run-tests 'woc.editor.test-runner)]
    (System/exit (if (zero? (+ (:fail result) (:error result))) 0 1))))
