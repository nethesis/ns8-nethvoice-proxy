REGISTRY_URL = ghcr.io/nethvoice-proxy
APP_NAME = postgres
REGISTRY_NAME = ${REGISTRY_URL}/$(APP_NAME)
TODAY = $(shell date '+%Y%m%d')

default:
	cat Makefile

test:
	echo $(TODAY)



run: ## Run container
	docker run --detach --name $(APP_NAME) --env-file ../../.env --restart always --network host $(REGISTRY_NAME)

stop: ## Stop a running container
	docker stop $(APP_NAME)

restart: ## Restart container
	docker restart $(APP_NAME)

log: ## show logs
	docker logs $(APP_NAME) -f

sh: ## show logs
	docker exec -it $(APP_NAME) bash

remove: ## Stop and remove a running container
	docker stop $(APP_NAME); docker rm $(APP_NAME); docker rmi -f $(REGISTRY_NAME);



pull: ## Pull a container
	docker pull $(REGISTRY_NAME):latest

build:
	docker build -t $(REGISTRY_NAME):$(TODAY) .
	docker build -t $(REGISTRY_NAME):latest .

build-staging:
	docker build -t $(REGISTRY_NAME):staging .

build-today:
	docker build -t $(REGISTRY_NAME):$(TODAY) .

push:
	docker push $(REGISTRY_NAME):$(TODAY)
	docker push $(REGISTRY_NAME):latest

push-staging:
	docker push $(REGISTRY_NAME):staging

push-today:
	docker push $(REGISTRY_NAME):$(TODAY)

all: build push
