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
                                .foregroundStyle(.linearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            Text("Zipline")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    NavigationLink(destination: FilePickerView()) {
                        VStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 25))
                                .foregroundStyle(.linearGradient(colors: [.mint, .mint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            Text("Records")
                                .font(.caption2)
                                .foregroundColor(.mint)
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                HStack(spacing: 20) {
                    NavigationLink(destination: DropTowerTrackerView()) {
                        VStack {
                            Image(systemName: "arrow.down.to.line.alt")
                                .font(.system(size: 25))
                                .foregroundStyle(.pink)
                            Text("Drop Tower")
                                .font(.caption2)
                                .foregroundColor(.pink)
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
            .navigationTitle("RollNRecord")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
