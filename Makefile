.PHONY: build app install smoke clean

build:
	swift build --package-path app/SwitchPilot --build-system native

app:
	./scripts/build-app

install:
	./scripts/install-app

smoke:
	./scripts/smoke.sh

clean:
	swift package --package-path app/SwitchPilot clean
	rm -rf app/SwitchPilot/.build
