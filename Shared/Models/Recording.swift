import Foundation
import CoreLocation
import MapKit


protocol RecordingPoint: Identifiable, Codable {
    var id: UUID { get }
    var timestamp: Date { get }
    var speed: Double { get }
    var altitude: Double { get }
    var gForce: Double { get }
    var descentRate: Double { get }
    var coordinate: LocationCoordinate { get }
}

struct Recording: Identifiable, Codable {
    let id: UUID
    let filename: String
    let data: [RecordingPoint]
    let stats: RecordingStats
    
    init(id: UUID = UUID(), filename: String, data: [RecordingPoint], stats: RecordingStats) {
        self.id = id
        self.filename = filename
        self.data = data
        self.stats = stats
    }
    
    struct RecordingStats: Codable {
        let avgSpeed: Double
        let maxSpeed: Double
        let maxGForce: Double
        let avgDescentRate: Double
        let maxAltitude: Double
        let duration: TimeInterval
    }
}

struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ZiplineDataPoint: RecordingPoint {
    let id: UUID
    let timestamp: Date
    let speed: Double
    let altitude: Double
    let gForce: Double
    let descentRate: Double
    let coordinate: LocationCoordinate
}

struct DropDataPoint: RecordingPoint {
    let id: UUID
    let timestamp: Date
    let speed: Double
    let altitude: Double
    let gForce: Double
    let descentRate: Double
    let coordinate: LocationCoordinate
}
