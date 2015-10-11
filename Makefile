all: build

build:
	@docker build --tag=quay.io/sameersbn/postgresql .

release: build
	@docker build --tag=quay.io/sameersbn/postgresql:$(shell cat VERSION) .
