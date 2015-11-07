all: build

build:
	@docker build --tag=sameersbn/postgresql .

release: build
	@docker build --tag=sameersbn/postgresql:$(shell cat VERSION) .
