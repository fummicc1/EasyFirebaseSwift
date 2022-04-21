//
//  MessageListModel.swift
//  MessageApp
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import Foundation
import Combine

class MessageListModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var startMessage: String?

    private var uid: String?

    private let repository: Repository
    private var cancellables: Set<AnyCancellable> = []

    init(repository: Repository) {
        self.repository = repository

        repository.uid.sink { uid in
            self.uid = uid
        }.store(in: &cancellables)
        
        repository.messages.assign(to: &$messages)
    }

    func createBroadcastMessage() async {
        guard let startMessage = startMessage,
              let uid = uid else {
            return
        }
        let message = Message(
            text: startMessage,
            senderID: uid,
            receiverID: nil
        )
        do {
            try await repository.saveMessage(message)
        } catch {
            print(error)
        }
    }
}
