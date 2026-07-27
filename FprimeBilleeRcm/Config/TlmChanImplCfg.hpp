#ifndef TLMCHANIMPLCFG_HPP_
#define TLMCHANIMPLCFG_HPP_

// Size the telemetry database for this embedded deployment. The generated
// dictionary currently contains 112 telemetry channels (89 baseline + 9 from
// McpManager/ThermalStateMachine + 9 from InaManager's 9 INA780B sensors).
//
// TLMCHAN_HASH_BUCKETS must be >= the channel count -- it's a fixed-size
// static array (Svc::TlmChan::TlmEntry buckets[TLMCHAN_HASH_BUCKETS], doubled
// by TlmChan's internal double-buffering), NOT heap, so it doesn't compete
// with the runtime margin covered in README 14.4. But it is far from free:
// each TlmEntry's Fw::TlmBuffer is sized by the project-wide
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
    TLMCHAN_HASH_BUCKETS = 116
};
}

#endif
