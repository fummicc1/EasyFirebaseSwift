//
//  RootView.swift
//  Shared
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var repository: RepositoryImpl

    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
