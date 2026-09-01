(ns worldofcake.laylagen.test-runner
  (:require [clojure.test :as test]
            [worldofcake.laylagen.core-test]))

(defn -main [& _]
  (let [{:keys [fail error]} (test/run-tests 'worldofcake.laylagen.core-test)]
    (when (pos? (+ fail error))
      (System/exit 1))))
