import SwiftUI

struct GaugeView: View {
    let value: Double
    let range: ClosedRange<Double>
    let icon: String
    let label: String
    let color: Color
    let isRecording: Bool
    
    var body: some View {
        Gauge(value: value, in: range) {
            Image(systemName: icon)
                .opacity(isRecording ? 1 : 0.3)
                .imageScale(.small)
        } currentValueLabel: {
            Text(isRecording ? label : "--")
                .font(.footnote) 
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .center) 
                
        }
        .gaugeStyle(.accessoryCircular)
        .tint(color.gradient)
    }
}

struct ZiplineTrackerView: View {
    @StateObject private var tracker = ZiplineTracker()
    @State private var showRecordingsView = false
    @State private var latestRecordingFilename: String?
    
    var body: some View {
        VStack {
            if tracker.isCountingDown {
                countdownView
            } else if let error = tracker.errorMessage {
                errorView(error)
            } else {
                metricsGrid
            }
        }
        .padding()
        .onDisappear {
            if tracker.isRecording {
                tracker.stopTracking()
            }
        }
        .onAppear {
            tracker.setRideType(.zipline)
            tracker.onRecordingStopped = { filename in
                latestRecordingFilename = filename
                showRecordingsView = true
            }
        }
        .overlay { savingOverlay }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRecordingsView) {
            if let filename = latestRecordingFilename {
                ViewRecordings(filename: filename, isFromRecording: true)
            }
        }
    }
    
    private var countdownView: some View {
        Text("\(tracker.countdownValue)")
            .font(.system(size: 80, weight: .bold))
            .transition(.scale)
            .animation(.easeInOut, value: tracker.countdownValue)
    }
    
    private func errorView(_ error: String) -> some View {
        Text(error)
            .foregroundColor(.red)
    }
    
    private var metricsGrid: some View {
        Grid(alignment: .center, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                elevationGauge
                descentRateGauge
            }
            if tracker.currentRideType == .zipline {
                GridRow {
                    speedGauge
                        .gridCellColumns(2)
                }
            }
        }
        .padding(.horizontal, 8)
        .gesture(
            TapGesture(count: 2)
                .onEnded {
                    if tracker.isRecording {
                        tracker.stopTracking()
                    } else {
                        tracker.startTracking()
                    }
                }
        )
        .disabled(tracker.isCountingDown)
        .overlay(
            tracker.isActionInProgress ? Color.black.opacity(0.5) : Color.clear
        )
    }
    
    private var elevationGauge: some View {
        GaugeView(
            value: tracker.altitude,
            range: 0...10000,
            icon: "mountain.2",
            label: "\(Int(tracker.altitude))ft",
            color: .cyan,
            isRecording: tracker.isRecording
        )
    }
    
    private var descentRateGauge: some View {
        GaugeView(
            value: abs(tracker.descentRate),
            range: 0...500,
            icon: tracker.ascentIcon,
            label: "\(Int(abs(tracker.descentRate))) ft/min",
            color: .orange,
            isRecording: tracker.isRecording
        )
    }

    private var speedGauge: some View {
        GaugeView(
            value: tracker.speed,
            range: 0...60,
            icon: "speedometer",
            label: "\(Int(tracker.speed)) MPH",
            color: .green,
            isRecording: tracker.isRecording
        )
    }

    private var savingOverlay: some View {
        Group {
            if tracker.isSaving {
                ZStack {
                    Color.black.opacity(0.8)
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Saving Data")
                            .foregroundStyle(.white)
                            .font(.callout)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button(action: {
                if tracker.isRecording {
                    tracker.stopTracking()
                } else {
                    tracker.initiateTracking()
                }
            }) {
                Label(tracker.isRecording ? "Stop" : "Start",
                      systemImage: tracker.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title2)
            }
            .tint(tracker.isRecording ? .red : .green)
            .buttonStyle(.bordered)
            .handGestureShortcut(.primaryAction)
            .disabled(tracker.isCountingDown)
        }
    }
}