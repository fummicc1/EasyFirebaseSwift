//
//  ViewController+Combine.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import Foundation
import FirebaseFirestore
import EasyFirebaseSwiftFirestore

extension ViewController {
    func create_combine(message: String) {
        let newModel = Model(
            ref: nil,
            createdAt: nil,
            updatedAt: nil,
            message: message
        )
        newModel.write(for: .createWithDocumentId(savedDocumentId)).sink { completion in
            print(completion)
        } receiveValue: { }
        .store(in: &cancellables)
    }

    func fetch_combine() {
        guard let ref = model.ref else {
            return
        }
        Model.single(for: .fetch(ref: ref)).sink { completion in
            switch completion {
            case .failure(let error):
                print(error)
            case .finished:
                break
            }
        } receiveValue: { model in
            print(model.message)
        }
        .store(in: &cancellables)
    }
}
