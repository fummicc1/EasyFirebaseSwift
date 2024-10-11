//
//  ViewController+Filter.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import EasyFirebaseFirestore
import Foundation

extension ViewController {
    func filter() async {
        let equalFilter = FirestoreEqualFilter(
            fieldPath: "message",
            value: "Update Text"
        )
        let stream: AsyncThrowingStream<[Model], any Error> = await client.listen(filter: [equalFilter])
        var iterator = stream.makeAsyncIterator()
        do {
            while let model = try await iterator.next() {
                if model.isEmpty == false && model.allSatisfy({ $0.message == "Update Text" }) {
                    print("Update Text is included")
                }
            }
        } catch {
            print(error)
        }
    }
}
