import Combine
import EasyFirebaseSwift
import Foundation

@MainActor
class Model: ObservableObject {

    @Published var list: [Message] = []
    @Published var nickName: String = ""
    @Published var newMessageText: String = ""

    private var cancellables: Set<AnyCancellable> = []
    private let firestoreClient: FirestoreClient = FirestoreClient()

    init() {
        let action = FirestoreModelTypeAction<Message>
            .snapshots(SnapshotInputParameter.Default())
        Message.multiple(for: action, client: firestoreClient)
            .sink { _ in
            } receiveValue: { messages in
                self.list = messages
            }
            .store(in: &cancellables)
    }

    func create() async {

        if nickName.isEmpty {
            return
        }

        if newMessageText.isEmpty {
            return
        }

        let newMessage = Message(
            text: newMessageText,
            sender: nickName
        )
        do {
            try await firestoreClient.create(newMessage)
            newMessageText = ""
        } catch {
            print(error)
        }
    }
}
