module rp2350Deployment {

  # ----------------------------------------------------------------------
  # Base ID Convention
  # ----------------------------------------------------------------------
  #
  # All Base IDs follow the 8-digit hex format: 0xDSSCCxxx
  #
  # Where:
  #   D   = Deployment digit (1 for this deployment)
  #   SS  = Subtopology digits (00 for main topology, 01-05 for subtopologies)
  #   CC  = Component digits (00, 01, 02, etc.)
  #   xxx = Reserved for internal component items (events, commands, telemetry)
  #

  # ----------------------------------------------------------------------
  # Defaults
  # ----------------------------------------------------------------------

  module Default {
    constant QUEUE_SIZE = 8
    constant STACK_SIZE = 8 * 1024
  }

  # ----------------------------------------------------------------------
  # Active component instances
  # ----------------------------------------------------------------------

  instance rateGroup1: Svc.ActiveRateGroup base id 0x10001000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 43

  instance rateGroup2: Svc.ActiveRateGroup base id 0x10002000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 42

  instance rateGroup3: Svc.ActiveRateGroup base id 0x10003000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 41

  instance cmdSeq: Svc.CmdSequencer base id 0x10004000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 40

  # ----------------------------------------------------------------------
  # BILLEE Component instances
  # ----------------------------------------------------------------------
 
  instance subsystemManager: Billee.SubsystemManager base id 0x10015000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 44

  instance mcpManager: Billee.McpManager base id 0x10020000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 39

  instance inaManager: Billee.InaManager base id 0x10022000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 38

  # ----------------------------------------------------------------------
  # Queued component instances
  # ----------------------------------------------------------------------


  # ----------------------------------------------------------------------
  # Passive component instances
  # ----------------------------------------------------------------------

  instance chronoTime: Zephyr.ZephyrTime base id 0x10010000

  instance rateGroupDriver: Svc.RateGroupDriver base id 0x10011000

  instance systemResources: Svc.SystemResources base id 0x10012000

  instance timer: Zephyr.ZephyrRateDriver base id 0x10013000

  instance comDriver: Zephyr.ZephyrUartDriver base id 0x10014000

  # ----------------------------------------------------------------------
  # Subsystem power-enable GPIO driver instances
  # ----------------------------------------------------------------------

  instance drive1EnableGpio: Zephyr.ZephyrGpioDriver base id 0x10016000

  instance drive2EnableGpio: Zephyr.ZephyrGpioDriver base id 0x10017000

  instance drive3EnableGpio: Zephyr.ZephyrGpioDriver base id 0x10018000

  instance drive4EnableGpio: Zephyr.ZephyrGpioDriver base id 0x10019000

  instance drive5EnableGpio: Zephyr.ZephyrGpioDriver base id 0x1001A000

  instance drive6EnableGpio: Zephyr.ZephyrGpioDriver base id 0x1001B000

  instance armEnableGpio: Zephyr.ZephyrGpioDriver base id 0x1001C000

  instance scienceEnableGpio: Zephyr.ZephyrGpioDriver base id 0x1001D000

  instance auxEnableGpio: Zephyr.ZephyrGpioDriver base id 0x1001E000

  instance eStopStatusGpio: Zephyr.ZephyrGpioDriver base id 0x1001F000

  # ----------------------------------------------------------------------
  # MCP9808 temperature sensor I2C driver instance
  # ----------------------------------------------------------------------

  instance mcpI2cBusDriver: Zephyr.ZephyrI2cDriver base id 0x10021000

  # ----------------------------------------------------------------------
  # INA780B power monitor I2C driver instance
  # ----------------------------------------------------------------------

  instance inaI2cBusDriver: Zephyr.ZephyrI2cDriver base id 0x10023000

  # ----------------------------------------------------------------------
  # Fault Protection Manager instance (passive: reacts to readings pushed
  # in by mcpManager/inaManager rather than its own rate-group tick)
  # ----------------------------------------------------------------------

  instance fpManager: Billee.FPManager base id 0x10024000

}
