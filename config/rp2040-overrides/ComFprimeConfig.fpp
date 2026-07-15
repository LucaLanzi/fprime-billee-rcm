module ComFprimeConfig {
    constant BASE_ID = 0x03000000

    module QueueSizes {
        constant comQueue = 24
    }

    module StackSizes {
        constant comQueue = 3 * 1024
    }

    module Priorities {
        constant comQueue = 29
    }

    module QueueDepths {
        constant events = 16
        constant tlm = 32
        constant file = 2
    }

    module QueuePriorities {
        constant events = 0
        constant tlm = 2
        constant file = 1
    }

    module BuffMgr {
        constant frameAccumulatorSize = 512
        constant commsBuffSize = 512
        constant commsFileBuffSize = 512
        constant commsBuffCount = 6
        constant commsFileBuffCount = 1
        constant commsBuffMgrId = 200
    }
}
