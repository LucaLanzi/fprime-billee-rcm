module ComCcsdsConfig {
    constant BASE_ID = 0x02000000

    module QueueSizes {
        constant comQueue = 24
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
        constant events = 16
        constant tlm = 32
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
