import SwiftUI

@main
struct GermanBuddyApp: App {
    @StateObject private var convo = Conversation()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(convo)
        }
    }
}
