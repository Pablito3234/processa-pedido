COMPOSE      = docker compose
COMPOSE_DEV  = docker compose -f docker-compose.yml -f docker-compose.dev.yml

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

# ── K8s ───────────────────────────────────────────────────────────────────────
k8s-build:
	docker build -t pedidos-app:v1 .
	k3d image import pedidos-app:v1 -c processador-pedidos

k8s-up:
	kubectl apply -f k8s/
	kubectl get all -n processador-pedidos

k8s-down:
	kubectl delete namespace processador-pedidos

k8s-logs-worker:
	kubectl logs -l app=worker -n processador-pedidos --tail=20 -f

.PHONY: dev dev-d prod down down-v logs logs-worker logs-loja \
        migrate shell db-shell db-status order order-nack health \
        k8s-build k8s-up k8s-down k8s-logs-worker
