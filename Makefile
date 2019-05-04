all: build

build:
	@docker build --tag=yassan/postgresql .

release: build
	@docker build --tag=yassan/postgresql:$(shell cat VERSION) .
