module DataProductsConfig {
    constant BASE_ID = 0x04000000

    module QueueSizes {
        constant dpCat = 8
        constant dpMgr = 8
        constant dpWriter = 8
        constant dpBufferManager = 8
    }

    module StackSizes {
        constant dpCat = 8 * 1024
        constant dpMgr = 8 * 1024
        constant dpWriter = 8 * 1024
        constant dpBufferManager = 8 * 1024
    }

    module Priorities {
        constant dpCat = 24
        constant dpMgr = 23
        constant dpWriter = 22
        constant dpBufferManager = 21
    }

    module BuffMgr {
        constant dpBufferStoreSize = 1024
        constant dpBufferStoreCount = 2
        constant dpBufferManagerId = 300
    }

    module Paths {
        constant dpDir = "./DpCat"
        constant dpState = "./DpCat/DpState.dat"
    }
}
