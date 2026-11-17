VERSION ?= 1.0.0
APP := build/Cambio.app
BIN := $(APP)/Contents/MacOS/Cambio

.PHONY: test app run install zip screenshots icon clean

test:
	swift test

app:
	scripts/build-app.sh $(VERSION)

run: app
	open $(APP)

install: app
	-osascript -e 'quit app id "app.cambio.Cambio"' 2>/dev/null
	-pkill -x Cambio
	rm -rf /Applications/Cambio.app
	ditto $(APP) /Applications/Cambio.app
	open /Applications/Cambio.app

zip: app
	ditto -c -k --keepParent $(APP) build/Cambio-$(VERSION).zip

screenshots: app
	$(BIN) --snapshot docs/screenshots/en -AppleLanguages "(en)" -AppleLocale en_US
	$(BIN) --snapshot docs/screenshots/pt-BR -AppleLanguages "(pt-BR)" -AppleLocale pt_BR

icon:
	swift scripts/make-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build build
