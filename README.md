# EasyFirebaseSwift
An Easy Firebase (Auth / Firestore) Library written in Swift.

# Installation

Supporting SwiftPackageManager (SPM).

```swift
.package(url: "https://github.com/fummicc1/EasyFirebaseSwift", .upToNextMajor(from: "1.3.0"))
```

# Usage

## Model

First of all, create Model layer inheriting `FirestoreModel` protocol.

```swift

import EasyFirebaseSwift
import FirebaseFirestoreSwift
import FirebaseFirestore

struct Model: FirestoreModel {

    // - MARK : Necessary
    // the identifier to use when we observe single document within this model's collection.
    static var singleIdentifier: String = "model"
    
    // the identifier to use when we observe collection of this model.
    static var arrayIdentifier: String = "models"
    
    // collectionName corresponding to Firestore's collection schema.
    static var collectionName: String = "models"
    
    // To use PropertyWrapper such as @DocumentID, @ServerTimestamp, we need to import FirebaseFirestoreSwift.
    @DocumentID
    var ref: DocumentReference?
    
    @ServerTimestamp
    var createdAt: Timestamp?
    
    @ServerTimestamp
    var updatedAt: Timestamp?
    
    // - MARK : Custom property
    
    var message: String
}
```

## Create

`Create` can be used like the following.

```swift
let client = FirestoreClient()

// Note: - new model must guarantee `createdAt`, `updatedAt` and `ref` are nil.
let model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test")

client.create(model) { reference in
    model.ref = reference
} failure: { error in
    print(error)
}
```

## Update 

`Update` can be used in this way.

```swift
let client = FirestoreClient()

// In this case, we fetch an exsisting data from Firestore.
client.get(uid: "example_1234567890") { model in
    var model = model
    model.message = "Update Test"

    // Note: - updated model must guarantee `createdAt`, `updatedAt` and `ref` are NOT nil.
    client.update(model) { reference in
        model.ref = reference
    } failure: { error in
        print(error)
    }
} failure: { error in
    print(error)
}
```

## Write

`Write` is actually either `create` or `update` method. according to `merge` parameter.

## Read

If we want to get snapshots once, we should use `get` method, on the other hand, if we want to fetch the latest data whenever database is updated, we should use `listen` method.

## Get

`get` is used like the following.

Note: It is necessary that we specify the type of reponse model by giving concrete type at closure parameter like the following.

### Collection (Multiple Documents)

```swift
client.get(
    filter: [],
    order: [],
    limit: nil
) { (models: [Model]) in // Here, we need to specify concrete type at parameter of closure.
    for model in models {
        print(model.message)
    }
} failure: { error in
    print(error)
}
```

### Single Document

```swift
client.get(uid: "1234567890") { (model: Model) in
    print(model.message)
} failure: { error in
    print(error)
}
```

## Listen(Snapshot)

We can achieve both **single observation** and **query observation** of a certain collection at the same time!

`listen` also specifies which model we want by giving concrete type at closure parameter like the following.

### Collection (Multiple Documents)

```swift
client.listen(
    filter: [],
    order: [],
    limit: nil
) { (models: [Model]) in // Here, we need to specify concrete type at parameter of closure.
    for model in models {
        print(model.message)
    }
} failure: { error in
    print(error)
}
```

### Single Document

```swift
client.listen(uid: "1234567890") { (model: Model) in
    print(model.message)
} failure: { error in
    print(error)
}
```

## Combine

Supporting Combine! 

See [example](https://github.com/fummicc1/EasyFirebaseSwift/blob/18fed270daf6c58721b67b1584c2976f893e933d/Example/Example/ViewController.swift#L81-L101) to check the usage.

```swift
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
```

# Contributing

Pull requests, bug reports and feature requests are welcome 🚀
