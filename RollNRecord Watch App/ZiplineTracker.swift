import Foundation
import CoreMotion
import CoreLocation
import SwiftUI
import WatchKit

enum RideType {
    case zipline
    case dropTower
}

class ZiplineTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
    
    @Published var altitude: Double = 0.0
    @Published var descentRate: Double = 0.0
    @Published var speed: Double = 0.0  
    @Published var isRecording = false
    @Published var errorMessage: String?
    @Published var ascentIcon: String = "arrow.up"
    @Published var isActionInProgress = false
    @Published var countdownValue: Int = 3
    @Published var isCountingDown = false
    @Published var isSaving = false
    
    private var lastAltitudeReading: Double?
    private var lastTimestamp: Date?
    private var recordingData: [any RecordingPoint] = []  
    private var recordingTimer: Timer?
    private let dataUpdateInterval: TimeInterval = 1.5
    private let altimeterUpdateInterval: TimeInterval = 0.1 
    private let ziplineUpdateInterval: TimeInterval = 0.08  
    private let dropTowerUpdateInterval: TimeInterval = 0.05  
    
    private var lastAltimeterUpdate: Date?
    private var baseAltitude: Double?
    var onRecordingStopped: ((String) -> Void)?
    var currentRideType: RideType = .zipline
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .otherNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
    
    func setRideType(_ type: RideType) {
        currentRideType = type
    }
    
    func initiateTracking() {
        isCountingDown = true
        countdownValue = 3
        
        func performCountdown() {
            WKInterfaceDevice.current().play(.click)
            
            if countdownValue > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.countdownValue -= 1
                    performCountdown()
                }
            } else {
                self.isCountingDown = false
                WKInterfaceDevice.current().play(.start)
                self.startTracking()
            }
        }
        
        performCountdown()
    }
    
    func startTracking() {
        guard !isActionInProgress else { return }
        isActionInProgress = true
        print("🚀 Starting tracking session")
        isRecording = true
        lastAltitudeReading = nil
        lastTimestamp = nil
        baseAltitude = nil  
        
        if currentRideType == .dropTower {
            altitude = 0.0  
        }
        
        recordingData.removeAll()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: currentRideType == .zipline ? ziplineUpdateInterval : dropTowerUpdateInterval, repeats: true) { [weak self] _ in
            self?.recordDataPoint()
        }
        
        if (!CMAltimeter.isAbsoluteAltitudeAvailable()) {
            errorMessage = "Altimeter not available"
            isActionInProgress = false
            return
        }
        
        altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self,
                  let data = data else { return }
            
            let absoluteAltitude = data.altitude * 3.28084
            self.updateElevation(with: absoluteAltitude)
        }
        
        if currentRideType == .zipline {
            locationManager.startUpdatingLocation()
        }
        
        WKInterfaceDevice.current().play(.start)
        
        lastAltimeterUpdate = Date()
        
        isActionInProgress = false
    }
    
    func stopTracking() {
        guard !isActionInProgress else { return }
        isActionInProgress = true
        isSaving = true
        
        
        let filename = isRecording && !recordingData.isEmpty ? saveRecordingData() : ""
        cleanupResources()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSaving = false
            if !filename.isEmpty {
                self.onRecordingStopped?(filename)
            }
            self.isActionInProgress = false
        }
        
        WKInterfaceDevice.current().play(.stop)
    }
    
    private func cleanupResources() {
        isRecording = false
        altitude = 0.0
        descentRate = 0.0
        baseAltitude = nil
        
        
        altimeter.stopAbsoluteAltitudeUpdates()
        
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingData.removeAll()
        
        
        lastAltitudeReading = nil
        lastTimestamp = nil
        lastAltimeterUpdate = nil
        
        locationManager.stopUpdatingLocation()
        speed = 0.0
        
        
        isActionInProgress = false
        isCountingDown = false
        isSaving = false
    }
    
    deinit {
        cleanupResources()
        recordingData.removeAll()
    }
    
    private func updateElevation(with absoluteAltitude: Double) {
        let now = Date()
        DispatchQueue.main.async {
            
            if self.currentRideType == .dropTower {
                if self.baseAltitude == nil {
                    self.baseAltitude = absoluteAltitude
                }
                
                self.altitude = absoluteAltitude - (self.baseAltitude ?? absoluteAltitude)
            } else {
                
                self.altitude = absoluteAltitude
            }
            
            if let lastAltitude = self.lastAltitudeReading,
               let lastTime = self.lastTimestamp {
                let timeDelta = now.timeIntervalSince(lastTime)
                let minimumInterval = self.currentRideType == .zipline ? self.ziplineUpdateInterval : self.altimeterUpdateInterval
                if timeDelta >= minimumInterval {
                    let altitudeDelta = absoluteAltitude - lastAltitude
                    
                    let newRate = (altitudeDelta / timeDelta) * 60.0
                    self.descentRate = (self.descentRate + newRate) / 2.0
                    self.ascentIcon = altitudeDelta >= 0 ? "arrow.up" : "arrow.down"
                    
                    self.lastAltitudeReading = absoluteAltitude
                    self.lastTimestamp = now
                }
            } else {
                self.lastAltitudeReading = absoluteAltitude
                self.lastTimestamp = now
            }
        }
    }
    
    private func recordDataPoint() {
        if currentRideType == .zipline {
            let dataPoint = ZiplineDataPoint(
                id: UUID(),
                timestamp: Date(),
                altitude: altitude,
                descentRate: descentRate,
                speed: speed  
            )
            addRecordingDataPoint(dataPoint)
        } else {
            let dataPoint = DropDataPoint(
                id: UUID(),
                timestamp: Date(),
                altitude: altitude,
                descentRate: descentRate,
                speed: nil   
            )
            addRecordingDataPoint(dataPoint)
        }
    }
    
    func addRecordingDataPoint(_ dataPoint: any RecordingPoint) {  
        recordingData.append(dataPoint)
        print("📊 Added data point - Altitude: \(dataPoint.altitude)ft, Rate: \(String(format: "%.2f", dataPoint.descentRate))ft/min")
    }
    
    private func saveRecordingData() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        let prefix = currentRideType == .zipline ? "zipline" : "drop"
        let suffix = currentRideType == .zipline ? "zip" : "drop"
        let filename = "\(prefix)_\(formatter.string(from: Date()))_\(suffix).json"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return ""
        }
        
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            print("📝 Saving \(recordingData.count) data points")
            
            
            let jsonData: Data
            if currentRideType == .zipline {
                let ziplineData = recordingData.map { point in
                    ZiplineDataPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        altitude: point.altitude,
                        descentRate: point.descentRate,
                        speed: point.speed  
                    )
                }
                jsonData = try encoder.encode(ziplineData)
            } else {
                let dropData = recordingData.map { point in
                    DropDataPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        altitude: point.altitude,
                        descentRate: point.descentRate,
                        speed: nil  
                    )
                }
                jsonData = try encoder.encode(dropData)
            }
            
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📄 JSON Content:")
                print(jsonString)
            }
            
            try jsonData.write(to: fileURL)
            print("✅ Recording saved to: \(filename)")
        } catch {
            print("❌ Failed to save recording: \(error.localizedDescription)")
        }
        
        return filename
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard currentRideType == .zipline,
              let location = locations.last else { return }
        
        let currentSpeed = max(location.speed, 0.0) * 2.23694 
        DispatchQueue.main.async {
            self.speed = currentSpeed
        }
    }
}
