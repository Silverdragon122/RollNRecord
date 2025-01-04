import Foundation

private func calculateStats<T: RecordingPoint>(for data: [T]) -> Recording.RecordingStats {
    guard !data.isEmpty else {
        return Recording.RecordingStats(
            maxAltitude: 0,
            avgDescentRate: 0,
            duration: 0,
            climbDuration: nil,
            maxSpeed: nil  
        )
    }
    
    let avgDescentRate = data.reduce(0) { $0 + $1.descentRate } / Double(data.count)
    let maxAltitude = data.map { $0.altitude }.max() ?? 0
    let duration = data.last!.timestamp.timeIntervalSince(data[0].timestamp)
    let maxSpeed = data.compactMap { $0.speed }.max()  
    
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
        climbDuration: climbDuration,
        maxSpeed: maxSpeed  
    )
}
