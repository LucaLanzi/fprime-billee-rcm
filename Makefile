.PHONY: setup zephyr-setup

setup:
	git fetch origin
	git checkout lucadev
	git pull origin lucadev
	python3.12 -m venv fprime-venv
	@echo "make setup complete"

zephyr-setup:
	fprime-venv/bin/python -m pip install -r requirements-zephyr.txt
	fprime-venv/bin/python -m west update
	fprime-venv/bin/python -m west packages pip --install
	fprime-venv/bin/python -m west sdk install
	@echo "make zephyr-setup complete"
