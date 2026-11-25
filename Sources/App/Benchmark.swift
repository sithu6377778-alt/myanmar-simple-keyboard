import Darwin
import Foundation

/// `--benchmark`: measures the work done on every key press — Apple layout
/// lookup + the ေ composer — for speed and memory. Does not change how the
/// keyboard behaves; only runs when started with this flag (CI).
enum Benchmark {
    /// "နေကောင်းလား ကျေးဇူးတင်ပါတယ် " typed the iPhone way: (keyCode, shift)
    static let sentence: [(UInt16, Bool)] = [
        (0, false), (14, false),                                                    // ေ န
        (0, false), (32, false), (46, false), (34, false), (3, false), (41, false),  // ေ က ာ င ် း
        (9, false), (46, false), (41, false), (49, false),                          // လ ာ း ␣
        (0, false), (32, false), (1, false), (41, false),                           // ေ က ျ း
        (6, true), (37, false), (41, false),                                        // ဇ ူ း
        (13, false), (34, false), (3, false),                                       // တ င ်
        (16, false), (5, false),                                                    // ပ ါ
        (13, false), (11, true), (3, false), (49, false),                           // တ ယ ် ␣
    ]

    /// Physical memory footprint of this process (what Activity Monitor shows).
    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    static func f(_ value: Double, _ digits: Int = 2) -> String { String(format: "%.\(digits)f", value) }

    static func run() -> Int32 {
        var failures = 0

        // 1. Loading Apple's layout (happens once, on the first key press).
        let loadStart = now()
        let translator = KeyTranslator()
        let loadMicros = Double(now() - loadStart) / 1000
        print("layout load (once):        \(f(loadMicros)) µs   [\(translator.sourceID ?? "fallback table")]")

        // Make sure we time the real, correct thing.
        var check = EComposer()
        var typed = ""
        for (code, shift) in sentence {
            typed += check.input(translator.text(keyCode: code, shift: shift, option: false, capsLock: false) ?? "").commit
        }
        typed += check.commitAll()
        print("benchmark sentence:        \(typed)")

        // Warm-up.
        var composer = EComposer()
        var sink = 0
        for i in 0..<20_000 {
            let (code, shift) = sentence[i % sentence.count]
            let r = composer.input(translator.text(keyCode: code, shift: shift, option: false, capsLock: false) ?? "")
            sink &+= r.commit.utf8.count &+ r.marked.utf8.count
        }

        // 2. Per-key latency (200,000 key presses, each timed).
        let timedKeys = 200_000
        var samples = [UInt64](repeating: 0, count: timedKeys)
        for i in 0..<timedKeys {
            let (code, shift) = sentence[i % sentence.count]
            let start = now()
            let r = composer.input(translator.text(keyCode: code, shift: shift, option: false, capsLock: false) ?? "")
            sink &+= r.commit.utf8.count &+ r.marked.utf8.count
            samples[i] = now() - start
        }
        samples.sort()
        let average = Double(samples.reduce(0, +)) / Double(timedKeys) / 1000
        let p50 = Double(samples[timedKeys / 2]) / 1000
        let p99 = Double(samples[timedKeys * 99 / 100]) / 1000
        let worst = Double(samples[timedKeys - 1]) / 1000
        print("per key press:             average \(f(average)) µs · median \(f(p50)) µs · 99% under \(f(p99)) µs · slowest \(f(worst, 1)) µs")
        print("                           (1 ms = 1000 µs; people notice delays above ~10,000 µs)")

        // 3. Throughput + memory growth over 1,000,000 key presses.
        let keys = 1_000_000
        let memoryBefore = footprint()
        let start = now()
        for i in 0..<keys {
            let (code, shift) = sentence[i % sentence.count]
            let r = composer.input(translator.text(keyCode: code, shift: shift, option: false, capsLock: false) ?? "")
            sink &+= r.commit.utf8.count &+ r.marked.utf8.count
        }
        let seconds = Double(now() - start) / 1_000_000_000
        let memoryAfter = footprint()
        let growthKB = (Double(memoryAfter) - Double(memoryBefore)) / 1024
        print("1,000,000 key presses:     \(f(seconds, 3)) s total  (\(Int(Double(keys) / seconds)) keys/s)")
        print("memory before / after:     \(f(Double(memoryBefore) / 1_048_576, 1)) MB / \(f(Double(memoryAfter) / 1_048_576, 1)) MB  (growth \(f(growthKB, 0)) KB)")

        // 4. The ေ logic alone (without the layout lookup).
        let texts = sentence.map { translator.text(keyCode: $0.0, shift: $0.1, option: false, capsLock: false) ?? "" }
        let composerStart = now()
        for i in 0..<keys {
            let r = composer.input(texts[i % texts.count])
            sink &+= r.commit.utf8.count
        }
        let composerNs = Double(now() - composerStart) / Double(keys)
        print("ေ logic only:              \(f(composerNs / 1000, 3)) µs per key")
        print("(checksum \(sink))")

        // Generous limits: a real problem would be far above these.
        if average > 50 { failures += 1; print("FAIL: average key press slower than 50 µs") }
        if p99 > 1000 { failures += 1; print("FAIL: 99% of key presses should take under 1 ms") }
        if growthKB > 10 * 1024 { failures += 1; print("FAIL: memory grew more than 10 MB (possible leak)") }
        print(failures == 0 ? "BENCHMARK PASSED" : "BENCHMARK FAILED (\(failures))")
        return failures == 0 ? 0 : 1
    }
}
