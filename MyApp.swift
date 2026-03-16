import SwiftUI

@main
struct MyApp: App {
    // 状態を保持するStoreを生成
    @StateObject private var store = CollectionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store) // アプリ全体に共有
        }
    }
}
