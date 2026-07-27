#ifndef TLMCHANIMPLCFG_HPP_
#define TLMCHANIMPLCFG_HPP_

// Size the telemetry database for this embedded deployment. The generated
// dictionary currently contains 119 telemetry channels.
//
// TLMCHAN_HASH_BUCKETS is a pool of hash-table nodes (Svc::TlmChan::TlmEntry
// buckets[TLMCHAN_HASH_BUCKETS], doubled by TlmChan's internal double-
// buffering) allocated lazily, one per DISTINCT channel ID the first time it
// is ever written -- not one per channel that merely exists in the
// dictionary. FW_ASSERT fires the moment a write needs a node and the pool
// is already full, so this must stay >= the number of channels actually
// written at runtime, which in practice means >= the total channel count.
// It's a fixed-size static array, NOT heap, so it doesn't compete with the
// runtime margin covered in the README's heap section. But it is far from
// free: each TlmEntry's Fw::TlmBuffer is sized by the project-wide
// FW_COM_BUFFER_MAX_SIZE (default 512, shared with command/event/param/file
// buffers -- see lib/fprime/default/config/FpConstants.fpp), not by this
// project's actual telemetry types (our largest, Billee::ThermalReading, is
// ~42 bytes). That makes each bucket cost ~1 KiB of static RAM regardless of
// how small the real payloads are -- confirmed directly: bumping this from
// 96 to 128 cost 38 KiB, not the few hundred bytes a naive estimate would
// suggest. Kept tight (a handful of spare slots, not padded to a round
// number) for that reason; re-measure before padding further.
namespace {
enum {
    TLMCHAN_NUM_TLM_HASH_SLOTS = 15,
    TLMCHAN_HASH_MOD_VALUE = 99,
    TLMCHAN_HASH_BUCKETS = 125
};
}

#endif
