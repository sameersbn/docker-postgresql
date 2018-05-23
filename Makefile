all: build

build:
	docker build --tag=fmartingr/postgres .

release:
	docker build --tag=fmartingr/postgres:$(shell cat VERSION) .
	docker build --tag=fmartingr/postgres:latest .
	docker push fmartingr/postgres

test:
	make build
	docker run -d --name=test-postgres fmartingr/postgres; sleep 10
	docker run -it --volumes-from=test-postgres fmartingr/postgres sudo -u postgres -H psql -c "\conninfo"
	docker stop test-postgres
	docker rm test-postgres
