# RP2350/Zephyr OSAL storage sizes. Zephyr 4.3's k_thread makes the task
# implementation larger than the F Prime default of 40 bytes.
constant FW_CONSOLE_HANDLE_MAX_SIZE = 24
constant FW_TASK_HANDLE_MAX_SIZE = 192
constant FW_FILE_HANDLE_MAX_SIZE = 16
constant FW_MUTEX_HANDLE_MAX_SIZE = 72
constant FW_QUEUE_HANDLE_MAX_SIZE = 368
constant FW_DIRECTORY_HANDLE_MAX_SIZE = 16
constant FW_FILESYSTEM_HANDLE_MAX_SIZE = 16
constant FW_RAW_TIME_HANDLE_MAX_SIZE = 56
constant FW_RAW_TIME_SERIALIZATION_MAX_SIZE = 8
constant FW_CONDITION_VARIABLE_HANDLE_MAX_SIZE = 56
constant FW_CPU_HANDLE_MAX_SIZE = 16
constant FW_MEMORY_HANDLE_MAX_SIZE = 16
constant FW_HANDLE_ALIGNMENT = 8

# Reduced from the framework default of 512 (see FpConstants.fpp for the
# paired FW_COM_BUFFER_MAX_SIZE override -- F's config-override locator maps
# by the filename that originally defined each constant, and this one is
# defined in the framework's own PlatformCfg.fpp, matching this file).
# FW_FILE_BUFFER_MAX_SIZE equals FW_COM_BUFFER_MAX_SIZE exactly (no
# subtraction), so file downlink chunks must still fit whole -- reduced in
# step with that constant. Smaller chunks mean slower file transfers, not
# broken ones; this project's data-product files are small.
constant FW_FILE_CHUNK_SIZE = 128
