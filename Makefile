.PHONY: setup run test lint format docker-build tf-stage2-init tf-stage2-plan tf-stage2-apply tf-stage2-destroy

setup:
	python3 -m venv .venv
	. .venv/bin/activate && pip install --upgrade pip && pip install -e './backend[dev]'

run:
	. .venv/bin/activate && uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000

test:
	. .venv/bin/activate && pytest backend/tests -q

lint:
	. .venv/bin/activate && ruff check backend

format:
	. .venv/bin/activate && ruff format backend

docker-build:
	docker build -t regintel-api:dev -f backend/Dockerfile .

tf-stage2-init:
	terraform -chdir=infrastructure/terraform/stage2 init

tf-stage2-plan:
	terraform -chdir=infrastructure/terraform/stage2 plan

tf-stage2-apply:
	terraform -chdir=infrastructure/terraform/stage2 apply

tf-stage2-destroy:
	terraform -chdir=infrastructure/terraform/stage2 destroy
