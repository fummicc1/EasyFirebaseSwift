# EasyFirebaseFirestoreSwift
An Easy CloudFirestore Library written in Swift.

# Usage

## Model

First of all, create Model layer extending FirestoreModel protocol.

```swift

import EasyFirebaseFirestoreSwift
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

Both `get` and `listen` specifies which model we want by giving concrete type at closure parameter like the following.

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


