module CdhCoreConfig {
    constant BASE_ID = 0x01000000

    module QueueSizes {
        constant cmdDisp = 8
        constant events = 16
        constant tlmSend = 32
        # Only 12 components ping health (NUM_PING_ENTRIES); 16 keeps headroom
        # while freeing ~9 KiB of heap this queue was taking at 32 -- that margin
        # is what lets dpBufferManager's setup() succeed instead of hitting a
        # 2240-byte allocation failure on a nearly-exhausted heap.
        constant $health = 16
    }

    module StackSizes {
        constant cmdDisp = 8 * 1024
        constant events = 8 * 1024
        constant tlmSend = 8 * 1024
    }

    module Priorities {
        constant cmdDisp = 35
        constant $health = 24
        constant events = 23
        constant tlmSend = 22
    }
}
