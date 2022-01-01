//
//  ViewController.swift
//  Example
//
//  Created by Fumiya Tanaka on 2021/05/01.
//

import FirebaseFirestoreSwift
import EasyFirebaseSwift
import FirebaseFirestore
import Combine
import UIKit

struct Model: FirestoreModel {
    
    static var collectionName: String = "models"
    
    @DocumentID
    var ref: DocumentReference?
    
    @ServerTimestamp
    var createdAt: Timestamp?
    
    @ServerTimestamp
    var updatedAt: Timestamp?
    
    var message: String
}

class ViewController: UIViewController {
    
    private let client = FirestoreClient()
    private var cancellables: Set<AnyCancellable> = []
    
    var model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create New Document
        create()
        
        // Observe
        
        // All Collection
        snapshots()
        
        // With Filter
        filter()
        
    }
    
    // MARK: Update
    @IBAction func update() {
        model.message = "Update Test"
        client.update(model, success: {  }, failure: { _ in })
    }
    
    // MARK: GET
    func get() {
        
        // Using Closure
        // Get single Document
        client.get(uid: "1234567890") { (model: Model) in
            print(model.message)
        } failure: { error in
            print(error)
        }
        
        // Using Combine
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
    
    // MARK: Snapshots
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
    
    // MARK: Filter
    func filter() {
        let equalFilter = FirestoreEqualFilter(fieldPath: "message", value: "Update Text")
        client.listen(
            filter: [equalFilter],
            order: [],
            limit: nil)
        { (models: [Model]) in
            let messageChecking = models.allSatisfy { model in
                model.message == "Update Text"
            }
            // Do All models have `Update Text`?
            assert(messageChecking)
        } failure: { error in
            print(error)
        }

    }
    
    // MARK: Create
    func create() {
        model.publisher(for: .create).sink { error in
            print(error)
        } receiveValue: { }
        .store(in: &cancellables)
    }
}

