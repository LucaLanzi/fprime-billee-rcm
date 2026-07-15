module rp2040Deployment {

  module Default {
    constant QUEUE_SIZE = 8
    constant STACK_SIZE = 3 * 1024
  }

  instance rateGroup1: Svc.ActiveRateGroup base id 0x10001000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 43

  instance chronoTime: Zephyr.ZephyrTime base id 0x10010000

  instance rateGroupDriver: Svc.RateGroupDriver base id 0x10011000

  instance timer: Zephyr.ZephyrRateDriver base id 0x10013000

  instance comDriver: Zephyr.ZephyrUartDriver base id 0x10014000
}
