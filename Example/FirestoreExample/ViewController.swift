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
    
    var model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test") {
        didSet {
            label.text = model.message
        }
    }

    @IBOutlet private weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        create_combine(message: "Test")
        snapshots()
    }

    @IBAction func update() {
        model.message = getNewMessage()
        client.update(model, success: {  }, failure: { _ in })
    }

    @IBAction func update_combine() {
        create_combine(message: getNewMessage())
    }

    @IBAction func update_async() {
        Task {
            do {
                try await create_async(message: getNewMessage())
            } catch {
                print(error)
            }
        }
    }

    private func getNewMessage() -> String {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let message = "Update Test at \(formatter.string(from: now))"
        return message
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
}

