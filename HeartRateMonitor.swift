//
//  HeartRateMonitor.swift
//  Beats
//
//  Created by Raphael Hanneken on 14/01/2017.
//  Copyright © 2017 Raphael Hanneken. All rights reserved.
//

import Foundation
import HealthKit

class HeartRateMonitor: NSObject, HKWorkoutSessionDelegate {

    let healthStore: HKHealthStore!

    let sampleType: HKQuantityType!

    let unit: HKUnit!

    var workoutSession: HKWorkoutSession?

    var queryAnchor: HKQueryAnchor!

    // MARK: Methods

    init(withHealthStore _: HKHealthStore? = nil) throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HeartRateMonitorError.healthDataNotAvailable
        }

        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HeartRateMonitorError.initializingQuantityTypeHeartRateFailed
        }

        self.sampleType = quantityType
        self.healthStore = HKHealthStore()
        self.unit = HKUnit(from: "count/min")

        super.init()

        self.requestHealthStoreAuthorization()
    }

    func workoutSession(_: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from _: HKWorkoutSessionState,
                        date: Date) {
        switch toState {
        case .running:
            self.healthStore.execute(createHeartRateStreamingQuery(withStartDate: date))
            NSLog("Workout started.")
        default:
            return
        }
    }

    func workoutSession(_: HKWorkoutSession, didFailWithError error: Error) {
        NSLog("Workout failed with error: \(error)")
    }

    // MARK: Methods - Private

    func startWorkoutSession() throws {
        if self.workoutSession != nil {
            return
        }

        let workout = try HKWorkoutSession(configuration: configureWorkoutSession())
        workout.delegate = self

        self.healthStore.start(workout)
        self.workoutSession = workout
    }

    fileprivate func configureWorkoutSession() -> HKWorkoutConfiguration {
        let workoutConfig = HKWorkoutConfiguration()

        workoutConfig.activityType = .walking
        workoutConfig.locationType = .indoor

        return workoutConfig
    }

    fileprivate func createHeartRateStreamingQuery(withStartDate startDate: Date) -> HKAnchoredObjectQuery {
        let date = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [date])
        let heartRateQuery = HKAnchoredObjectQuery(type: self.sampleType,
                                                   predicate: predicate,
                                                   anchor: self.queryAnchor,
                                                   limit: HKObjectQueryNoLimit,
                                                   resultsHandler: self.queryResultsHandler)

        heartRateQuery.updateHandler = self.queryResultsHandler

        return heartRateQuery
    }

    @objc
    public func queryResultsHandler(_: HKAnchoredObjectQuery,
                                    samples: [HKSample]?,
                                    deletedObjects _: [HKDeletedObject]?,
                                    anchor _: HKQueryAnchor?,
                                    error _: Error?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {
            return
        }

        DispatchQueue.main.async {
            guard let sample = heartRateSamples.first else {
                return
            }
            NSLog("Heart Rate Sample: \(sample.quantity.doubleValue(for: self.unit))")
        }
    }

    fileprivate func requestHealthStoreAuthorization() {
        healthStore?.requestAuthorization(toShare: nil, read: [self.sampleType]) { success, _ in
            if success {
                NSLog("Authorization to access HealthKit data granted.")
            }
        }
    }
}

enum HeartRateMonitorError: Error {
    case healthDataNotAvailable
    case initializingQuantityTypeHeartRateFailed
}
