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
    public final class Subscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == Model, SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let action: FirestoreModelAction<Model>
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, action: FirestoreModelAction<Model>, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.action = action
            self.client = client
            
            switch action {
            case .create(let model):
                create(model: model)
                
            case .update(let model):
                update(model: model)
                
            case .get(let ref):
                get(ref: ref)
                
            case .snapshot(let ref):
                snapshot(ref: ref)
                
            case .delete(let ref):
                delete(ref: ref)
                
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
        
        private func get(ref: DocumentReference) {
            client.get(uid: ref.documentID) { [weak self] (model: Model) in
                _ = self?.subscriber?.receive(model)
            } failure: { [weak self] error in
                self?.subscriber?.receive(completion: .failure(error))
            }
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
    
    public final class ListSubscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == [Model], SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let action: FirestoreModelAction<Model>
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, action: FirestoreModelAction<Model>, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.action = action
            self.client = client
        }
        
        public func request(_ demand: Subscribers.Demand) {
        }
        
        public func cancel() {
            subscriber = nil
        }
        
        private func snapshot() {
            client.listen(
                filter: [],
                order: [],
                limit: nil
            ) { (models: [Model]) in
                
            } failure: { error in
                
            }

        }
        
    }
    
    public struct Publisher<Model: FirestoreModel>: Combine.Publisher {
        public typealias Output = Model
        
        public typealias Failure = Error
        
        let model: Model
        let action: FirestoreModelAction<Model>
        let firestoreClient: FirestoreClient
        
        init(model: Model, action: FirestoreModelAction<Model>, firestoreClient: FirestoreClient = FirestoreClient()) {
            self.model = model
            self.action = action
            self.firestoreClient = firestoreClient
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, Model == S.Input {
            let subscription = Subscription(
                subscriber: subscriber,
                action: action,
                firestoreClient: firestoreClient
            )
            subscriber.receive(subscription: subscription)
        }
    }
}
