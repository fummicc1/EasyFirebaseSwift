import EasyFirebaseFirestore
import Foundation

@MainActor
class Model: ObservableObject {

    @Published var list: [Message] = []
    @Published var nickName: String = ""
    @Published var newMessageText: String = ""

    private var listenerTask: Task<Void, Never>?
    private let firestoreClient: FirestoreClient = FirestoreClient()

    init() {
        listenerTask = Task {
            do {
                for try await messages in await firestoreClient.listen() as AsyncThrowingStream<[Message], Error> {
                    self.list = messages
                }
            } catch {
                print("Error listening to messages: \(error)")
            }
        }
    }

    deinit {
        listenerTask?.cancel()
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
            try await firestoreClient.write(newMessage)
            newMessageText = ""
        } catch {
            print(error)
        }
    }
}
