all: build

build:
	@docker build --tag=boky/postgresql .

release: build
	@docker build --tag=postgresql:$(shell cat VERSION) .
