COMPOSE      = docker compose
COMPOSE_DEV  = docker compose -f docker-compose.yml -f docker-compose.dev.yml
CLUSTER      = processador-pedidos
NS           = processador-pedidos
IMAGE        = pedidos-app:v1

# ── Dev ───────────────────────────────────────────────────────────────────────
dev:
	$(COMPOSE_DEV) up --build

dev-d:
	$(COMPOSE_DEV) up --build -d

# ── Prod ──────────────────────────────────────────────────────────────────────
prod:
	$(COMPOSE) up --build -d

# ── Parar ─────────────────────────────────────────────────────────────────────
down:
	$(COMPOSE) down

down-v:
	$(COMPOSE) down -v

# ── Logs ──────────────────────────────────────────────────────────────────────
logs:
	$(COMPOSE) logs -f

logs-worker:
	$(COMPOSE) logs -f worker

logs-loja:
	$(COMPOSE) logs -f loja

# ── Django ────────────────────────────────────────────────────────────────────
migrate:
	$(COMPOSE) exec loja python manage.py migrate

shell:
	$(COMPOSE) exec loja python manage.py shell

# ── Banco ─────────────────────────────────────────────────────────────────────
db-shell:
	$(COMPOSE) exec db psql -U postgres -d pedidosdb

db-status:
	$(COMPOSE) exec db psql -U postgres -d pedidosdb \
	  -c "SELECT id, cliente, total, status FROM pedidos ORDER BY criado_em DESC;"

# ── Testes rápidos ────────────────────────────────────────────────────────────
order:
	curl -s -X POST http://localhost:5000/order \
	  -H "Content-Type: application/json" \
	  -d '{"cliente":"Teste","itens":[{"produto":"Notebook","qty":1,"preco":3500.00},{"produto":"Mouse","qty":2,"preco":89.90}]}' \
	  | python3 -m json.tool

order-nack:
	curl -s -X POST http://localhost:5000/order \
	  -H "Content-Type: application/json" \
	  -d '{"cliente":"Invalido","itens":[{"produto":"X","qty":-1,"preco":10}]}'

health:
	curl -s http://localhost:5000/health | python3 -m json.tool

# ── K8s — setup completo ──────────────────────────────────────────────────────
k8s-cluster:
	k3d cluster create $(CLUSTER) \
	  --servers 1 --agents 2 \
	  --port "5000:30000@loadbalancer" \
	  --port "3000:30001@loadbalancer" \
	  --port "15672:30002@loadbalancer"
	k3d kubeconfig merge $(CLUSTER) --kubeconfig-switch-context
	kubectl create namespace $(NS)

k8s-build:
	docker build -t $(IMAGE) .
	k3d image import $(IMAGE) -c $(CLUSTER)

k8s-deploy:
	kubectl apply -f k8s/
	kubectl get all -n $(NS)

# fluxo completo: cluster → build → deploy
k8s-up: k8s-cluster k8s-build k8s-deploy

# ── K8s — dia a dia ───────────────────────────────────────────────────────────
k8s-status:
	kubectl get all -n $(NS)

k8s-logs-worker:
	kubectl logs -l app=worker -n $(NS) --tail=20 -f

k8s-logs-loja:
	kubectl logs -l app=loja -n $(NS) --tail=20 -f

k8s-order:
	curl -s -X POST http://localhost:5000/order \
	  -H "Content-Type: application/json" \
	  -d '{"cliente":"Teste K8s","itens":[{"produto":"Cadeira","qty":1,"preco":890.00}]}' \
	  | python3 -m json.tool

k8s-order-nack:
	curl -s -X POST http://localhost:5000/order \
	  -H "Content-Type: application/json" \
	  -d '{"cliente":"Invalido","itens":[{"produto":"X","qty":-1,"preco":10}]}'

k8s-rabbitmq:
	kubectl port-forward svc/rabbitmq 15672:15672 -n $(NS)

k8s-scale-worker:
	kubectl scale deployment worker --replicas=2 -n $(NS)
	kubectl get pods -n $(NS) -l app=worker

# ── K8s — destruir ────────────────────────────────────────────────────────────
k8s-down:
	k3d cluster delete $(CLUSTER)

.PHONY: dev dev-d prod down down-v logs logs-worker logs-loja \
        migrate shell db-shell db-status order order-nack health \
        k8s-cluster k8s-build k8s-deploy k8s-up \
        k8s-status k8s-logs-worker k8s-logs-loja k8s-order k8s-order-nack \
        k8s-rabbitmq k8s-scale-worker k8s-down
