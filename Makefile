PYTHON ?= python3
PORT ?= 8000

.PHONY: install check run love web build size serve dev clean

install:
	npm ci

check:
	$(PYTHON) tools/build.py check

run:
	$(PYTHON) tools/build.py run

love:
	$(PYTHON) tools/build.py love

web build:
	$(PYTHON) tools/build.py web

size:
	$(PYTHON) tools/build.py size

serve:
	$(PYTHON) tools/build.py serve --port $(PORT)

dev:
	$(PYTHON) tools/build.py dev --port $(PORT)

clean:
	$(PYTHON) tools/build.py clean
