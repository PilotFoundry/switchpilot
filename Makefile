.PHONY: build app release install smoke docs-check clean

build:
	swift build --package-path app/SwitchPilot --build-system native

app:
	./scripts/build-app

release:
	./scripts/build-release

install:
	./scripts/install-app

smoke:
	./scripts/smoke.sh

docs-check:
	python3 scripts/check-docs.py

clean:
	swift package --package-path app/SwitchPilot clean
	rm -rf app/SwitchPilot/.build
