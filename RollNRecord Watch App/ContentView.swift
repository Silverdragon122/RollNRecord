import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    NavigationLink(destination: ZiplineTrackerView()) {
                        VStack {
                            Image(systemName: "figure.climbing")
                                .font(.system(size: 25))
                            Text("Zipline")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 70)
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    
                    NavigationLink(destination: FilePickerView()) {
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 25))
                            Text("Records")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 70)
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
                HStack(spacing: 20) {
                    NavigationLink(destination: DropTowerTrackerView()) {
                        VStack {
                            Image(systemName: "arrow.down.to.line.alt")
                                .font(.system(size: 25))
                            Text("Drop Tower")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 70)
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
            .padding()
            .navigationTitle("RollNRecord")
        }
    }
}

#Preview {
    ContentView()
}
