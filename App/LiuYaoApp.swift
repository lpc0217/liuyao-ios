import SwiftUI

@main
struct LiuYaoApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(Theme.accent)
                #if DEBUG
                .task { await store.verifyLiveIfRequested() }
                .disabled(store.verificationRunning)
                .overlay { if store.verificationRunning { ProgressView("正在验证真实解卦…").padding(24).background(Theme.paper, in: RoundedRectangle(cornerRadius: 12)) } }
                #endif
                .preferredColorScheme(.light)
                .alert("历史记录", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
                    Button("知道了", role: .cancel) { store.storageError = nil }
                } message: { Text(store.storageError ?? "") }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { InputView() }
                .tabItem { Label("起卦", systemImage: "square.and.pencil") }
            NavigationStack { HistoryView() }
                .tabItem { Label("卦记", systemImage: "clock") }
            NavigationStack { LibraryView() }
                .tabItem { Label("卦典", systemImage: "book.closed") }
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
        }
    }
}
