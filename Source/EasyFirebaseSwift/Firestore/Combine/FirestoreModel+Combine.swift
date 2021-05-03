//
//  FirestoreModel+Combine.swift
//  
//
//  Created by Fumiya Tanaka on 2021/05/03.
//

import Foundation
import FirebaseFirestore
import Combine

public enum FirestoreModelCombine {
    public final class Subscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == Model, SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let ref: DocumentReference
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, ref: DocumentReference, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.ref = ref
            self.client = client
            
            client.listen(ref: ref) { (model: Model) in
                _ = subscriber.receive(model)
            } failure: { error in
                subscriber.receive(completion: .failure(error))
            }
        }
        
        public func request(_ demand: Subscribers.Demand) {
        }
        
        public func cancel() {
            subscriber = nil
        }
    }
    
    public final class ListSubscription<SubscriberType: Subscriber, Model: FirestoreModel>: Combine.Subscription where SubscriberType.Input == [Model], SubscriberType.Failure == Swift.Error {
        
        private var subscriber: SubscriberType?
        private let query: Query
        private let client: FirestoreClient
        
        public init(subscriber: SubscriberType, query: Query, firestoreClient client: FirestoreClient) {
            self.subscriber = subscriber
            self.query = query
            self.client = client
            
            client.listen(ref: query) { (model: [Model]) in
                _ = subscriber.receive(model)
            } failure: { error in
                subscriber.receive(completion: .failure(error))
            }
        }
        
        public func request(_ demand: Subscribers.Demand) {
        }
        
        public func cancel() {
            subscriber = nil
        }
        
        
    }
}
