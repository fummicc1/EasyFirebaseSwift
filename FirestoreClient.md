# FirestoreClient

FirestoreClient is a client that helps me use a firestore interface with ease.

## Model

First of all, create Model layer inheriting `FirestoreModel` protocol.

```swift

import EasyFirebaseSwift
import FirebaseFirestore

// Note: FirestoreModel inherits `Codable` Protocol
struct Model: FirestoreModel {

    // - MARK : Necessary

    // collectionName corresponding to Firestore's CollectionName.
    static var collectionName: String = "models"

    // NOTE: To use PropertyWrapper such as @DocumentID, @ServerTimestamp
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

To create a new document on Firestore, use `create` method.

Please pay attention that All of `createdAt`, `updatedAt` and `ref` are assigned `nil` value.

```swift
let client = FirestoreClient()

// Note: new model must guarantee `createdAt`, `updatedAt` and `ref` are nil.
let model = Model(
    ref: nil,
    createdAt: nil,
    updatedAt: nil,
    message: "Test"
)

client.create(model) { reference in
    model.ref = reference
} failure: { error in
    print(error)
}
```

## Update

Using `update` method, we can update an existing model.

Like `create` method, we have to guarantee model's metadata (`createdAt`, `updatedAt`, `ref`) are not `nil` value.

```swift
let client = FirestoreClient()

// In this case, we fetch an exsisting data from Firestore.
client.get(uid: "example_1234567890") { model in
    var model = model
    model.message = "Update Test"

    // Note: updated model must guarantee `createdAt`, `updatedAt` and `ref` are NOT nil.
    client.update(model) { reference in
        model.ref = reference
    } failure: { error in
        print(error)
    }
} failure: { error in
    print(error)
}
```

## Read

If we want to get snapshots once, we should use `get` method, on the other hand, if we want to fetch the latest data whenever database is updated, we should use `listen` method.

## Get (fetch once)

`get` is used like the following.

Note: It is necessary to specify the type of reponse model by giving `concrete type`(not `existential type`) at closure parameter like the following.

### Collection (Multiple Documents)

```swift
client.get(
    filter: [],
    order: [],
    limit: nil
) { (models: [Model]) in // Here, we need to specify concrete type of responsed model.
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

`listen` also specifies which model we want by giving `concrete type` at closure parameter like the following.

### Collection (Multiple Documents)

```swift
client.listen(
    filter: [],
    order: [],
    limit: nil
) { (models: [Model]) in // Here, we need to specify concrete type of responsed model.
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

## Combine (Experimental)

Supporting Combine!

if you want to check the practical usage, please see [this file]().

### Combine.Create

```swift
// Create
model.publisher(for: .create).sink { error in
    print(error)
} receiveValue: { }
.store(in: &cancellables)

```

### Combine.Get

```swift
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

## Swift Concurrency (async/await) (Experimental)

We are supporting Swift Concurrency after v1.5.0 !!

if you want to check the practical usage, please see [this file]().

## Filter

It is possible to filter documents.

Core interface to filter documents is `FirestoreQueryFilter`.

In practice, I have prepared two classes `FirestoreEqualFilter` and `FirestoreRangeFilter`.

Please see the following code as an example useCase for `FirestoreEqualFilter`.

```swift
// Create Filter
let equalFilter = FirestoreEqualFilter(
    fieldPath: "message",
    value: "Update Text"
)

// Apply Filter
client.listen(
    filter: [equalFilter],
    order: [],
    limit: nil
)
{ (models: [Model]) in
    // Ensure all response pass the filtering.
    let messageChecking = models.allSatisfy { model in
        model.message == "Update Text"
    }
    // Do All models have `Update Text`? → YES
    assert(messageChecking)
} failure: { error in
    print(error)
}

```

## SubCollection

:construction: WIP

## CollectionGroup

:construction: WIP
