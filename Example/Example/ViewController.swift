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
    static var singleIdentifier: String = "model"
    
    static var arrayIdentifier: String = "models"
    
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
        
        // MARK: Closure
        
        // Snapshot for Collection
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
        
        // Create
        client.create(model) { reference in
            self.model.ref = reference
        } failure: { error in
            print(error)
        }
        
        // Get single Document
        client.get(uid: "1234567890") { (model: Model) in
            print(model.message)
        } failure: { error in
            print(error)
        }
        
        // Snapshot for single Document
        client.listen(uid: "1234567890") { (model: Model) in
            print(model.message)
        } failure: { error in
            print(error)
        }
        
        // MARK: Combine
        
        // Create
        model.publisher(for: .create).sink { error in
            print(error)
        } receiveValue: { }
        .store(in: &cancellables)
                
        // Get
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
    
    @IBAction func update() {
        model.message = "Update Test"
        client.update(model, success: {  }, failure: { _ in })
    }
}

