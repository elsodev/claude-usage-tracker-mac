.PHONY: app run test clean

app:
	./scripts/build-app.sh

run: app
	open dist/ClaudeUsage.app

test:
	swift test

clean:
	rm -rf .build dist
