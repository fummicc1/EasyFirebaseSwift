//
//  ViewController.swift
//  Example
//
//  Created by Fumiya Tanaka on 2021/05/01.
//

import Combine
import EasyFirebaseFirestore
import FirebaseFirestore
import UIKit

class ViewController: UIViewController {

    let client = FirestoreClient()
    var cancellables: Set<AnyCancellable> = []

    let savedDocumentId: String = "FirestoreExample-SampleDocument"
    var model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test") {
        didSet {
            label.text = model.message
        }
    }

    @IBOutlet private weak var label: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            try await client.write(Model(message: "Test"))
        }
        snapshots()
        super.viewDidLoad()
        Task {
            let message = getNewMessage()
            try await client.write(Model(message: message))
        }
    }

    @IBAction func update() {
        Task {
            model.message = getNewMessage()
            try await client.write(model)
        }
    }

    @IBAction func update_combine() {
        Task {
            try await client.write(Model(message: getNewMessage()))
        }
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
        Task {
            let model: Model = try await client.get(documentId: savedDocumentId)
            print(model.message)
        }
    }

    func snapshots() {
        Task {
            let stream: AsyncThrowingStream<[Model], any Error> = await client.listen()
            var iterator = stream.makeAsyncIterator()
            while let models = try await iterator.next() {
                if let model = models.first(where: { $0.id == savedDocumentId }) {
                    self.model = model
                }
            }
        }
    }
}
