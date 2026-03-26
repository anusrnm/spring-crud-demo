# Spring CRUD Demo

Spring Boot 3.3 · Java 21 · PostgreSQL — REST CRUD API for product inventory.

## Requirements

| Tool | Version |
|------|---------|
| Java | 21 (`C:\jdk-21`) |
| Maven | 3.9+ |
| Docker + Docker Compose | any recent version |

---

## Quick start (Docker Compose)

Starts the app and a PostgreSQL 16 sidecar in one command:

```powershell
docker compose up --build
```

The app is available at `http://localhost:8080` once the `app` container logs `Started SpringCrudDemoApplication`.

Stop and remove containers + volume:

```powershell
docker compose down -v
```

---

## Run locally (without Docker)

Requires a reachable PostgreSQL instance.  Update `src/main/resources/application.yml` with your local connection details, then:

```powershell
$env:JAVA_HOME = 'C:\jdk-21'
$env:Path      = "$env:JAVA_HOME\bin;$env:Path"
mvn spring-boot:run
```

---

## Build & test

```powershell
$env:JAVA_HOME = 'C:\jdk-21'
$env:Path      = "$env:JAVA_HOME\bin;$env:Path"
mvn -B test      # unit + integration tests (H2 in-memory)
mvn -B verify    # full lifecycle + packaged JAR
```

---

## REST API

Base path: `/api/products`

| Method | Path | Description | Success |
|--------|------|-------------|---------|
| `GET` | `/api/products` | List all products | 200 |
| `GET` | `/api/products/{id}` | Get product by id | 200 |
| `POST` | `/api/products` | Create a product | 201 |
| `PUT` | `/api/products/{id}` | Update a product | 200 |
| `DELETE` | `/api/products/{id}` | Delete a product | 204 |

### Product payload

```json
{
  "name":        "Keyboard Model-1",
  "description": "Mechanical RGB keyboard — unit 1",
  "price":       89.99,
  "quantity":    42
}
```

`name` and `price` (> 0) and `quantity` (≥ 0) are required.
`400 Bad Request` is returned for validation failures; `404 Not Found` when the id does not exist.

---

## OpenAPI / Swagger UI

Available while the app is running:

| Resource | URL |
|----------|-----|
| OpenAPI JSON | `http://localhost:8080/api-docs` |
| Swagger UI | `http://localhost:8080/swagger-ui.html` |

---

## Seed sample data

Two scripts in `scripts/` POST 100 products (10 categories × 10 rounds) to the running API using parallel HTTP requests.

**PowerShell (Windows — requires PowerShell 7+)**

```powershell
.\scripts\seed-products.ps1
# optional overrides:
.\scripts\seed-products.ps1 -BaseUrl http://localhost:8080 -Count 50 -Concurrency 30
```

**Python (cross-platform — stdlib only, Python 3.11+)**

```bash
python scripts/seed-products.py
# optional overrides:
python scripts/seed-products.py --count 200 --concurrency 30 --base-url http://localhost:8080
```

**Bash (Linux / WSL / macOS)** — requires `curl` and `awk`:

```bash
chmod +x scripts/seed-products.sh
./scripts/seed-products.sh
# optional overrides:
./scripts/seed-products.sh http://localhost:8080 50 30
```

Both scripts print a confirmation line for each created product and a summary at the end.

---

## Project structure

```
src/
  main/
    java/com/example/springcruddemo/
      SpringCrudDemoApplication.java   # entry point
      product/
        Product.java                   # JPA entity
        ProductRepository.java         # Spring Data repository
        ProductService.java            # business logic
        ProductController.java         # REST controller (OpenAPI annotated)
        ProductNotFoundException.java  # domain exception
        RestExceptionHandler.java      # global error handler
        ApiError.java                  # error response record
    resources/
      application.yml                  # production config (PostgreSQL)
  test/
    java/.../product/
      ProductControllerTest.java       # MockMvc integration tests
    resources/
      application.yml                  # test config (H2 in-memory)
scripts/
  seed-products.ps1                    # PowerShell seed script (parallel, PS 7+)
  seed-products.py                     # Python seed script (asyncio + stdlib, no deps)
  seed-products.sh                     # Bash seed script (parallel background jobs)
Dockerfile                             # multi-stage build (Maven → JRE)
docker-compose.yml                     # app + postgres services
```
