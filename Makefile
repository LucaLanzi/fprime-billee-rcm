PROJECT_ROOT := $(CURDIR)
VENV_PYTHON := $(PROJECT_ROOT)/fprime-venv/bin/python
VENV_FPRIME_UTIL := $(PROJECT_ROOT)/fprime-venv/bin/fprime-util

export FPRIME_FRAMEWORK_PATH := $(PROJECT_ROOT)/lib/fprime

.PHONY: setup zephyr-setup clean-zephyr zephyr-rp2350 print-env check-env

setup:
	git checkout lucadev
	python3.12 -m venv fprime-venv
	$(VENV_PYTHON) -m pip install -r requirements.txt
	grep -q "FPRIME_FRAMEWORK_PATH" fprime-venv/bin/activate || echo 'export FPRIME_FRAMEWORK_PATH=$(PROJECT_ROOT)/lib/fprime' >> fprime-venv/bin/activate
	@echo "make setup complete"

zephyr-setup:
	$(VENV_PYTHON) -m pip install -r requirements-zephyr.txt
	$(VENV_PYTHON) -m west update
	$(VENV_PYTHON) -m west packages pip --install
	$(VENV_PYTHON) -m west sdk install
	@echo "make zephyr-setup complete"

clean-zephyr:
	rm -rf build-fprime-automatic-zephyr build-artifacts/zephyr
	@echo "make clean-zephyr complete"

zephyr-rp2350: clean-zephyr
	$(VENV_FPRIME_UTIL) generate -DBOARD=rpi_pico2/rp2350a/m33 zephyr -f
	$(VENV_FPRIME_UTIL) build zephyr
	@echo "make zephyr-rp2350 complete"

print-env:
	@echo "Make PROJECT_ROOT=$(PROJECT_ROOT)"
	@echo "Make FPRIME_FRAMEWORK_PATH=$(FPRIME_FRAMEWORK_PATH)"
	@echo "Shell FPRIME_FRAMEWORK_PATH=$$FPRIME_FRAMEWORK_PATH"

check-env:
	@test -d "$$FPRIME_FRAMEWORK_PATH" || (echo "Invalid FPRIME_FRAMEWORK_PATH: $$FPRIME_FRAMEWORK_PATH" && exit 1)
	@test -f "$$FPRIME_FRAMEWORK_PATH/cmake/FPrime.cmake" || (echo "Does not look like F Prime: $$FPRIME_FRAMEWORK_PATH" && exit 1)
	@echo "FPRIME_FRAMEWORK_PATH is valid: $$FPRIME_FRAMEWORK_PATH"