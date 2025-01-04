import Foundation

protocol RecordingPoint: Identifiable, Codable {
    var id: UUID { get }
    var timestamp: Date { get }
    var altitude: Double { get }
    var descentRate: Double { get }
    var speed: Double? { get }  
}

struct Recording {
    let id: UUID
    let filename: String
    let data: [any RecordingPoint]
    let stats: RecordingStats
    
    struct RecordingStats: Codable {
        let maxAltitude: Double
        let avgDescentRate: Double
        let duration: TimeInterval
        let climbDuration: TimeInterval? 
    }
}

struct ZiplineDataPoint: RecordingPoint {
    let id: UUID
    let timestamp: Date
    let altitude: Double
    let descentRate: Double
    let speed: Double?  
}

struct DropDataPoint: RecordingPoint {
    let id: UUID
    let timestamp: Date
    let altitude: Double
    let descentRate: Double
    
    let speed: Double?
}
