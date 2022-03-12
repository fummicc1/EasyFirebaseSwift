# StorageClient

StorageClient is a client that helps me use a firebase-storage interface with ease.

## About StorageReference

In StorageClient, StorageReference is either `Resource` or `Folder`.

## Resource

[`Resource`]() is a content that can store in FirebaseStorage, such as `Text`, `Image`, `Video`, `Audio` and so on.

Although Resource is content, Resouce is stored in `Folder` as one of a resouce in single folder.

|"My Photo" is `Resource`|
|---|
|<img width="400" alt="スクリーンショット 2022-03-13 0 27 45" src="https://user-images.githubusercontent.com/44002126/158024933-e515253b-6bed-424b-9339-53a958cd1685.png">|

## Folder

All of `Resource`s are in `Folder`.
There are three kinds of `Folder`.

### HomeFolder

`HomeFolder` is at the real root of folder.

### RootFolder

`RootFolder` is a child of `HomeFolder`.
Although `HomeFolder` is ensured to be single, `RootFolder` can be multiple.
So, this is root `Folder` created by developers.

### SubFolder

`SubFolder` is a child of `RootFolder`.


|"StorageExample" is `RootFolder`|
|---|
|<img width="400" alt="スクリーンショット 2022-03-13 0 43 10" src="https://user-images.githubusercontent.com/44002126/158024941-ba431261-bd21-483c-99ad-c9bf42340b08.png">|


## Usage

1. Init `StorageClient`.

First of all, configure `StorageClient.shared.storage` with own `FirebaseStorage.Storage`.

```swift
// Option: If you want to select specific Storage, add this line.
StorageClient.shared.storage = Storage.storage()
```

### Upload

2. Create new `Resource` and upload.

It is possible to `upload` new resource like the following.

Because all `Resource` are under `Folder`, it is also necessary to set parent folder at `Resource.folder`.

```swift
func upload_photo() {
    let folder = RootFolder(name: "Tests")
    let text: String = "Test Test Test Test Text!!"
    let data = text.data(using: .utf8)!
    let resource = Resource(
        name: "test",
        folder: folder,
        metadata: Resource.Metadata(contentType: .plain),
        data: data
    )
    // Start uploading
    resource.uploadWithData()
        .sink { task in
            switch task.status {
            case .success:
                print("OK")
            case .fail(let error):
                print(error)
            case .progress(let fractionComplete):
                print(fractionComplete)
            default:
                break
            }
        }
        .store(in: &cancellables)
}
```

## Resource.Task

Documentation is work in progress.


