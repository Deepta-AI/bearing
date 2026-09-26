import os

import psycopg
import uvicorn
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route

from catalogue.search import search

DSN = os.environ.get("DATABASE_URL", "postgresql://localhost/catalogue")


async def catalogue(request):
    page = int(request.query_params.get("page", "1"))
    with psycopg.connect(DSN) as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT id, name, price_paise FROM products WHERE active"
            " ORDER BY popularity DESC LIMIT 48 OFFSET %s",
            ((page - 1) * 48,),
        )
        rows = cur.fetchall()
    return JSONResponse([{"id": r[0], "name": r[1], "price_paise": r[2]} for r in rows])


async def search_route(request):
    q = request.query_params.get("q", "").strip()
    if not q:
        return JSONResponse([])
    with psycopg.connect(DSN) as conn:
        return JSONResponse(search(conn, q))


app = Starlette(routes=[Route("/catalogue", catalogue), Route("/search", search_route)])


def main():
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
