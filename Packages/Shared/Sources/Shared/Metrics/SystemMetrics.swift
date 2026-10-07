import Darwin

/// 현재 프로세스의 CPU 시간, 스레드 수, 메모리 사용량을 읽는다.
enum SystemMetrics {
    /// 프로세스가 지금까지 사용한 CPU 시간(user + system, 초). 종료된 스레드의 시간도 포함한다.
    ///
    /// 두 시점의 차이를 경과 시간으로 나누면 구간 CPU 사용률이 된다.
    /// 스레드별 `thread_info`의 `cpu_usage`는 스케줄러의 감쇠 추정치이고, 샘플 사이에 끝난 스레드가 빠져서 쓰지 않는다.
    static func cpuTime() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    static func threadCount() -> Int {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS, let threadList else {
            return 0
        }
        for index in 0..<Int(threadCount) {
            mach_port_deallocate(mach_task_self_, threadList[index])
        }
        let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), size)
        return Int(threadCount)
    }

    /// Xcode Memory Gauge, Jetsam 기준과 동일한 physical footprint (bytes).
    static func memoryFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
