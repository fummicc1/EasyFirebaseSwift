//
//  CombineCore.swift
//  
//
//  Created by Fumiya Tanaka on 2021/06/23.
//

import Foundation
import FirebaseFirestore
import Combine

public enum FirestoreModelCombine {
}

// MARK: Single Write
public extension FirestoreModelCombine {
    final class WriteSubscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == Void, SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let model: Model
        private let action: FirestoreModelAction<Model>
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, model: Model, action: FirestoreModelAction<Model>, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.model = model
            self.action = action
            self.client = client
            
            switch action {
            case .create:
                create(model: model)
                
            case .update:
                update(model: model)
                
            case .delete:
                guard let ref = model.ref else {
                    assertionFailure()
                    return
                }
                delete(ref: ref)
            }
            
        }
        public func request(_ demand: Subscribers.Demand) {
        }
        
        public func cancel() {
            subscriber = nil
        }
        
        private func create(model: Model) {
            client.create(model) { [weak self] _ in
                self?.subscriber?.receive(completion: .finished)
            } failure: { [weak self] error in
                self?.subscriber?.receive(completion: .failure(error))
            }
        }
        
        private func update(model: Model) {
            client.update(model) { [weak self] in
                self?.subscriber?.receive(completion: .finished)
            } failure: { [weak self] error in
                self?.subscriber?.receive(completion: .finished)
            }
            
        }
        
        private func delete(ref: DocumentReference) {
            client.delete(id: ref.documentID, type: Model.self) { [weak self] error in
                if let error = error {
                    self?.subscriber?.receive(completion: .failure(error))
                } else {
                    self?.subscriber?.receive(completion: .finished)
                }
            }
            
        }
    }
    
    struct WritePublisher<Model: FirestoreModel>: Combine.Publisher {
        public typealias Output = Void
        
        public typealias Failure = Error
        
        let model: Model
        let action: FirestoreModelAction<Model>
        let firestoreClient: FirestoreClient
        
        init(model: Model, action: FirestoreModelAction<Model>, firestoreClient: FirestoreClient = FirestoreClient()) {
            self.model = model
            self.action = action
            self.firestoreClient = firestoreClient
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, Void == S.Input {
            let subscription = WriteSubscription(
                subscriber: subscriber,
                model: model,
                action: action,
                firestoreClient: firestoreClient
            )
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: Single Fetch
public extension FirestoreModelCombine {
    final class FetchSubscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == Model, SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let action: FirestoreModelTypeAction<Model>
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, action: FirestoreModelTypeAction<Model>, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.action = action
            self.client = client
            
            switch action {
            case let .fetch(ref):
                fetch(ref: ref)
                
            case let .snapshot(ref):
                snapshot(ref: ref)
                
            default:
                assertionFailure()
                break
            }
            
        }
        
        public func request(_ demand: Subscribers.Demand) {
        }
        
        public func cancel() {
            subscriber = nil
        }
        
        private func snapshot(ref: DocumentReference) {
            client.listen(ref: ref) { [weak self] (model: Model) in
                _ = self?.subscriber?.receive(model)
            } failure: { [weak self] error in
                self?.subscriber?.receive(completion: .failure(error))
            }
        }
        
        private func fetch(ref: DocumentReference) {
            client.get(uid: ref.documentID) { [weak self] (model: Model) in
                _ = self?.subscriber?.receive(model)
            } failure: { [weak self] error in
                self?.subscriber?.receive(completion: .failure(error))
            }
        }
    }
    
    struct FetchPublisher<Model: FirestoreModel>: Combine.Publisher {
        public typealias Output = Model
        
        public typealias Failure = Error
        
        let action: FirestoreModelTypeAction<Model>
        let firestoreClient: FirestoreClient
        
        init(action: FirestoreModelTypeAction<Model>, firestoreClient: FirestoreClient = FirestoreClient()) {
            self.action = action
            self.firestoreClient = firestoreClient
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, Model == S.Input {
            let subscription = FetchSubscription(subscriber: subscriber, action: action, firestoreClient: firestoreClient)
            subscriber.receive(subscription: subscription)
        }
    }
}
