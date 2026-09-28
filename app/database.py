import os
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./boundarypass.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=connect_args)
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
