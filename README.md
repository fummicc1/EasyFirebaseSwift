# EasyFirebaseSwift
An Easy Firebase (Auth / Firestore) Library written in Swift.

# Installation

Supporting SwiftPackageManager (SPM).

```swift
.package(url: "https://github.com/fummicc1/EasyFirebaseSwift", .upToNextMinor(from: "1.1.0"))
```

# Usage

## Model

First of all, create Model layer extending FirestoreModel protocol.

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

## Create / Update

Both create and update can achieve by using `write` method.

```swift
let client = FirestoreClient()
let model = Model(ref: nil, createdAt: nil, updatedAt: nil, message: "Test")

client.write(model, merge: true) { reference in
    model.ref = reference
} failure: { error in
    print(error)
}
```

## Read

If we want to get snapshots once, we should use `get` method, on the other hand, if we want to fetch the latest data whenever database is updated, we should use `listen` method.

Both `get` and `listen` specify which model we want by giving concrete type at closure parameter like the following.

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


# Contributing

Pull requests, bug reports and feature requests are welcome 🚀
