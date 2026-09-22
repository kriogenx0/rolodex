import SwiftUI

@main
struct RolodexApp: App {
    @StateObject private var viewModel = ContactsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 920, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
