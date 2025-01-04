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
    }
    
    private var goingUpView: some View {
        VStack {
            Image(systemName: "chevron.up")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .foregroundColor(.blue)
                .padding()
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isDropping)
            
            Text("Going up!")
                .font(.largeTitle)
                .padding()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text("Altitude: \(Int(tracker.altitude - initialAltitude)) ft")
                .font(.title2)
                .padding()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text("System will detect when drop starts!")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
    
    private var droppingView: some View {
        VStack {
            Image(systemName: "chevron.down")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .foregroundColor(.red)
                .padding()
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isDropping)
            
            Text("Dropping!")
                .font(.largeTitle)
                .padding()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text("\(Int(dropSpeed)) ft/min")
                .font(.title2)
                .padding()
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 16) {
            Text("Recording")
                .font(.system(size: 18, weight: .bold))
            Text("Complete!")
                .font(.system(size: 18, weight: .bold))
            
            Button(action: {
                dismiss()  
            }) {
                Text("Return Home")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private func handleDescentRateChange(_ newRate: Double) {
        if newRate < -250 {
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

struct DropData: Codable {
    let startTime: Date
    let endTime: Date
    let maxSpeed: Double
    let duration: TimeInterval
}

#Preview {
    DropTowerTrackerView()
}
