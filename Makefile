PROJECT_ROOT := $(CURDIR)
PYTHON ?= python3
VENV_PYTHON := $(PROJECT_ROOT)/fprime-venv/bin/python
VENV_FPRIME_UTIL := $(PROJECT_ROOT)/fprime-venv/bin/fprime-util

export FPRIME_FRAMEWORK_PATH := $(PROJECT_ROOT)/lib/fprime
export PATH := $(PROJECT_ROOT)/fprime-venv/bin:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help setup setup-zephyr clean-zephyr build-rp2350 gds cpfirm print-banner

help: ## Show available commands
	@echo "Available commands:"
	@grep -E '^[A-Za-z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"} {printf "  %-20s %s\n", $$1, $$2}'

setup: ## Create venv and install project dependencies
	$(PYTHON) -m venv fprime-venv
	git submodule update --init --recursive
	$(VENV_PYTHON) -m pip install -r requirements.txt
	grep -q "FPRIME_FRAMEWORK_PATH" fprime-venv/bin/activate || echo 'export FPRIME_FRAMEWORK_PATH=$(PROJECT_ROOT)/lib/fprime' >> fprime-venv/bin/activate
	@echo "make setup complete"
	@$(MAKE) --no-print-directory print-banner

setup-zephyr: ## Install Zephyr dependencies
	$(VENV_PYTHON) -m pip install -r requirements-zephyr.txt
	$(VENV_PYTHON) -m west update
	$(VENV_PYTHON) -m west packages pip --install
	$(VENV_PYTHON) -m west sdk install --toolchains arm-zephyr-eabi
	@echo "make zephyr-setup complete"
	@$(MAKE) --no-print-directory print-banner

print-banner: ## Print the project splash screen
	@echo ""
	@echo "██████╗  ██╗██╗     ██╗     ███████╗███████╗"
	@echo "██╔══██╗ ██║██║     ██║     ██╔════╝██╔════╝"
	@echo "██████╔╝ ██║██║     ██║     █████╗  █████╗  "
	@echo "██╔══██╗ ██║██║     ██║     ██╔══╝  ██╔══╝  "
	@echo "██████╔╝ ██║███████╗███████╗███████╗███████╗"
	@echo "╚═════╝  ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝"
	@echo ""
	@echo "        Rover Control Module"
	@echo "        Powered by F\` Flight Software (NASA/JPL)"
	@echo ""

clean-zephyr: ## Remove Zephyr build outputs
	rm -rf build-fprime-automatic-zephyr build-artifacts/zephyr
	@echo "make clean-zephyr complete"

build-rp2350: clean-zephyr ## Build the RP2350 Zephyr target
	$(VENV_FPRIME_UTIL) generate -DBOARD=rpi_pico2/rp2350a/m33 zephyr -f
	$(VENV_FPRIME_UTIL) build zephyr
	@echo "make build-rp2350 complete"

USBIPD_BUSID ?= 2-4
MAC_UART_DEVICE ?= /dev/tty.usbmodem2101

.PHONY: gds wsl mac linux

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

linux:
	@:

UF2_FILE := $(PROJECT_ROOT)/build-artifacts/zephyr.uf2

MAC_BOOTSEL_VOLUME ?= /Volumes/RP2350
WSL_BOOTSEL_DRIVE ?= D:
# Linux: candidate auto-mount points, checked in order. If none exist, cpfirm
# auto-detects an unmounted RP2350 / RPI-RP2 mass-storage device and mounts it
# (needs sudo), then falls back to picotool if that's installed.
LINUX_BOOTSEL_VOLUME ?= /media/$(shell whoami)/RP2350 /run/media/$(shell whoami)/RP2350 /media/RP2350 /mnt/RP2350
LINUX_BOOTSEL_LABELS ?= RP2350 RPI-RP2

cpfirm: ## Copy build-artifacts/zephyr.uf2 to the board in BOOTSEL mode (Linux: auto-mounts or uses picotool)
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
		copied=""; \
		for vol in $(LINUX_BOOTSEL_VOLUME); do \
			if [ -d "$$vol" ]; then \
				echo "[INFO] Found mounted BOOTSEL volume $$vol"; \
				cp "$(UF2_FILE)" "$$vol/" && sync && echo "[INFO] Copied to $$vol"; \
				copied=1; break; \
			fi; \
		done; \
		if [ -z "$$copied" ]; then \
			dev=""; \
			for lbl in $(LINUX_BOOTSEL_LABELS); do \
				dev="$$(lsblk -rpno NAME,LABEL 2>/dev/null | awk -v l="$$lbl" '$$2==l{print $$1; exit}')"; \
				[ -n "$$dev" ] && { echo "[INFO] Found BOOTSEL block device $$dev (label $$lbl)"; break; }; \
			done; \
			if [ -n "$$dev" ]; then \
				mnt="$$(mktemp -d)"; \
				echo "[INFO] Mounting $$dev at $$mnt (sudo)..."; \
				sudo mount "$$dev" "$$mnt" || { echo "[ERROR] mount $$dev failed."; rmdir "$$mnt" 2>/dev/null || true; exit 1; }; \
				cp "$(UF2_FILE)" "$$mnt/" && sync; \
				sudo umount "$$mnt" 2>/dev/null || true; \
				rmdir "$$mnt" 2>/dev/null || true; \
				echo "[INFO] Flashed via $$dev — the board resets itself."; \
				copied=1; \
			fi; \
		fi; \
		if [ -z "$$copied" ] && command -v picotool >/dev/null 2>&1; then \
			echo "[INFO] No BOOTSEL volume found; trying picotool (add -f yourself to force a running board into BOOTSEL)..."; \
			if picotool load -x "$(UF2_FILE)" || sudo picotool load -x "$(UF2_FILE)"; then \
				echo "[INFO] Flashed with picotool."; copied=1; \
			fi; \
		fi; \
		if [ -z "$$copied" ]; then \
			echo "[ERROR] No RP2350 in BOOTSEL mode found."; \
			echo "        Put the board in BOOTSEL: hold BOOTSEL, tap RESET (or replug), then re-run."; \
			echo "        Or install picotool ('sudo apt install picotool') and run:"; \
			echo "            picotool reboot -f -u && make cpfirm"; \
			echo "        If it auto-mounts to an unusual path:"; \
			echo "            make cpfirm LINUX_BOOTSEL_VOLUME=/path/to/RP2350"; \
			exit 1; \
		fi; \
	fi
