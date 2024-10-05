//
//  ViewController.swift
//  StorageExample
//
//  Created by Fumiya Tanaka on 2022/03/12.
//

import Combine
import EasyFirebaseSwiftStorage
import FirebaseStorage
import Photos
import PhotosUI
import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!

    var cancellables: Set<AnyCancellable> = []
    var image: UIImage? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = self?.image
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        StorageClient.shared.storage = Storage.storage()
    }

    @IBAction func didTapImagePickerButton() {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            config.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        } else {
            let picker = UIImagePickerController(rootViewController: self)
            picker.sourceType = .photoLibrary
            picker.delegate = self
            present(picker, animated: true, completion: nil)
        }
    }

    @IBAction func didTapDoneButton() {
        guard let image = image else {
            return
        }
        let imageData = image.jpegData(compressionQuality: 1.0)
        let folder = RootFolder(name: "StorageExample")
        let metaData = Resource.Metadata(contentType: .jpeg)
        let resource = Resource(
            name: "My Photo",
            folder: folder,
            metadata: metaData,
            data: imageData
        )
        resource.upload()
            .sink { task in
                switch task.status {
                case .progress(let fractionComplete):
                    print(fractionComplete)
                case .success:
                    break
                case .fail(let error):
                    print(error)
                }
            }.store(in: &cancellables)
    }
}

@available(iOS 14, *)
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard let result = results.first else {
            return
        }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(
                ofClass: UIImage.self
            ) { [weak self] image, error in
                if let error = error {
                    print(error)
                } else {
                    self?.image = image as? UIImage
                }
            }
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

@available(iOS, introduced: 14, unavailable)
extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true, completion: nil)
        let image = info[.originalImage] as? UIImage
        self.image = image
    }
}
