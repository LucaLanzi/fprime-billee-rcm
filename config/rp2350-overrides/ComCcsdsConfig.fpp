module ComCcsdsConfig {
    constant BASE_ID = 0x02000000

    module QueueSizes {
        # Reduced from 24: this component's own async-port message queue was
        # costing ~565 bytes/slot (~13.6 KiB total), the single largest per-component
        # heap consumer at boot, and was the last ~1.2 KiB standing between a working
        # boot and cmdSeq's 5 KiB command-sequence buffer allocation failing. 16
        # matches the depth already used for events/health elsewhere in this topology.
        constant comQueue = 16
        constant aggregator = 8
    }

    module StackSizes {
        constant comQueue = 8 * 1024
        constant aggregator = 8 * 1024
    }

    module Priorities {
        constant aggregator = 30
        constant comQueue = 29
    }

    module QueueDepths {
        # This is ComCcsds.comQueue's INTERNAL priority-queue depth (allocated inside
        # comQueue.configure(), separate from QueueSizes.comQueue above, which is that
        # same active component's own async-port message queue). Measured directly with
        # a heap probe: at the original values (events=16, tlm=32, file=4) this single
        # call consumed 26 KiB of heap -- by far the largest individual allocation in
        # the whole boot sequence, and the reason cmdSeq's later 5 KiB sequence-buffer
        # allocation had nothing left to work with. Halving once (events=8, tlm=16) only
        # left cmdSeq's allocation succeeding by ~300 bytes -- too marginal to survive
        # steady-state runtime allocations. Halved again for real headroom.
        constant events = 4
        constant tlm = 8
        constant file = 4
    }

    module QueuePriorities {
        constant events = 0
        constant tlm = 2
        constant file = 1
    }

    module BuffMgr {
        constant frameAccumulatorSize = 1024
        constant commsBuffSize = 1024
        constant commsFileBuffSize = 1024
        constant commsBuffCount = 6
        constant commsFileBuffCount = 2
        constant commsBuffMgrId = 200
    }
}
