import com.snapchat.djinni.rt.Color
import com.snapchat.djinni.rt.RuntimeIface
import com.snapchat.djinni.rt.RuntimeRecord
import com.snapchat.djinni.rt.create // StaticsCompat companion extension: RuntimeIface.create(seed)
import kotlin.system.exitProcess

// HOST load/link/run round-trip driver for the Kotlin generator backend.
// Drives the NEW Kotlin surface end-to-end against a real native C++ impl loaded
// from libkruntime.dylib:
//   - StaticsCompat companion factory  RuntimeIface.create(seed)  -> CppRuntimeIface proxy
//   - property get / set               iface.seed
//   - enum round-trip                  nextColor
//   - optional<string> round-trip      idOptional (value + null)
//   - list<i32> round-trip             idList
//   - map<string,i64> round-trip       idMap
//   - record round-trip JVM->C++->JVM  idRecord   (echo)
//   - record built in C++ -> JVM       makeRecord (optional/list/map/enum fields)
fun main(args: Array<String>) {
    val dylib = args[0]
    var ok = false
    try {
        System.load(dylib)
        println("[1] System.load OK: $dylib")

        // Non-null static factory through the StaticsCompat companion extension.
        val iface: RuntimeIface = RuntimeIface.create(7)
        println("[2] RuntimeIface.create(7) -> ${iface.javaClass.name}")
        check(iface.javaClass.name == "com.snapchat.djinni.rt.CppRuntimeIface") {
            "expected CppRuntimeIface proxy, got ${iface.javaClass.name}"
        }

        // Property getter (native_getSeed).
        check(iface.seed == 7) { "seed getter expected 7, got ${iface.seed}" }
        // Property setter (native_setSeed) then read back.
        iface.seed = 42
        check(iface.seed == 42) { "seed setter expected 42, got ${iface.seed}" }
        println("[3] property get/set OK (seed=${iface.seed})")

        // Enum round-trip.
        check(iface.nextColor(Color.BLUE) == Color.INDIGO) { "nextColor(BLUE) != INDIGO" }
        check(iface.nextColor(Color.VIOLET) == Color.RED) { "nextColor(VIOLET) wrap != RED" }
        println("[4] enum round-trip OK")

        // optional<string> both directions.
        check(iface.idOptional("hi") == "hi") { "idOptional(value) mismatch" }
        check(iface.idOptional(null) == null) { "idOptional(null) mismatch" }
        println("[5] optional round-trip OK")

        // list<i32>.
        val list = listOf(1, 2, 3, -7)
        check(iface.idList(list) == list) { "idList mismatch: ${iface.idList(list)}" }
        // map<string,i64>.
        val map = mapOf("x" to 10L, "y" to 20L)
        check(iface.idMap(map) == map) { "idMap mismatch: ${iface.idMap(map)}" }
        println("[6] list + map round-trip OK")

        // Record round-trip JVM -> C++ -> JVM (echo). Exercises every field type:
        // i32, string, optional<f64>, list<string>, map<string,i64>, enum.
        val rec = RuntimeRecord(9, "n", 3.5, listOf("t1", "t2"), mapOf("k" to 1L), Color.GREEN)
        check(iface.idRecord(rec) == rec) { "idRecord echo mismatch: ${iface.idRecord(rec)}" }
        // Null optional field survives the round-trip too.
        val recNullOpt = rec.copy(gain = null)
        check(iface.idRecord(recNullOpt) == recNullOpt) { "idRecord null-opt mismatch" }
        println("[7] record round-trip OK")

        // Record built entirely in C++ (uses seed=42 set above).
        val made = iface.makeRecord("z")
        check(made.id == 42) { "makeRecord.id expected 42, got ${made.id}" }
        check(made.label == "cfg:z") { "makeRecord.label expected 'cfg:z', got '${made.label}'" }
        check(made.gain == 1.5) { "makeRecord.gain expected 1.5, got ${made.gain}" }
        check(made.tags == listOf("a", "b")) { "makeRecord.tags mismatch: ${made.tags}" }
        check(made.props == mapOf("k" to 7L)) { "makeRecord.props mismatch: ${made.props}" }
        check(made.favColor == Color.RED) { "makeRecord.favColor expected RED (42%7=0), got ${made.favColor}" }
        println("[8] C++-built record OK: $made")

        println("[9] ALL CHECKS PASSED")
        ok = true
    } finally {
        // NativeObjectManager runs a non-daemon cleanup thread; exit explicitly so the
        // host proof terminates deterministically.
        exitProcess(if (ok) 0 else 1)
    }
}
