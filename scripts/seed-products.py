#!/usr/bin/env python3
"""
Seed sample products into the Spring CRUD Demo API using async HTTP (asyncio + urllib).

No third-party dependencies — only the standard library.

Usage:
    python seed-products.py [--base-url URL] [--count N] [--concurrency N]

Examples:
    python seed-products.py
    python seed-products.py --count 200 --concurrency 30
    python seed-products.py --base-url http://localhost:8080
"""

import argparse
import asyncio
import json
import random
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

CATEGORIES = [
    ("Laptop",   "High-performance laptop",      499.99, 2499.99),
    ("Monitor",  "Full-HD widescreen monitor",   149.99,  799.99),
    ("Keyboard", "Mechanical RGB keyboard",       39.99,  199.99),
    ("Mouse",    "Wireless ergonomic mouse",      19.99,  129.99),
    ("Headset",  "Noise-cancelling headset",      49.99,  349.99),
    ("Webcam",   "4K streaming webcam",           59.99,  249.99),
    ("SSD",      "NVMe solid-state drive",        59.99,  399.99),
    ("RAM",      "DDR5 memory module",            29.99,  179.99),
    ("GPU",      "Discrete graphics card",       199.99, 1299.99),
    ("CPU",      "Multi-core desktop processor",  99.99,  699.99),
]

# ---------------------------------------------------------------------------
# Payload builder
# ---------------------------------------------------------------------------

@dataclass
class Payload:
    index: int
    name: str
    body: bytes


def build_payloads(count: int) -> list[Payload]:
    payloads = []
    for i in range(1, count + 1):
        prefix, desc, lo, hi = CATEGORIES[(i - 1) % len(CATEGORIES)]
        price = round(random.uniform(lo, hi), 2)
        qty   = random.randint(0, 499)
        name  = f"{prefix} Model-{i}"
        data  = {
            "name":        name,
            "description": f"{desc} - unit {i}",
            "price":       price,
            "quantity":    qty,
        }
        payloads.append(Payload(index=i, name=name, body=json.dumps(data).encode()))
    return payloads


# ---------------------------------------------------------------------------
# Async worker
# ---------------------------------------------------------------------------

async def post_product(
    semaphore: asyncio.Semaphore,
    url: str,
    payload: Payload,
    loop: asyncio.AbstractEventLoop,
) -> dict:
    """Send one POST request using a thread-pool executor (keeps urllib's simplicity)."""
    async with semaphore:
        try:
            result = await loop.run_in_executor(None, _do_post, url, payload)
            return result
        except Exception as exc:
            return {"ok": False, "name": payload.name, "error": str(exc)}


def _do_post(url: str, payload: Payload) -> dict:
    req = urllib.request.Request(
        url,
        data=payload.body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read())
            return {"ok": True, "name": body.get("name"), "id": body.get("id"), "price": body.get("price")}
    except urllib.error.HTTPError as exc:
        return {"ok": False, "name": payload.name, "error": f"HTTP {exc.code}"}
    except Exception as exc:
        return {"ok": False, "name": payload.name, "error": str(exc)}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def run(base_url: str, count: int, concurrency: int) -> None:
    url       = f"{base_url}/api/products"
    payloads  = build_payloads(count)
    semaphore = asyncio.Semaphore(concurrency)
    loop      = asyncio.get_event_loop()

    print(f"Seeding {count} products to {url}  [concurrency={concurrency}] ...")

    tasks   = [post_product(semaphore, url, p, loop) for p in payloads]
    results = await asyncio.gather(*tasks)

    ok = failed = 0
    for r in sorted(results, key=lambda x: x.get("name", "")):
        if r["ok"]:
            ok += 1
            print(f"  [OK] {r['name']}  id={r['id']}  price={r['price']}")
        else:
            failed += 1
            print(f"  [FAIL] {r['name']} - {r['error']}", file=sys.stderr)

    print(f"\nDone. Created: {ok}  Failed: {failed}")
    if failed:
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed sample products into the Spring CRUD Demo API.")
    parser.add_argument("--base-url",    default="http://localhost:8080", help="API base URL (default: http://localhost:8080)")
    parser.add_argument("--count",       default=100,  type=int, help="Number of products to create (default: 100)")
    parser.add_argument("--concurrency", default=20,   type=int, help="Max simultaneous requests (default: 20)")
    args = parser.parse_args()

    asyncio.run(run(args.base_url, args.count, args.concurrency))


if __name__ == "__main__":
    main()
