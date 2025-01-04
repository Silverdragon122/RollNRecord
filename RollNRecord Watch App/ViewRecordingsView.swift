import SwiftUI
import MapKit
import WatchKit



@MainActor
class RecordingsViewModel: ObservableObject {
    @Published var recording: Recording?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    func loadRecording(filename: String) {
        isLoading = true
        recording = nil
        errorMessage = nil
        
        Task {
            do {
                guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    await MainActor.run {
                        self.errorMessage = "Could not access documents directory"
                        self.isLoading = false
                    }
                    return
                }
                
                let fileURL = documentsPath.appendingPathComponent(filename)
                let data = try Data(contentsOf: fileURL)
                
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Loading JSON Content:")
                    print(jsonString)
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                
                if filename.contains("_drop.json") {
                    let dropData = try decoder.decode([DropDataPoint].self, from: data)
                    print("📊 Loaded \(dropData.count) drop tower data points")
                    await MainActor.run {
                        let stats = self.calculateStats(for: dropData)
                        self.recording = Recording(id: UUID(), filename: filename, data: dropData, stats: stats)
                        self.isLoading = false
                    }
                } else {
                    let ziplineData = try decoder.decode([ZiplineDataPoint].self, from: data)
                    await MainActor.run {
                        let stats = self.calculateStats(for: ziplineData)
                        self.recording = Recording(id: UUID(), filename: filename, data: ziplineData, stats: stats)
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Error loading recording: \(error)")
                await MainActor.run {
                    self.errorMessage = "Error loading recording: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateStats<T: RecordingPoint>(for data: [T]) -> Recording.RecordingStats {
        guard !data.isEmpty else {
            return Recording.RecordingStats(maxAltitude: 0, avgDescentRate: 0, duration: 0, climbDuration: nil)
        }
        
        let avgDescentRate = data.reduce(0) { $0 + $1.descentRate } / Double(data.count)
        let maxAltitude = data.map { $0.altitude }.max() ?? 0
        let duration = data.last!.timestamp.timeIntervalSince(data[0].timestamp)
        
        
        let climbDuration: TimeInterval?
        if let dropStartIndex = data.firstIndex(where: { $0.descentRate < -10 }) {
            climbDuration = data[dropStartIndex].timestamp.timeIntervalSince(data[0].timestamp)
        } else {
            climbDuration = nil
        }
        
        return Recording.RecordingStats(
            maxAltitude: maxAltitude,
            avgDescentRate: avgDescentRate,
            duration: duration,
            climbDuration: climbDuration
        )
    }
    
    func calculateIntensity(stats: Recording.RecordingStats) -> Int {
        let maxAltitudeFactor = min(stats.maxAltitude / 17, 10) * 0.6
        let avgDescentRateFactor = min(abs(stats.avgDescentRate) / 493, 10) * 0.5
        let climbTimeFactor = min((stats.climbDuration ?? 0) / 200, 10) * 0.1
        
        let intensity = maxAltitudeFactor + avgDescentRateFactor + climbTimeFactor
        return min(Int(intensity.rounded()), 10)
    }
    
    nonisolated func cleanup() {
        Task { @MainActor [weak self] in
            self?.recording = nil
            self?.errorMessage = nil
            self?.isLoading = false
        }
    }
    
    deinit {
        cleanup()
        print("RecordingsViewModel deinitialized")
    }
}

struct IdentifiableRecordingPoint: Identifiable {
    let id: UUID
    let point: any RecordingPoint
}

struct ViewRecordings: View {
    @StateObject private var viewModel = RecordingsViewModel()
    @State private var showDiscardAlert = false
    @State private var region = MKCoordinateRegion()
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    let filename: String
    let isFromRecording: Bool
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if let recording = viewModel.recording {
                ScrollViewReader { proxy in
                    ScrollView {
                        contentView(for: recording)
                    }
                    .onAppear {
                        
                        proxy.scrollTo("stats", anchor: .top)
                    }
                }
            } else {
                ProgressView("Waiting...")
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isFromRecording {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive, action: {
                        showDiscardAlert = true
                    }) {
                        Text("Discard")
                    }
                }
            }
        }
        .alert("Discard Recording?", isPresented: $showDiscardAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                if let filename = viewModel.recording?.filename {
                    deleteRecording(filename)
                    viewModel.cleanup()
                }
                dismiss()
            }
        }
        .task {
            viewModel.loadRecording(filename: filename)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private func deleteRecording(_ filename: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = documentsPath.appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("Successfully deleted recording: \(filename)")
        } catch {
            print("Error deleting recording: \(error.localizedDescription)")
        }
    }
    
    private func statsGrid(stats: Recording.RecordingStats) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                StatView(title: "Max Alt", value: String(format: "%.0f", stats.maxAltitude), unit: "ft")
                StatView(title: "Avg Descent", value: String(format: "%.0f", abs(stats.avgDescentRate)), unit: "ft/min")
            }
            
            if filename.contains("_drop.json"), let climbTime = stats.climbDuration {
                GridRow {
                    StatView(title: "Climb Time", value: String(format: "%.1f", climbTime), unit: "sec")
                    StatView(title: "Drop Time", value: String(format: "%.1f", stats.duration - climbTime), unit: "sec")
                }
            }
            GridRow {
                StatView(title: "Intensity", value: "\(viewModel.calculateIntensity(stats: stats))", unit: "/10")
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func contentView(for recording: Recording) -> some View {
        VStack(spacing: 10) {
            statsGrid(stats: recording.stats)
                .id("stats")
            
            dropTowerGraph(for: recording)
                .frame(height: 110)
        }
        .padding(.horizontal, 2)
    }
    
    private func dropTowerGraph(for recording: Recording) -> some View {
        let baseAltitude = recording.data.first?.altitude ?? 0
        let relativeAltitudes = recording.data.map { $0.altitude - baseAltitude }
        let maxHeight = relativeAltitudes.max() ?? 0
        let minHeight = relativeAltitudes.min() ?? 0
        let maxSpeed = recording.data.map { abs($0.descentRate) }.max() ?? 0
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        let graphWidth = screenWidth - 60 
        
        
        let climbingPhaseIndex = recording.data.firstIndex { $0.descentRate < -10 } ?? recording.data.count
        
        let isDropTower = filename.contains("_drop.json")
        
        return VStack(spacing: 4) {
            ZStack {
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                
                HStack(spacing: 0) {
                    
                    VStack {
                        Text("\(Int(maxHeight))ft")
                            .font(.system(size: 8))
                        Spacer()
                        Text("\(Int(minHeight))ft")
                            .font(.system(size: 8))
                    }
                    .frame(width: 35)
                    .padding(.leading, 2)
                    
                    
                    GeometryReader { geometry in
                        
                        Path { path in
                            let heightScale = geometry.size.height / (maxHeight - minHeight)
                            let widthScale = geometry.size.width / Double(relativeAltitudes.count - 1)
                            
                            
                            for (index, height) in relativeAltitudes.enumerated() {
                                let x = Double(index) * widthScale
                                let y = (maxHeight - height) * heightScale
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        
                        if isDropTower {
                            
                            Path { path in
                                let heightScale = geometry.size.height / (maxHeight - minHeight)
                                let widthScale = geometry.size.width / Double(relativeAltitudes.count - 1)
                                
                                for index in 0...min(climbingPhaseIndex, relativeAltitudes.count - 1) {
                                    let x = Double(index) * widthScale
                                    let y = (maxHeight - relativeAltitudes[index]) * heightScale
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(Color.blue, lineWidth: 2)
                        }
                        
                        
                        Path { path in
                            let heightScale = geometry.size.height / (maxHeight - minHeight)
                            let widthScale = geometry.size.width / Double(relativeAltitudes.count - 1)
                            
                            let startIndex = isDropTower ? climbingPhaseIndex : 0
                            
                            if startIndex < relativeAltitudes.count {
                                path.move(to: CGPoint(
                                    x: Double(startIndex) * widthScale,
                                    y: (maxHeight - relativeAltitudes[startIndex]) * heightScale
                                ))
                                
                                for index in startIndex..<relativeAltitudes.count {
                                    let x = Double(index) * widthScale
                                    let y = (maxHeight - relativeAltitudes[index]) * heightScale
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: recording.data.suffix(from: isDropTower ? climbingPhaseIndex : 0).map { point in
                                    let speed = point.speed ?? abs(point.descentRate)
                                    let normalizedSpeed = isDropTower 
                                        ? min(abs(point.descentRate) / 3800.0, 1.0)  
                                        : min((speed - 1.0) / 39.0, 1.0)  
                                    return Color(
                                        red: normalizedSpeed,
                                        green: 1.0 - normalizedSpeed,
                                        blue: 0
                                    )
                                },
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 80)
            
            
            HStack(spacing: 0) {
                let duration = recording.stats.duration
                ForEach(0...3, id: \.self) { i in
                    Text(String(format: "%.1fs", duration * Double(i) / 3.0))
                        .font(.system(size: 8))
                        .frame(width: graphWidth / 3)
                }
            }
            .padding(.leading, 35)
            
            
            VStack(spacing: 4) {
                Text("Max descent: \(Int(maxSpeed)) ft/min")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                
                
                if filename.contains("_drop.json") {
                    HStack(spacing: 8) {
                        
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 4)
                            Text("Climbing")
                                .font(.system(size: 7))
                        }
                        
                        
                        HStack(spacing: 2) {
                            LinearGradient(
                                colors: [.green, .yellow, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 24, height: 4)
                            Text("0-3800 ft/min")
                                .font(.system(size: 7))
                        }
                    }
                } else {
                    
                    HStack(spacing: 2) {
                        LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 24, height: 4)
                        Text("1-40 MPH")
                            .font(.system(size: 7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
    
struct StatView: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack(spacing: 1) {
                Text(value)
                Text(unit)
            }
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ViewRecordings(filename: "example.json", isFromRecording: false)
}
