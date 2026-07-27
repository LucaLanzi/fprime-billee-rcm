# ======================================================================
# FPP file for configuration of various F Prime framework constants
# ======================================================================

# ---------------------------------------------------------------------
# Buffer sizes
# ---------------------------------------------------------------------

@ When dumping the contents of the registry, this specifies the size of the buffer used to store object names.
@ Should be >= FW_OBJ_NAME_BUFFER_SIZE.
constant FW_OBJ_SIMPLE_REG_BUFF_SIZE = 255

@ Specifies the size of the string holding the queue name for queues
constant FW_QUEUE_NAME_BUFFER_SIZE = 80

@ Specifies the size of the string holding the task name for active components and tasks
constant FW_TASK_NAME_BUFFER_SIZE = 80

@ Specifies the size of the buffer that contains a communications packet
#
# Reduced from the framework default of 512: this sizes EVERY telemetry/
# command/event/param buffer in the system uniformly, and Svc::TlmChan
# allocates one per telemetry hash bucket (doubled by its internal
# double-buffering) -- not heap, but static RAM, and it was costing ~1.1 KiB
# *per telemetry channel* for payloads that are actually 40-90 bytes at most
# in this project (Svc::Version's longest string is 80 chars; our own types
# top out around 46 bytes). At 112 channels that's ~120 KiB, over a fifth of
# total SRAM, spent on a buffer 5-10x larger than anything ever placed in
# it -- directly measured as the reason initComponents() ran out of heap
# once Billee::InaManager pushed the channel count up further (see
# README 14.4). 160 comfortably covers every declared string size in the
# dictionary with margin. FW_FILE_CHUNK_SIZE (Config/PlatformCfg.fpp) is
# reduced in step, since FW_FILE_BUFFER_MAX_SIZE below equals this constant
# exactly (no subtraction) -- file downlink chunks must still fit whole.
constant FW_COM_BUFFER_MAX_SIZE = 160

@ Specifies the size of the buffer attached to state machine signals
constant FW_SM_SIGNAL_BUFFER_MAX_SIZE = 128

@ Specifies the size of the buffer that contains the serialized command arguments
constant FW_CMD_ARG_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - sizeof(FwOpcodeType) - sizeof(FwPacketDescriptorType)

@ Specifies the maximum size of a string in a command argument
constant FW_CMD_STRING_MAX_SIZE = 40

@ Specifies the size of the buffer that contains the serialized log arguments
constant FW_LOG_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - sizeof(FwEventIdType) - sizeof(FwPacketDescriptorType)

@ Specifies the maximum size of a string in a log event
@ Note: This constant truncates file names in assertion failure event reports
#
# Reduced from the framework default of 200: must be < FW_LOG_BUFFER_MAX_SIZE
# (152 with FW_COM_BUFFER_MAX_SIZE=160 above). This only affects how much of
# a source file path survives in an FW_ASSERT failure report, not normal
# event/telemetry data -- 100 comfortably covers this project's actual path
# lengths (e.g. ".../lib/fprime/Svc/BufferManager/BufferManagerComponentImpl.cpp"
# is 74 chars).
constant FW_LOG_STRING_MAX_SIZE = 100

@ Specifies the size of the buffer that contains the serialized telemetry value
constant FW_TLM_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - sizeof(FwChanIdType) - sizeof(FwPacketDescriptorType)

@ Specifies the size of the buffer that contains the serialized telemetry value
constant FW_STATEMENT_ARG_BUFFER_MAX_SIZE = FW_CMD_ARG_BUFFER_MAX_SIZE

@ Specifies the maximum size of a string in a telemetry channel
constant FW_TLM_STRING_MAX_SIZE = 40

@ Specifies the size of the buffer that contains the serialized parameter value
constant FW_PARAM_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - sizeof(FwPrmIdType) - sizeof(FwPacketDescriptorType)

@ Specifies the maximum size of a string in a parameter
constant FW_PARAM_STRING_MAX_SIZE = 40

@ Specifies the maximum size of a file downlink chunk
constant FW_FILE_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE

@ Specifies the maximum size of a string in an interface call
constant FW_INTERNAL_INTERFACE_STRING_MAX_SIZE = 256

@ Defines the size of the text log string buffer. Should be large enough for format string and arguments
constant FW_LOG_TEXT_BUFFER_SIZE = 256

@ Configuration for Fw::String
@ Note: FPrimeBasicTypes.hpp needs to be updated to sync enum
constant FW_FIXED_LENGTH_STRING_SIZE = 256

# ---------------------------------------------------------------------
# Other constants
# ---------------------------------------------------------------------

@ For the simple object registry provided with the framework, this specifies how many objects the registry will store.
constant FW_OBJ_SIMPLE_REG_ENTRIES = 500

@ For the simple queue registry provided with the framework, this specifies how many queues the registry will store.
constant FW_QUEUE_SIMPLE_QUEUE_ENTRIES = 100

@ Maximum number of cascading FW_ASSERT check failures before forcing a system assert
constant FW_ASSERT_COUNT_MAX = 10

@ Don't care value for time contexts in sequences
constant FW_CONTEXT_DONT_CARE = 0xFF

@ Value encoded during serialization for boolean true
dictionary constant FW_SERIALIZE_TRUE_VALUE = 0xFF

@ Value encoded during serialization for boolean false
dictionary constant FW_SERIALIZE_FALSE_VALUE = 0x00
