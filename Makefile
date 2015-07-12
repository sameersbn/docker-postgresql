all: build

build:
	@docker build --tag=${USER}/postgresql .

release: build
	@docker build --tag=${USER}/postgresql:$(shell cat VERSION) .
