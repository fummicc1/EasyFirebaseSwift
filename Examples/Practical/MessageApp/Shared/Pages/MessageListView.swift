//
//  MessageListView.swift
//  MessageApp
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import SwiftUI

struct MessageListView: View {

    @EnvironmentObject var repository: RepositoryImpl

    var body: some View {
        Text("Hello, World!")
    }
}

struct MessageListView_Previews: PreviewProvider {
    static var previews: some View {
        MessageListView()
    }
}
