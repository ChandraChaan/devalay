"""Management commands.

  python -m app.cli init-db            create tables (development; use Alembic in production)
  python -m app.cli seed [--no-books]  load bundled public-domain content
  python -m app.cli create-admin EMAIL [--role admin|editor]   (password read from stdin/prompt)
  python -m app.cli warm-rashifal      pre-compute today's Rashifal in both languages
"""

import argparse
import getpass
import sys

from sqlalchemy import select

from app.db import Base, SessionLocal, engine
from app.models import User
from app.security import hash_password


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="app.cli")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init-db")
    seed = sub.add_parser("seed")
    seed.add_argument("--no-books", action="store_true")
    admin = sub.add_parser("create-admin")
    admin.add_argument("email")
    admin.add_argument("--role", default="admin", choices=["admin", "editor"])
    sub.add_parser("warm-rashifal")
    args = parser.parse_args(argv)

    if args.cmd == "init-db":
        Base.metadata.create_all(engine)
        print("tables created")
    elif args.cmd == "seed":
        from app.seed.loader import load_all

        with SessionLocal() as db:
            print(load_all(db, include_books=not args.no_books))
    elif args.cmd == "create-admin":
        password = sys.stdin.readline().strip() if not sys.stdin.isatty() else getpass.getpass("Password: ")
        if len(password) < 12:
            sys.exit("Admin passwords must be at least 12 characters")
        with SessionLocal() as db:
            user = db.scalar(select(User).where(User.email == args.email.lower()))
            if user is None:
                user = User(email=args.email.lower(), display_name="Admin")
                db.add(user)
            user.password_hash = hash_password(password)
            user.role = args.role
            user.is_active = True
            db.commit()
            print(f"{args.role} ready: {user.email}")
    elif args.cmd == "warm-rashifal":
        from datetime import date

        from app.routers.astro import _rashifal_day

        with SessionLocal() as db:
            for lang in ("hi", "en"):
                print(lang, len(_rashifal_day(db, date.today(), lang)))


if __name__ == "__main__":
    main()
