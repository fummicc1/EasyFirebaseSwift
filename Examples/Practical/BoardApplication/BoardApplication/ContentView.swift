import Foundation
import SwiftUI

struct ContentView: View {

    @ObservedObject var model: Model = Model()
    @State private var blurOpacityAnimation: Double = 1
    private var hideAddView: Bool {
        blurOpacityAnimation == 0
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    VStack {
                        List {
                            ForEach(model.list, id: \.id) { message in
                                HStack {
                                    Text(message.sender)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .font(.body)
                                    Text(message.text)
                                        .font(.body)
                                }
                                .padding()
                            }
                        }
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
                if hideAddView {
                    Button {
                        withAnimation(.easeInOut) {
                            blurOpacityAnimation = 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(Color(UIColor.systemBackground))
                    }
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .alignmentGuide(.trailing) { d in
                        d.width + 16
                    }
                    .alignmentGuide(.bottom) { d in
                        d.height + 16
                    }

                } else {
                    VStack {
                        VStack {
                            Text("New Message")
                                .font(.title3)
                                .bold()
                            TextEditor(text: $model.newMessageText)
                                .lineLimit(3)
                                .padding(4)
                                .frame(height: 120)
                            Divider()
                            TextField("NickName", text: $model.nickName)
                                .padding(4)
                        }
                        .background(Color(UIColor.systemBackground))
                        .padding()
                        .cornerRadius(8)
                        Spacer().frame(height: 8)
                        HStack {
                            Button {
                                withAnimation(.easeInOut) {
                                    blurOpacityAnimation = 0
                                }
                            } label: {
                                Text("Hide")
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.systemBackground))
                            }
                            .padding()
                            .background(Color.secondary)
                            .clipShape(Circle())
                            Spacer()
                            Button {
                                Task {
                                    await model.create()
                                }
                            } label: {
                                Label("Create", systemImage: "plus")
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.systemBackground))
                            }
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                    }
                    .padding(4)
                    .shadow(radius: 4)
                    .opacity(blurOpacityAnimation)
                }
            }
            .navigationTitle("掲示板")
        }.navigationViewStyle(.stack)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
