PROJECT_ROOT := $(CURDIR)
PYTHON ?= python3
VENV_PYTHON := $(PROJECT_ROOT)/fprime-venv/bin/python
VENV_FPRIME_UTIL := $(PROJECT_ROOT)/fprime-venv/bin/fprime-util

export FPRIME_FRAMEWORK_PATH := $(PROJECT_ROOT)/lib/fprime
export PATH := $(PROJECT_ROOT)/fprime-venv/bin:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help setup setup-zephyr clean-zephyr build-rp2350 gds cpfirm print-env check-env

help: ## Show available commands
	@echo "Available commands:"
	@grep -E '^[A-Za-z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"} {printf "  %-20s %s\n", $$1, $$2}'

setup: ## Create venv and install project dependencies
	$(PYTHON) -m venv fprime-venv
	$(VENV_PYTHON) -m pip install -r requirements.txt
	grep -q "FPRIME_FRAMEWORK_PATH" fprime-venv/bin/activate || echo 'export FPRIME_FRAMEWORK_PATH=$(PROJECT_ROOT)/lib/fprime' >> fprime-venv/bin/activate
	@echo "make setup complete"

setup-zephyr: ## Install Zephyr dependencies
	$(VENV_PYTHON) -m pip install -r requirements-zephyr.txt
	$(VENV_PYTHON) -m west update
	$(VENV_PYTHON) -m west packages pip --install
	$(VENV_PYTHON) -m west sdk install --toolchains arm-zephyr-eabi
	@echo "make zephyr-setup complete"

clean-zephyr: ## Remove Zephyr build outputs
	rm -rf build-fprime-automatic-zephyr build-artifacts/zephyr
	@echo "make clean-zephyr complete"

build-rp2350: clean-zephyr ## Build the RP2350 Zephyr target
	$(VENV_FPRIME_UTIL) generate -DBOARD=rpi_pico2/rp2350a/m33 zephyr -f
	$(VENV_FPRIME_UTIL) build zephyr
	@echo "make build-rp2350 complete"

USBIPD_BUSID ?= 2-4
MAC_UART_DEVICE ?= /dev/tty.usbmodem2101

.PHONY: gds wsl mac

gds:
	@if [ "$(filter wsl,$(MAKECMDGOALS))" = "wsl" ]; then \
		echo "[INFO] Attaching USB device $(USBIPD_BUSID) to WSL..."; \
		powershell.exe -NoProfile -Command \
			"usbipd attach --wsl --busid $(USBIPD_BUSID)" || { \
				echo "[ERROR] Failed to attach USB device $(USBIPD_BUSID)"; \
				exit 1; \
			}; \
	fi
	@if [ "$(filter mac,$(MAKECMDGOALS))" = "mac" ]; then \
		UART_DEVICE="$(MAC_UART_DEVICE)" ./uart_gds.sh; \
	else \
		./uart_gds.sh; \
	fi

# Dummy targets used only as command-line keywords
wsl:
	@:

mac:
	@:

UF2_FILE := $(PROJECT_ROOT)/build-artifacts/zephyr.uf2

MAC_BOOTSEL_VOLUME ?= /Volumes/RP2350
LINUX_BOOTSEL_VOLUME ?= /media/$(shell whoami)/RP2350
WSL_BOOTSEL_DRIVE ?= D:

cpfirm: ## Copy build-artifacts/zephyr.uf2 to the board while it is in BOOTSEL mode
	@test -f "$(UF2_FILE)" || { \
		echo "[ERROR] $(UF2_FILE) not found. Run 'make build-rp2350' first."; \
		exit 1; \
	}
	@if [ "$(filter mac,$(MAKECMDGOALS))" = "mac" ]; then \
		test -d "$(MAC_BOOTSEL_VOLUME)" || { \
			echo "[ERROR] $(MAC_BOOTSEL_VOLUME) not found. Is the board in BOOTSEL mode?"; \
			exit 1; \
		}; \
		cp "$(UF2_FILE)" "$(MAC_BOOTSEL_VOLUME)/" && echo "[INFO] Copied to $(MAC_BOOTSEL_VOLUME)"; \
	elif [ "$(filter wsl,$(MAKECMDGOALS))" = "wsl" ]; then \
		echo "[INFO] Attaching USB device $(USBIPD_BUSID) to WSL..."; \
		powershell.exe -NoProfile -Command \
			"usbipd attach --wsl --busid $(USBIPD_BUSID)" || { \
				echo "[ERROR] Failed to attach USB device $(USBIPD_BUSID)"; \
				exit 1; \
			}; \
		echo "[INFO] Copying via Windows drive $(WSL_BOOTSEL_DRIVE) (adjust WSL_BOOTSEL_DRIVE if the board mounts elsewhere)..."; \
		WIN_UF2_PATH="$$(wslpath -w "$(UF2_FILE)")"; \
		powershell.exe -NoProfile -Command \
			"Copy-Item -Path '$$WIN_UF2_PATH' -Destination '$(WSL_BOOTSEL_DRIVE)\\'" || { \
				echo "[ERROR] Failed to copy to $(WSL_BOOTSEL_DRIVE). Is the board in BOOTSEL mode and mounted at that drive letter?"; \
				exit 1; \
			}; \
		echo "[INFO] Copied to $(WSL_BOOTSEL_DRIVE)"; \
	else \
		test -d "$(LINUX_BOOTSEL_VOLUME)" || { \
			echo "[ERROR] $(LINUX_BOOTSEL_VOLUME) not found. Is the board in BOOTSEL mode? Set LINUX_BOOTSEL_VOLUME if it mounts elsewhere."; \
			exit 1; \
		}; \
		cp "$(UF2_FILE)" "$(LINUX_BOOTSEL_VOLUME)/" && echo "[INFO] Copied to $(LINUX_BOOTSEL_VOLUME)"; \
	fi

print-env: ## Print Make and shell environment values
	@echo "Make PROJECT_ROOT=$(PROJECT_ROOT)"
	@echo "Make FPRIME_FRAMEWORK_PATH=$(FPRIME_FRAMEWORK_PATH)"
	@echo "Shell FPRIME_FRAMEWORK_PATH=$$FPRIME_FRAMEWORK_PATH"

check-env: ## Validate FPRIME_FRAMEWORK_PATH
	@test -d "$$FPRIME_FRAMEWORK_PATH" || (echo "Invalid FPRIME_FRAMEWORK_PATH: $$FPRIME_FRAMEWORK_PATH" && exit 1)
	@test -f "$$FPRIME_FRAMEWORK_PATH/cmake/FPrime.cmake" || (echo "Does not look like F Prime: $$FPRIME_FRAMEWORK_PATH" && exit 1)
	@echo "FPRIME_FRAMEWORK_PATH is valid: $$FPRIME_FRAMEWORK_PATH"
