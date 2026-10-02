from contextlib import asynccontextmanager
from pathlib import Path
from time import perf_counter

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from sqlalchemy import select, update

from app.database import Booking, Match, SessionLocal, initialize_database

BASE_DIR = Path(__file__).resolve().parent


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_database()
    yield


app = FastAPI(title="BoundaryPass Cricket Tickets", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=BASE_DIR / "templates")


HTTP_REQUESTS = Counter(
    "boundarypass_http_requests_total",
    "HTTP requests handled by BoundaryPass",
    ["method", "route", "status"],
)
HTTP_REQUEST_DURATION = Histogram(
    "boundarypass_http_request_duration_seconds",
    "BoundaryPass HTTP request duration in seconds",
    ["method", "route"],
)


@app.middleware("http")
async def observe_requests(request: Request, call_next):
    started = perf_counter()
    status = "500"
    try:
        response = await call_next(request)
        status = str(response.status_code)
        return response
    finally:
        route = request.scope.get("route")
        route_name = getattr(route, "path", "unmatched")
        if route_name != "/metrics":
            HTTP_REQUESTS.labels(request.method, route_name, status).inc()
            HTTP_REQUEST_DURATION.labels(request.method, route_name).observe(
                perf_counter() - started
            )


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(
        content=generate_latest(),
        headers={"Content-Type": CONTENT_TYPE_LATEST},
    )


class BookingRequest(BaseModel):
    match_id: int
    customer_name: str = Field(min_length=2, max_length=100)
    customer_email: str = Field(min_length=5, max_length=254)
    quantity: int = Field(ge=1, le=6)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    with SessionLocal() as session:
        matches = session.scalars(select(Match).order_by(Match.id)).all()
        return templates.TemplateResponse(
            request=request,
            name="index.html",
            context={"matches": matches},
        )


@app.get("/api/matches")
def list_matches():
    with SessionLocal() as session:
        matches = session.scalars(select(Match).order_by(Match.id)).all()
        return [
            {
                "id": match.id,
                "teams": match.teams,
                "series": match.series,
                "date": match.match_date,
                "venue": match.venue,
                "price": match.price,
                "available_tickets": match.available_tickets,
            }
            for match in matches
        ]


@app.post("/api/bookings", status_code=201)
def create_booking(payload: BookingRequest):
    name = payload.customer_name.strip()
    email = payload.customer_email.strip().lower()

    if len(name) < 2 or "@" not in email or len(email) > 254:
        raise HTTPException(status_code=422, detail="Enter a valid name and email.")

    with SessionLocal.begin() as session:
        match = session.get(Match, payload.match_id)
        if match is None:
            raise HTTPException(status_code=404, detail="Match not found.")

        # The database updates stock only if enough tickets remain.
        # This also protects against two customers taking the last ticket.
        result = session.execute(
            update(Match)
            .where(
                Match.id == payload.match_id,
                Match.available_tickets >= payload.quantity,
            )
            .values(available_tickets=Match.available_tickets - payload.quantity)
        )
        if result.rowcount != 1:
            raise HTTPException(status_code=409, detail="Not enough tickets available.")

        booking = Booking(
            match_id=match.id,
            customer_name=name,
            customer_email=email,
            quantity=payload.quantity,
            total_price=match.price * payload.quantity,
        )
        session.add(booking)
        session.flush()

        return {
            "booking_id": booking.id,
            "match": match.teams,
            "quantity": booking.quantity,
            "total_price": booking.total_price,
            "message": "Booking confirmed",
        }
