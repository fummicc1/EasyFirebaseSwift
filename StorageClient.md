# StorageClient

StorageClient is a client that helps me use a firebase-storage interface with ease.

## About StorageReference

In StorageClient, StorageReference is either `Resource` or `Folder`.

## Resource

[`Resource`]() is a content that can store in FirebaseStorage, such as `Text`, `Image`, `Video`, `Audio` and so on.

Although Resource is content, Resouce is stored in `Folder` as one of a resouce in single folder.

## Folder

[`Folder`]() stores multiple `Resource`s.

## Usage

1. Init `StorageClient`

First of all, initialize `StorageClient` like the following.

```swift
// Option: If you want to select specific Storage, add this line.
StorageClient.defaultStorage = Storage.storage(url: "gs://easyfirebasefirestoreswift.appspot.com/")
let client = StorageClient()
```

### Upload

2. Create new `Resource` and upload

With `StorageClient`, it is possible to `upload` new resource like the following.

Because all `Resource` are under `Folder`, it is also necessary to prepare `Folder` object.

```swift
// Create Folder to store new Resource.
let folder = Folder(name: "Tests")
// TextData to store
let text: String = "Test Test Test Test Text!!"
// Text converted into Data type
let data = text.data(using: .utf8)!
// Resource, storeable content.
let resource = Resource(
    name: "test",
    metadata: Resource.Metadata(contentType: .plain),
    data: data
)
// Start uploading
client.upload(resource: resource, folder: folder)
    .sink { task in
        // task gives 3 cases.
        switch task.status {
        case .success:
            // complete task without error
            exp.fulfill()
        case .fail(let error):
            // finish task due to error
            print(error)
        case .progress(let ratio):
            // ratio is a fraction of complete-ratio, from 0 to 1.
            print(ratio)
        }
    }
    .store(in: &cancellables)
```
