.PHONY: build-cli build-api build-linux test lint clean \
        flutter-get flutter-test flutter-analyze flutter-build

build-cli:
	go build -o vive ./cmd/vive-admin

build-api:
	go build -o vive-api-server ./cmd/vive-api-server

build-linux:
	GOOS=linux GOARCH=amd64 go build -o vive-linux ./cmd/vive-admin

test: flutter-test
	go test ./... -v

flutter-get:
	flutter pub get

flutter-test:
	flutter test

flutter-analyze:
	dart analyze

flutter-build:
	flutter build apk --debug

lint: flutter-analyze
	go vet ./... && golangci-lint run ./... || echo "golangci-lint not installed, using go vet only"

clean:
	rm -f vive vive-linux vive-api-server
	rm -rf build/ .dart_tool/
