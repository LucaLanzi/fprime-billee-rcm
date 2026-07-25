module CdhCoreConfig {
    constant BASE_ID = 0x01000000

    module QueueSizes {
        constant cmdDisp = 8
        constant events = 16
        constant tlmSend = 32
        constant $health = 10
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
