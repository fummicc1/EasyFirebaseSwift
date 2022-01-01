//
//  ViewController.swift
//  Example
//
//  Created by Fumiya Tanaka on 2021/05/01.
//

import EasyFirebaseSwift
import FirebaseFirestore
import Combine
import UIKit

class ViewController: UIViewController {
    
    let client = FirestoreClient()
    var cancellables: Set<AnyCancellable> = []
    
    var model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        snapshots()
    }

    @IBAction func update() {
        model.message = "Update Test"
        client.update(model, success: {  }, failure: { _ in })
    }

    func get() {
        // Get single Document
        client.get(uid: "1234567890") { (model: Model) in
            print(model.message)
        } failure: { error in
            print(error)
        }
    }

    func snapshots() {
        // MARK: Collection (by empty filter)
        client.listen(
            filter: [],
            order: [],
            limit: nil
        ) { (models: [Model]) in
            for model in models {
                if model.ref == self.model.ref {
                    self.model = model
                }
            }
        } failure: { error in
            print(error)
        }
    }
    
    func create() {
        model.publisher(for: .create).sink { error in
            print(error)
        } receiveValue: { }
        .store(in: &cancellables)
    }
}

