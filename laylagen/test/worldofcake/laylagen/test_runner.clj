(ns worldofcake.laylagen.test-runner
  (:require [clojure.test :as test]
            [worldofcake.laylagen.core-test]
            [worldofcake.laylagen.gbloink-rack-test]
            [worldofcake.laylagen.targets-test]))

(defn -main [& _]
  (let [{:keys [fail error]} (test/run-tests 'worldofcake.laylagen.core-test 'worldofcake.laylagen.targets-test 'worldofcake.laylagen.gbloink-rack-test)]
    (when (pos? (+ fail error))
      (System/exit 1))))
