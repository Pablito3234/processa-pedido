# Processador de Pedidos

Sistema de processamento de pedidos com mensageria. Django monorepo com 5 serviços rodando via Docker Compose ou Kubernetes.

## Arquitetura

```
[Cliente]  ──POST /order──▶  [loja :5000]  ──publish──▶  [RabbitMQ]
                                                               │
                                                          deliver
                                                               │
                                                          [worker]
                                                               │
                                                    transaction.atomic()
                                                               │
                                                          [Postgres]
                                                               │
                                                            ACK()

[Usuário]  ──GET /──▶  [painel :3000]  ──SELECT──▶  [Postgres]
```

### Serviços

| Serviço  | Tecnologia            | Porta | Função |
|----------|-----------------------|-------|--------|
| loja     | Django + DRF          | 5000  | Recebe pedidos via API REST, publica no RabbitMQ |
| rabbitmq | RabbitMQ 3-management | 15672 | Broker — exchange `pedidos`, fila `pedidos.queue` |
| db       | Postgres 15           | 5432  | Tabelas `pedidos` e `itens_pedido` |
| worker   | Django management cmd | —     | Consome fila com ACK manual, insere no banco |
| painel   | Django templates      | 3000  | Visualiza pedidos em tempo real (auto-refresh 4s) |

### Por que RabbitMQ?

RabbitMQ garante **at-least-once delivery** via ACK manual. O worker só confirma (ACK) a mensagem *após* o INSERT no banco ser bem-sucedido. Se o worker cair no meio do processamento, RabbitMQ reenfileira automaticamente — nenhum pedido é perdido.

### Monorepo Django

Um único projeto Django, três apps, uma imagem Docker. Cada serviço roda um comando diferente:

```
loja   → gunicorn config.wsgi:application --bind 0.0.0.0:5000
worker → python manage.py run_worker
painel → gunicorn config.wsgi:application --bind 0.0.0.0:3000
```

## Estrutura

```
.
├── config/          # settings, urls, wsgi
├── pedidos/         # models (Pedido, ItemPedido) + management command run_worker
├── loja/            # DRF: POST /order, GET /health
├── painel/          # views + template HTML com auto-refresh
├── k8s/             # manifests Kubernetes
├── docs/            # documentação detalhada
├── Dockerfile
├── docker-compose.yml
├── docker-compose.dev.yml
└── Makefile
```

## Pré-requisitos

- Docker + Docker Compose
- `make`
- Para K8s: `k3d` + `kubectl`

## Rodando com Docker Compose

```bash
# Dev — hot reload, código local montado em /app
make dev

# Prod — gunicorn
make prod
```

Aguardar ~30s para RabbitMQ ficar healthy. Verificar:

```bash
docker compose ps
```

### Testar

```bash
make order        # envia pedido válido → {"order_id": "...", "status": "queued"}
make order-nack   # envia qty=-1 → worker imprime NACK
make health       # GET /health → {"status": "ok"}
make db-status    # lista pedidos no banco
make logs-worker  # acompanhar ACK/NACK em tempo real
```

### Interfaces

| URL | Descrição |
|-----|-----------|
| http://localhost:5000/order | POST — criar pedido |
| http://localhost:3000 | Painel de pedidos |
| http://localhost:15672 | RabbitMQ Management (guest/guest) |

## Rodando no Kubernetes (k3d)

```bash
# Criar cluster + buildar imagem + aplicar manifests
make k8s-up

# Aguardar pods ficarem Running
make k8s-status

# Testar
make k8s-order
make k8s-order-nack
make k8s-logs-worker

# Acessar RabbitMQ
make k8s-rabbitmq   # port-forward → http://localhost:15672

# Escalar worker
make k8s-scale-worker

# Destruir tudo
make k8s-down
```

## API

### `POST /order`

```json
{
  "cliente": "Maria",
  "itens": [
    {"produto": "Notebook", "qty": 1, "preco": 3500.00},
    {"produto": "Mouse",    "qty": 2, "preco": 89.90}
  ]
}
```

**Resposta:**
```json
{"order_id": "a1b2c3d4", "status": "queued"}
```

### `GET /health`
```json
{"status": "ok"}
```

### `GET /orders`
JSON dos últimos 20 pedidos.

## Comandos úteis

Ver [docs/makefile.md](docs/makefile.md) para referência completa de todos os comandos `make`.

| Comando | Descrição |
|---------|-----------|
| `make dev` / `make prod` | Subir ambiente |
| `make down` / `make down-v` | Parar (com ou sem apagar banco) |
| `make shell` | Django shell interativo |
| `make db-shell` | psql interativo |
| `make k8s-up` | Setup K8s completo do zero |
| `make k8s-down` | Destruir cluster |

## Documentação

| Arquivo | Conteúdo |
|---------|----------|
| [docs/arquitetura.md](docs/arquitetura.md) | Fluxo detalhado, diagrama ASCII, modelos do banco |
| [docs/compose.md](docs/compose.md) | Docker Compose — subir, testar, debug |
| [docs/kubernetes.md](docs/kubernetes.md) | K8s — cluster, deploy, scale, checklist |
| [docs/django.md](docs/django.md) | ORM vs psycopg2, DRF, management commands, migrations |
| [docs/makefile.md](docs/makefile.md) | Referência de todos os comandos `make` |
