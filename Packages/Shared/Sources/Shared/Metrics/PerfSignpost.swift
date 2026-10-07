import os

/// Instruments(Points of Interest / os_signpost)에서 구간을 확인하기 위한 signposter.
///
/// OSSignposter: 코드 구간의 시작과 끝을 시스템 로그에 남기는 API. 꺼져 있을 때 비용이 거의 없어 Release에도 둔다.
/// Instruments 타임라인에 구간이 막대로 보여서, "이 hitch 동안 무슨 코드가 돌았나"를 확인할 수 있다.
/// category `.pointsOfInterest`로 남기면 Instruments의 Points of Interest 트랙에 바로 나타난다.
///
/// ```swift
/// let state = PerfSignpost.signposter.beginInterval("draw")
/// defer { PerfSignpost.signposter.endInterval("draw", state) }
/// ```
public enum PerfSignpost {
    public static let subsystem = "com.perflab"
    public static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}
