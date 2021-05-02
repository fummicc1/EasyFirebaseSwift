//
//  ViewController.swift
//  Example
//
//  Created by Fumiya Tanaka on 2021/05/01.
//

import UIKit
import EasyFirebaseSwift
import FirebaseFirestoreSwift
import FirebaseFirestore

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
    
    var model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test")
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        client.write(model, merge: true) { reference in
            self.model.ref = reference
        } failure: { error in
            print(error)
        }
    }

    
    @IBAction func update() {
        model.message = "Update Test"
        client.write(model, merge: true, success: { _ in }, failure: { _ in })
    }
}

