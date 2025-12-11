import EasyFirebaseFirestore
import FirebaseFirestore
import Foundation

struct Message: FirestoreModel {

    /// Firestore上に保存される際のコレクション名
    static var collectionName: String = "messages"

    /// データの作成時刻
    @ServerTimestamp
    var createdAt: Timestamp?

    /// データの更新時刻
    @ServerTimestamp
    var updatedAt: Timestamp?

    /// データの参照
    @DocumentID
    var ref: DocumentReference?

    /// メッセージ
    var text: String

    /// 投稿したユーザー
    var sender: String
}

// MARK: Identifiable for SwiftUI
extension Message: Identifiable {
    typealias ID = String?
}
