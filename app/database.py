import os
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, create_engine, event, select
from sqlalchemy.engine import URL
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, sessionmaker

# Keep SQLite for local development and the existing password URL as a fallback.
# IAM mode uses the EKS Pod Identity credentials supplied to the container.
DATABASE_AUTH_MODE = os.getenv("DATABASE_AUTH_MODE", "url")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./boundarypass.db")

if DATABASE_AUTH_MODE == "iam":
    import boto3

    DB_HOST = os.environ["DATABASE_HOST"]
    DB_PORT = int(os.getenv("DATABASE_PORT", "5432"))
    DB_USER = os.getenv("DATABASE_USER", "boundarypass_app")
    DB_NAME = os.getenv("DATABASE_NAME", "boundarypass")
    AWS_REGION = os.environ["AWS_REGION"]

    # URL.create keeps credentials out of the URL and logs.
    database_url = URL.create(
        "postgresql+psycopg",
        username=DB_USER,
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
    )
    engine = create_engine(
        database_url,
        pool_pre_ping=True,
        # Verify the RDS certificate and the hostname used to sign the IAM token.
        connect_args={
            "sslmode": "verify-full",
            "sslrootcert": "/app/rds-global-bundle.pem",
            # Bound connection attempts and detect broken TCP connections.
            "connect_timeout": 10,
            "keepalives": 1,
            "keepalives_idle": 10,
            "keepalives_interval": 5,
            "keepalives_count": 3,
            "tcp_user_timeout": 20000,
        },
    )
    rds = boto3.client("rds", region_name=AWS_REGION)

    @event.listens_for(engine, "do_connect")
    def add_iam_token(dialect, connection_record, args, params):
        # Generate a new token for each new physical database connection.
        # Existing pooled connections do not need a new login token.
        params["password"] = rds.generate_db_auth_token(
            DBHostname=DB_HOST,
            Port=DB_PORT,
            DBUsername=DB_USER,
            Region=AWS_REGION,
        )
elif DATABASE_AUTH_MODE == "url":
    connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
    engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=connect_args)
else:
    raise ValueError(f"Unsupported DATABASE_AUTH_MODE: {DATABASE_AUTH_MODE}")

SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class Match(Base):
    __tablename__ = "matches"

    id: Mapped[int] = mapped_column(primary_key=True)
    teams: Mapped[str] = mapped_column(String(120))
    series: Mapped[str] = mapped_column(String(80))
    match_date: Mapped[str] = mapped_column(String(40))
    venue: Mapped[str] = mapped_column(String(150))
    price: Mapped[int] = mapped_column(Integer)
    available_tickets: Mapped[int] = mapped_column(Integer)
    bookings: Mapped[list["Booking"]] = relationship(back_populates="match")


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(primary_key=True)
    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id"))
    customer_name: Mapped[str] = mapped_column(String(100))
    customer_email: Mapped[str] = mapped_column(String(254))
    quantity: Mapped[int] = mapped_column(Integer)
    total_price: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    match: Mapped[Match] = relationship(back_populates="bookings")


def initialize_database() -> None:
    if DATABASE_AUTH_MODE == "iam":
        # The dedicated IAM user reads existing tables; schema setup stays
        # with the database administrator.
        with SessionLocal() as session:
            session.scalar(select(Match.id).limit(1))
        return

    Base.metadata.create_all(bind=engine)

    with SessionLocal.begin() as session:
        if session.scalar(select(Match.id).limit(1)) is not None:
            return

        session.add_all(
            [
                Match(
                    teams="India vs Australia",
                    series="International Cricket",
                    match_date="18 November",
                    venue="Wankhede Stadium, Mumbai",
                    price=1499,
                    available_tickets=100,
                ),
                Match(
                    teams="CSK vs MI",
                    series="IPL",
                    match_date="22 November",
                    venue="M. A. Chidambaram Stadium, Chennai",
                    price=999,
                    available_tickets=100,
                ),
                Match(
                    teams="RCB vs KKR",
                    series="IPL",
                    match_date="26 November",
                    venue="M. Chinnaswamy Stadium, Bengaluru",
                    price=1199,
                    available_tickets=100,
                ),
            ]
        )
