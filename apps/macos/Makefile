.PHONY: build test app release run clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh debug

release:
	./scripts/build-app.sh release

run: app
	open build/IsleNest.app

clean:
	rm -rf .build build
