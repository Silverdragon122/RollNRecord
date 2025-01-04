import SwiftUI

struct DropTowerTrackerView: View {
    @StateObject private var tracker = ZiplineTracker()
    @State private var isDropping = false
    @State private var dropStartTime: Date?
    @State private var dropEndTime: Date?
    @State private var dropSpeed: Double = 0.0
    @State private var initialAltitude: Double = 0.0
    @State private var recordingTimer: Timer?
    @State private var showRecordingsView = false
    @State private var latestRecordingFilename: String?
    @State private var isComplete = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if isComplete {
                completionView
            } else if isDropping {
                droppingView
            } else {
                goingUpView
            }
        }
        .padding()
        .onAppear {
            tracker.setRideType(.dropTower)
            tracker.startTracking()
            startRecordingTimer(interval: 0.05) 
            
            tracker.onRecordingStopped = { filename in
                latestRecordingFilename = filename
                showRecordingsView = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                initialAltitude = tracker.altitude
            }
        }
        .onDisappear {
            tracker.stopTracking()
            recordingTimer?.invalidate()
        }
        .onChange(of: tracker.descentRate) { oldValue, newValue in
            handleDescentRateChange(newValue)
        }
        .sheet(isPresented: $showRecordingsView) {
            if let filename = latestRecordingFilename {
                ViewRecordings(filename: filename, isFromRecording: true)
            }
        }
        .alert("Empty Recording", isPresented: $tracker.showEmptyRecordingAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("No movement was detected. The recording was discarded.")
        }
    }
    
    private var goingUpView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.bounce.up.byLayer, options: .repeating.speed(0.7))
                .symbolEffect(.bounce, options: .repeat(2).speed(0.7))
                .offset(y: 15) 
                .shadow(radius: 2)
            
            Text("Ascending")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 4) {
                Text("\(Int(abs(tracker.descentRate))) ft/min")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                
                Text("Ascent Speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(Int(tracker.altitude - initialAltitude)) ft")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.blue)
                .monospacedDigit()
            
            Spacer()
            
            Text("Drop detection active")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.thinMaterial)
                .clipShape(Capsule())
        }
    }
    
    private var droppingView: some View {
        VStack(spacing: 12) {  
            Image(systemName: "arrow.down.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)  
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .red.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.bounce.down.byLayer, options: .repeating)
                .shadow(radius: 2)
            
            Text("Dropping!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .red.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 2) {  
                SpeedGauge(
                    speed: dropSpeed,
                    maxSpeed: 4000
                )
                .frame(height: 40)
                
                Text("\(Int(dropSpeed))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.red)
                    .monospacedDigit()
                
                Text("ft/min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)  
        }
        .frame(maxHeight: .infinity)  
        .padding(.vertical, 10)  
    }
    
    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.bounce)
            
            Text("Ride Complete!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Button(action: { dismiss() }) {
                Label("Return Home", systemImage: "house.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
    
    private func handleDescentRateChange(_ newRate: Double) {
        if newRate < -20 {
            if (!isDropping) {
                isDropping = true
                dropStartTime = Date()
                dropSpeed = abs(newRate)
                playDropVibrations()
                startRecordingTimer(interval: 0.05) 
            } else {
                dropSpeed = max(dropSpeed, abs(newRate))
            }
        } else if isDropping {
            if let dropStartTime = dropStartTime, Date().timeIntervalSince(dropStartTime) > 3 {
                isDropping = false
                dropEndTime = Date()
                recordingTimer?.invalidate()
                recordingTimer = nil
                isComplete = true
                tracker.stopTracking()
            }
        }
    }
    
    private func playDropVibrations() {
        for _ in 0..<3 {
            WKInterfaceDevice.current().play(.notification)
            usleep(300000) 
        }
    }
    
    private func startRecordingTimer(interval: TimeInterval) {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.recordDataPoint()
            self.handleDescentRateChange(self.tracker.descentRate)
        }
    }
    
    private func recordDataPoint() {
        let currentAltitude = tracker.altitude - initialAltitude
        
        let dataPoint = DropDataPoint(
            id: UUID(),
            timestamp: Date(),
            altitude: currentAltitude,
            descentRate: tracker.descentRate,
            speed: nil  
        )
        
        print("📝 Recording data point - Alt: \(Int(currentAltitude))ft, Rate: \(Int(abs(tracker.descentRate)))ft/min")
        tracker.addRecordingDataPoint(dataPoint)
    }
}

struct AltitudeGauge: View {
    let value: Double
    let maxValue: Double
    
    var body: some View {
        Gauge(value: value, in: 0...maxValue) {
            Image(systemName: "arrow.up")
                .foregroundStyle(.blue)
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinear)
    }
}

struct SpeedGauge: View {
    let speed: Double
    let maxSpeed: Double
    
    var body: some View {
        Gauge(value: speed, in: 0...maxSpeed) {
            Image(systemName: "speedometer")
                .foregroundStyle(.red)
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinear)
        .tint(Gradient(colors: [.green, .yellow, .red]))
    }
}

struct DropData: Codable {
    let startTime: Date
    let endTime: Date
    let maxSpeed: Double
    let duration: TimeInterval
}

#Preview {
    DropTowerTrackerView()
}
