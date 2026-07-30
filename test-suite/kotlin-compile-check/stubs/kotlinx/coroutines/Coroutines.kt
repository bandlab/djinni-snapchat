// Compile-only stub of the tiny kotlinx.coroutines surface the generated Kotlin uses
// (the init-safe readiness gate + blocking compat hatches). This keeps kotlin-compile-check
// self-contained — no external coroutines artifact — while still exercising the generated
// signatures. Bodies are never executed by this check (compile only), so they just satisfy types.
@file:Suppress("UNUSED_PARAMETER")

package kotlinx.coroutines

class CompletableDeferred<T> {
    val isCompleted: Boolean get() = false
    val isCancelled: Boolean get() = false
    suspend fun await(): T = throw NotImplementedError()
    fun complete(value: T): Boolean = false
    fun completeExceptionally(cause: Throwable): Boolean = false
}

fun <T> runBlocking(block: suspend () -> T): T = throw NotImplementedError()
