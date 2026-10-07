import os

/// Instruments(Points of Interest / os_signpost)에서 구간을 확인하기 위한 signposter.
///
/// ```swift
/// let state = PerfSignpost.signposter.beginInterval("draw")
/// defer { PerfSignpost.signposter.endInterval("draw", state) }
/// ```
public enum PerfSignpost {
    public static let subsystem = "com.perflab"
    public static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}
