import SwiftUI

@main
struct RollNRecord_Watch_AppApp: App {
    @StateObject private var fileSync = FileSync.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
