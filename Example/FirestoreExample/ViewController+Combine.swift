//
//  ViewController+Combine.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import Foundation
import FirebaseFirestore
import EasyFirebaseSwift

extension ViewController {
    func create_combine() {
        model.publisher(for: .create).sink { error in
            print(error)
        } receiveValue: { }
        .store(in: &cancellables)
    }

    func get_combine() {
        let ref = Firestore.firestore().collection("models").document("sample")
        Model.publisher(for: .get(ref: ref)).sink { completion in
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
