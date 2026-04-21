"""First-run setup for SP Gas Billing on Windows.

Invoked by installer.iss via first_run_setup.bat. Idempotent:
  - initdb only if pgdata is empty
  - creates the application database if missing
  - runs alembic upgrade head (no-op if already at head)
  - runs scripts.seed (idempotent on its own)
  - leaves Postgres stopped so the NSSM service can take over

Args:
  sys.argv[1] = install root    (e.g. C:\\Program Files\\SP Gas Billing)
  sys.argv[2] = data root       (e.g. C:\\ProgramData\\SP Gas Billing)
"""

from __future__ import annotations

import os
import secrets
import shutil
import string
import subprocess
import sys
import time
from pathlib import Path

PG_PORT = 54329
PG_USER = "postgres"
PG_DB = "spgasbill"


def log(msg: str, log_path: Path) -> None:
    line = f"[first_run] {msg}"
    print(line)
    try:
        with log_path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def rand_token(n: int) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def run(cmd: list[str], env: dict | None = None, cwd: Path | None = None,
        log_path: Path | None = None) -> int:
    if log_path:
        log(f"exec: {' '.join(cmd)}", log_path)
    result = subprocess.run(
        cmd, env=env, cwd=str(cwd) if cwd else None,
        capture_output=True, text=True,
    )
    if log_path:
        if result.stdout:
            with log_path.open("a", encoding="utf-8") as f:
                f.write(result.stdout + "\n")
        if result.stderr:
            with log_path.open("a", encoding="utf-8") as f:
                f.write(result.stderr + "\n")
    return result.returncode


def read_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def write_env_file(path: Path, kv: dict[str, str]) -> None:
    path.write_text(
        "\n".join(f"{k}={v}" for k, v in kv.items()) + "\n",
        encoding="utf-8",
    )


def extract_pg_password(database_url: str) -> str:
    # postgresql+psycopg://postgres:PASSWORD@localhost:54329/spgasbill
    try:
        after_scheme = database_url.split("://", 1)[1]
        userpass = after_scheme.split("@", 1)[0]
        return userpass.split(":", 1)[1]
    except (IndexError, ValueError):
        return ""


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: first_run_setup.py <install_dir> <data_dir>", file=sys.stderr)
        return 2

    install_dir = Path(sys.argv[1])
    data_dir = Path(sys.argv[2])

    pgdata = data_dir / "pgdata"
    logs = data_dir / "logs"
    env_file = data_dir / "backend.env"

    pg_bin = install_dir / "pgsql" / "bin"
    py_exe = install_dir / "python" / "python.exe"
    backend = install_dir / "backend"

    logs.mkdir(parents=True, exist_ok=True)
    log_path = logs / "install.log"

    log(f"install_dir = {install_dir}", log_path)
    log(f"data_dir    = {data_dir}", log_path)

    # ---- 1. initdb (only if pgdata is empty) --------------------------------
    fresh_cluster = not (pgdata / "PG_VERSION").exists()
    if fresh_cluster:
        log("Running initdb...", log_path)
        pgdata.mkdir(parents=True, exist_ok=True)

        pg_pass = rand_token(24)
        pwfile = data_dir / ".pwfile"
        pwfile.write_text(pg_pass, encoding="utf-8")
        try:
            rc = run(
                [str(pg_bin / "initdb.exe"),
                 "-D", str(pgdata),
                 "-U", PG_USER,
                 "--pwfile", str(pwfile),
                 "-E", "UTF8",
                 "--locale=C"],
                log_path=log_path,
            )
        finally:
            pwfile.unlink(missing_ok=True)

        if rc != 0:
            log(f"ERROR: initdb failed rc={rc}", log_path)
            return rc

        # Lock the cluster to localhost + fixed port.
        (pgdata / "postgresql.auto.conf").write_text(
            "listen_addresses = 'localhost'\n"
            f"port = {PG_PORT}\n"
            "logging_collector = on\n"
            "log_directory = 'log'\n"
            "log_filename = 'postgres-%Y-%m-%d.log'\n"
            "log_rotation_age = 1d\n",
            encoding="utf-8",
        )

        # Persist env: app reads this on every backend start.
        write_env_file(env_file, {
            "DATABASE_URL": f"postgresql+psycopg://{PG_USER}:{pg_pass}@localhost:{PG_PORT}/{PG_DB}",
            "SECRET_KEY": rand_token(48),
            "DEBUG": "False",
            "CORS_ORIGINS": "*",
        })
    else:
        log("pgdata already initialized, skipping initdb", log_path)
        if not env_file.exists():
            log("ERROR: pgdata exists but backend.env is missing — cannot recover password", log_path)
            return 1

    env_map = read_env_file(env_file)
    pg_pass = extract_pg_password(env_map.get("DATABASE_URL", ""))
    if not pg_pass:
        log("ERROR: could not extract PG password from DATABASE_URL", log_path)
        return 1

    # ---- 2. Start Postgres in foreground for one-time setup -----------------
    log("Starting Postgres (bootstrap)...", log_path)
    rc = run(
        [str(pg_bin / "pg_ctl.exe"),
         "-D", str(pgdata),
         "-l", str(logs / "pg-bootstrap.log"),
         "-w", "start"],
        log_path=log_path,
    )
    if rc != 0:
        log(f"ERROR: pg_ctl start failed rc={rc}", log_path)
        return rc

    psql_env = os.environ.copy()
    psql_env["PGPASSWORD"] = pg_pass

    try:
        # ---- 3. Create DB if missing ----------------------------------------
        check = subprocess.run(
            [str(pg_bin / "psql.exe"),
             "-h", "localhost",
             "-p", str(PG_PORT),
             "-U", PG_USER,
             "-d", "postgres",
             "-tAc", f"SELECT 1 FROM pg_database WHERE datname='{PG_DB}'"],
            env=psql_env, capture_output=True, text=True,
        )
        if check.returncode != 0:
            log(f"psql check failed: {check.stderr}", log_path)
            return check.returncode

        if check.stdout.strip() != "1":
            log(f"Creating database {PG_DB}...", log_path)
            rc = run(
                [str(pg_bin / "psql.exe"),
                 "-h", "localhost",
                 "-p", str(PG_PORT),
                 "-U", PG_USER,
                 "-d", "postgres",
                 "-c", f"CREATE DATABASE {PG_DB} ENCODING 'UTF8' TEMPLATE template0"],
                env=psql_env, log_path=log_path,
            )
            if rc != 0:
                return rc

        # ---- 4. Copy env into backend dir (alembic + uvicorn auto-load .env)-
        shutil.copyfile(env_file, backend / ".env")

        # ---- 5. Migrate -----------------------------------------------------
        log("Running alembic upgrade head...", log_path)
        alembic_env = os.environ.copy()
        # Ensure embedded-python site-packages are on sys.path when launching via `-m alembic`
        alembic_env["PYTHONPATH"] = str(backend)
        rc = run(
            [str(py_exe), "-m", "alembic", "upgrade", "head"],
            env=alembic_env, cwd=backend, log_path=log_path,
        )
        if rc != 0:
            log(f"ERROR: alembic rc={rc}", log_path)
            return rc

        # ---- 6. Seed (idempotent) ------------------------------------------
        log("Seeding admin + catalog...", log_path)
        run(
            [str(py_exe), "-m", "scripts.seed"],
            env=alembic_env, cwd=backend, log_path=log_path,
        )
    finally:
        # ---- 7. Stop Postgres so NSSM service can take over -----------------
        log("Stopping bootstrap Postgres...", log_path)
        run(
            [str(pg_bin / "pg_ctl.exe"), "-D", str(pgdata), "-w", "stop"],
            log_path=log_path,
        )
        time.sleep(1)

    log("Done.", log_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
