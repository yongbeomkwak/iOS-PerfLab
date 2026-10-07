import Darwin

/// Mach API로 현재 프로세스의 CPU, 스레드, 메모리 사용량을 읽는다.
enum SystemMetrics {
    struct CPUSnapshot {
        /// 모든 스레드 CPU 사용률의 합 (100% = 코어 1개 완전 사용).
        let usagePercent: Double
        let threadCount: Int
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

    static func cpu() -> CPUSnapshot {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS, let threadList else {
            return CPUSnapshot(usagePercent: 0, threadCount: 0)
        }
        defer {
            let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), size)
        }

        var usage = 0.0
        for index in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threadList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            if result == KERN_SUCCESS, info.flags & TH_FLAGS_IDLE == 0 {
                usage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
            mach_port_deallocate(mach_task_self_, threadList[index])
        }
        return CPUSnapshot(usagePercent: usage, threadCount: Int(threadCount))
    }
}
