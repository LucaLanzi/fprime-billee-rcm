#ifndef TLMCHANIMPLCFG_HPP_
#define TLMCHANIMPLCFG_HPP_

// Size the telemetry database for this embedded deployment. The generated
// dictionary currently contains 89 telemetry channels.
namespace {
enum {
    TLMCHAN_NUM_TLM_HASH_SLOTS = 15,
    TLMCHAN_HASH_MOD_VALUE = 99,
    TLMCHAN_HASH_BUCKETS = 96
};
}

#endif
