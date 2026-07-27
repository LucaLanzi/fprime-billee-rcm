module CdhCoreConfig {
    constant BASE_ID = 0x01000000

    module QueueSizes {
        constant cmdDisp = 8
        constant events = 16
        # Reduced from 32: tlmSend's queue slot size is bounded by the largest
        # telemetry type in the topology, and Billee::ThermalReading (used by
        # McpManager) is bigger than anything that existed here before. At 32
        # slots that pushed heap usage past what ComCcsds.commsBufferManager
        # (mgrId 200, needs 8960 contiguous bytes) had left, causing a nullptr
        # allocation failure in BufferManagerComponentImpl.cpp:163. 16 matches
        # the depth already used for events/health elsewhere in this topology.
        constant tlmSend = 16
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
