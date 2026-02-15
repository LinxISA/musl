/*
 * Process-wide lock for arch/linx64 atomic_arch.h fallbacks.
 *
 * This is intentionally coarse-grained for bring-up correctness.
 */
volatile int __linx_atomic_lockword = 0;
