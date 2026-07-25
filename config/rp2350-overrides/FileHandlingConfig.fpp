module FileHandlingConfig {
    constant BASE_ID = 0x05000000

    module QueueSizes {
        constant fileUplink = 8
        constant fileDownlink = 8
        constant fileManager = 8
        constant prmDb = 8
    }

    module StackSizes {
        constant fileUplink = 8 * 1024
        constant fileDownlink = 8 * 1024
        constant fileManager = 8 * 1024
        constant prmDb = 8 * 1024
    }

    module Priorities {
        constant fileUplink = 24
        constant fileDownlink = 23
        constant fileManager = 22
        constant prmDb = 21
    }

    module DownlinkConfig {
        constant cooldown = 1000
        constant cycleTime = 1000
        constant fileQueueDepth = 4
    }
}
