PROJECT_ROOT := $(CURDIR)
PYTHON ?= python3
VENV_PYTHON := $(PROJECT_ROOT)/fprime-venv/bin/python
VENV_FPRIME_UTIL := $(PROJECT_ROOT)/fprime-venv/bin/fprime-util

export FPRIME_FRAMEWORK_PATH := $(PROJECT_ROOT)/lib/fprime
export PATH := $(PROJECT_ROOT)/fprime-venv/bin:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help setup setup-zephyr setup-picotool clean-zephyr build-rp2350 gds cpfirm print-banner

PICOTOOL_DIR := $(PROJECT_ROOT)/build-tools

help: ## Show available commands
	@$(MAKE) --no-print-directory print-banner
	@echo "Available commands:"
	@grep -E '^[A-Za-z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*##"} {printf "  %-20s %s\n", $$1, $$2}'

setup: ## Create venv and install project dependencies
	$(PYTHON) -m venv fprime-venv
	git submodule update --init --recursive
	$(VENV_PYTHON) -m pip install -r requirements.txt
	grep -q "FPRIME_FRAMEWORK_PATH" fprime-venv/bin/activate || echo 'export FPRIME_FRAMEWORK_PATH=$(PROJECT_ROOT)/lib/fprime' >> fprime-venv/bin/activate
	-@$(MAKE) --no-print-directory setup-picotool || echo "[WARN] picotool not installed — flash via the BOOTSEL button, or retry 'make setup-picotool'"
	@echo "make setup complete"
	@$(MAKE) --no-print-directory print-banner

setup-picotool: ## Install picotool (apt if available, else build from source)
	@if command -v picotool >/dev/null 2>&1; then \
		echo "[INFO] picotool already installed: $$(command -v picotool)"; \
		exit 0; \
	fi; \
	echo "[INFO] Installing picotool via apt..."; \
	if sudo apt-get update -qq && sudo apt-get install -y picotool >/dev/null 2>&1 \
	   && command -v picotool >/dev/null 2>&1; then \
		echo "[INFO] Installed picotool from apt."; exit 0; \
	fi; \
	echo "[INFO] apt has no picotool for this release — building from source..."; \
	sudo apt-get install -y git cmake build-essential pkg-config libusb-1.0-0-dev || exit 1; \
	rm -rf "$(PICOTOOL_DIR)/picotool" "$(PICOTOOL_DIR)/pico-sdk"; \
	mkdir -p "$(PICOTOOL_DIR)"; \
	git clone --depth 1 https://github.com/raspberrypi/pico-sdk "$(PICOTOOL_DIR)/pico-sdk" || exit 1; \
	git clone --depth 1 https://github.com/raspberrypi/picotool "$(PICOTOOL_DIR)/picotool" || exit 1; \
	cmake -S "$(PICOTOOL_DIR)/picotool" -B "$(PICOTOOL_DIR)/picotool/build" \
		-DPICO_SDK_PATH="$(PICOTOOL_DIR)/pico-sdk" || exit 1; \
	cmake --build "$(PICOTOOL_DIR)/picotool/build" -j"$$(nproc)" || exit 1; \
	sudo cmake --install "$(PICOTOOL_DIR)/picotool/build" || exit 1; \
	printf 'SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0666", TAG+="uaccess"\n' \
		| sudo tee /etc/udev/rules.d/99-picotool.rules >/dev/null; \
	sudo udevadm control --reload-rules 2>/dev/null && sudo udevadm trigger 2>/dev/null || true; \
	if command -v picotool >/dev/null 2>&1; then \
		echo "[INFO] picotool installed: $$(picotool version 2>/dev/null | head -1)"; \
	else \
		echo "[ERROR] picotool built but not on PATH — check /usr/local/bin/picotool"; exit 1; \
	fi

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
GDS_SERVICE ?= billee-lan-gds

.PHONY: gds wsl mac linux bootsel \
        install-gds-service uninstall-gds-service gds-service-status gds-attach

bootsel: ## Reboot a running RP2350 into BOOTSEL mode (needs picotool + firmware support)
	@command -v picotool >/dev/null 2>&1 || { \
		echo "[ERROR] picotool not installed. sudo apt install picotool"; exit 1; \
	}
	@picotool reboot -f -u || sudo picotool reboot -f -u || { \
		echo "[ERROR] picotool couldn't reboot the board. Use the BOOTSEL button:"; \
		echo "        hold BOOTSEL, tap RESET (or replug USB), release."; \
		exit 1; \
	}
	@echo "[INFO] Board should now be in BOOTSEL — run 'make cpfirm'."

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

install-gds-service: ## Install+enable a systemd service: lan_uart_gds.sh in a detached screen, auto-retry every 10s
	sudo ./install-lan-gds-service.sh

uninstall-gds-service: ## Stop and remove the billee-lan-gds systemd service
	-sudo systemctl disable --now $(GDS_SERVICE).service
	sudo rm -f /etc/systemd/system/$(GDS_SERVICE).service
	sudo systemctl daemon-reload
	@echo "[INFO] $(GDS_SERVICE) removed"

gds-service-status: ## Show billee-lan-gds service status and recent logs
	@systemctl status $(GDS_SERVICE).service --no-pager || true
	@echo
	@journalctl -u $(GDS_SERVICE).service -n 30 --no-pager || true

gds-attach: ## Attach to the running GDS screen session (Ctrl-A then D to detach)
	screen -r $(GDS_SERVICE)

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
				sudo cp "$(UF2_FILE)" "$$mnt/"; cp_rc=$$?; \
				sync; \
				sudo umount "$$mnt" 2>/dev/null || true; \
				rmdir "$$mnt" 2>/dev/null || true; \
				if [ "$$cp_rc" -ne 0 ]; then \
					echo "[ERROR] copy to $$dev failed (rc $$cp_rc)."; exit 1; \
				fi; \
				echo "[INFO] Flashed via $$dev — the board resets itself."; \
				copied=1; \
			fi; \
		fi; \
		if [ -z "$$copied" ] && command -v picotool >/dev/null 2>&1; then \
			echo "[INFO] No BOOTSEL disk found — trying picotool ('-f' reboots a running board into BOOTSEL)..."; \
			if picotool load -x -f "$(UF2_FILE)" || sudo picotool load -x -f "$(UF2_FILE)"; then \
				echo "[INFO] Flashed with picotool."; copied=1; \
			fi; \
		fi; \
		if [ -z "$$copied" ]; then \
			echo "[ERROR] No RP2350 in BOOTSEL mode, and picotool couldn't reach it."; \
			echo "        /dev/ttyACM* present means firmware is running, NOT in BOOTSEL."; \
			echo "        Fixes, easiest first:"; \
			echo "          1. sudo apt install picotool   (then re-run 'make cpfirm')"; \
			echo "          2. Hold the board's BOOTSEL button, tap RESET / replug USB,"; \
			echo "             release. 'lsblk' then shows a ~1MB disk labelled RP2350."; \
			echo "          3. No BOOTSEL button? Flash over SWD with a debug probe:"; \
			echo "             picotool load -x build-artifacts/zephyr.uf2 --bus <n> (via probe)"; \
			echo "        LINUX_BOOTSEL_VOLUME must be a MOUNT DIRECTORY, not /dev/tty*."; \
			exit 1; \
		fi; \
	fi
