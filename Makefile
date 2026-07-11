.PHONY: setup

setup:
	git fetch origin
	git checkout lucadev
	git pull origin lucadev
	python3.12 -m venv fprime-venv
	@echo "make setup complete"