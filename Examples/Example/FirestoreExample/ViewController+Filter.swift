//
//  ViewController+Filter.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import EasyFirebaseSwiftFirestore
import Foundation

extension ViewController {
    func filter() {
        let equalFilter = FirestoreEqualFilter(
            fieldPath: "message",
            value: "Update Text"
        )
        client.listen(
            filter: [equalFilter],
            order: [],
            limit: nil
        ) { (models: [Model]) in
            let messageChecking = models.allSatisfy { model in
                model.message == "Update Text"
            }
            // Do All models have `Update Text`?
            // fail if condition is false.
            assert(messageChecking)
        } failure: { error in
            print(error)
        }

    }
}
