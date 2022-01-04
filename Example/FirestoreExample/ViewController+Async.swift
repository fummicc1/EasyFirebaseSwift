//
//  ViewController+Async.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import Foundation

extension ViewController {
    func create_async(message: String) async throws {
        let newModel = Model(
            ref: nil,
            createdAt: nil,
            updatedAt: nil,
            message: message
        )
        try await client.create(newModel)
    }
}
