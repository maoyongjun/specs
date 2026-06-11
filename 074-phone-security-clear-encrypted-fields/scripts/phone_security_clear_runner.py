#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
import time
from pathlib import Path
from typing import Any


SPEC_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = Path(__file__).resolve().parents[3]
DB_SKILL_SCRIPT_DIR = WORKSPACE_ROOT / "database-sql-skill" / "scripts"
DEFAULT_DDL = (
    WORKSPACE_ROOT
    / "specs"
    / "069-phone-security-backfill-governance"
    / "sql"
    / "final-phone-security-ddl-and-indexes.sql"
)
DEFAULT_MANIFEST = SPEC_DIR / "sql" / "phone-security-clear-targets.json"
DEFAULT_DML_TEMPLATE = SPEC_DIR / "sql" / "phone-security-clear-dml-template.sql"
DEFAULT_OUT_DIR = SPEC_DIR / "out"
EXPECTED_TABLES = 44
EXPECTED_GROUPS = 45
EXPECTED_COLUMNS = 135
LOCK_ERROR_CODES = {1205, 1213}
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")

sys.path.insert(0, str(DB_SKILL_SCRIPT_DIR))
import db_skill  # noqa: E402


class RunnerError(Exception):
    pass


def quote_ident(value: str) -> str:
    if not IDENT_RE.fullmatch(value):
        raise RunnerError(f"unsafe SQL identifier: {value!r}")
    return f"`{value}`"


def parse_targets_from_ddl(path: Path) -> list[dict[str, Any]]:
    sql = path.read_text(encoding="utf-8")
    targets: list[dict[str, Any]] = []

    for statement in db_skill.split_sql_statements(sql):
        match = re.match(r"\s*ALTER\s+TABLE\s+`?([A-Za-z_][A-Za-z0-9_]*)`?\s+(.*)\Z", statement, re.I | re.S)
        if not match:
            continue
        table, body = match.group(1), match.group(2)
        if "ADD COLUMN" not in body.upper():
            continue

        columns = [
            item
            for item in re.findall(
                r"(?:ADD\s+COLUMN\s+)?`?([A-Za-z_][A-Za-z0-9_]*)`?\s+(?:VARCHAR|CHAR)\s*\(",
                body,
                flags=re.I,
            )
            if item.endswith(("_mask", "_md5", "_aes"))
        ]
        if not columns:
            continue

        prefixes: dict[str, dict[str, str]] = {}
        order: list[str] = []
        for column in columns:
            for suffix, kind in (("_mask", "mask"), ("_md5", "md5"), ("_aes", "aes")):
                if column.endswith(suffix):
                    prefix = column[: -len(suffix)]
                    if prefix not in prefixes:
                        prefixes[prefix] = {}
                        order.append(prefix)
                    prefixes[prefix][kind] = column
                    break

        for prefix in order:
            grouped = prefixes[prefix]
            missing = {"mask", "md5", "aes"} - set(grouped)
            if missing:
                raise RunnerError(f"{table}.{prefix} missing columns: {sorted(missing)}")
            targets.append(
                {
                    "table": table,
                    "pk": "id",
                    "field_prefix": prefix,
                    "columns": {
                        "mask": grouped["mask"],
                        "md5": grouped["md5"],
                        "aes": grouped["aes"],
                    },
                }
            )

    return targets


def validate_targets(targets: list[dict[str, Any]]) -> None:
    tables = {target["table"] for target in targets}
    columns = [column for target in targets for column in target["columns"].values()]
    if len(tables) != EXPECTED_TABLES:
        raise RunnerError(f"expected {EXPECTED_TABLES} tables, got {len(tables)}")
    if len(targets) != EXPECTED_GROUPS:
        raise RunnerError(f"expected {EXPECTED_GROUPS} field groups, got {len(targets)}")
    if len(columns) != EXPECTED_COLUMNS:
        raise RunnerError(f"expected {EXPECTED_COLUMNS} columns, got {len(columns)}")

    seen: set[tuple[str, str]] = set()
    for target in targets:
        table = target.get("table", "")
        pk = target.get("pk", "")
        prefix = target.get("field_prefix", "")
        if not all(IDENT_RE.fullmatch(value) for value in (table, pk, prefix)):
            raise RunnerError(f"invalid target identifiers: {target}")
        key = (table, prefix)
        if key in seen:
            raise RunnerError(f"duplicate target group: {table}.{prefix}")
        seen.add(key)
        columns_map = target.get("columns") or {}
        if set(columns_map) != {"mask", "md5", "aes"}:
            raise RunnerError(f"invalid column keys for {table}.{prefix}: {columns_map}")
        for column in columns_map.values():
            if not IDENT_RE.fullmatch(column):
                raise RunnerError(f"invalid target column: {table}.{column}")


def manifest_payload(targets: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "source_ddl": "specs/069-phone-security-backfill-governance/sql/final-phone-security-ddl-and-indexes.sql",
        "expected": {
            "tables": EXPECTED_TABLES,
            "field_groups": EXPECTED_GROUPS,
            "columns": EXPECTED_COLUMNS,
        },
        "targets": targets,
    }


def load_manifest(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    targets = payload.get("targets")
    if not isinstance(targets, list):
        raise RunnerError(f"manifest has no targets list: {path}")
    validate_targets(targets)
    return targets


def compare_manifest_to_ddl(manifest_path: Path, ddl_path: Path) -> list[dict[str, Any]]:
    generated = parse_targets_from_ddl(ddl_path)
    validate_targets(generated)
    manifest = load_manifest(manifest_path)
    if manifest != generated:
        raise RunnerError("manifest does not match targets generated from source DDL")
    return manifest


def target_condition(target: dict[str, Any]) -> str:
    md5_col = quote_ident(target["columns"]["md5"])
    return f"{md5_col} IS NOT NULL AND {md5_col} <> ''"


def target_set_null(target: dict[str, Any]) -> str:
    cols = target["columns"]
    return ", ".join(f"{quote_ident(cols[name])} = NULL" for name in ("mask", "md5", "aes"))


def render_dml_template(targets: list[dict[str, Any]], batch_size: int) -> str:
    lines = [
        "-- DML template for database-sql-skill analyze only.",
        "-- Do not run this file directly for production cleanup.",
        f"-- Batch size represented in template: {batch_size}",
        "",
    ]
    for target in targets:
        table = quote_ident(target["table"])
        pk = quote_ident(target["pk"])
        condition = target_condition(target)
        lines.extend(
            [
                f"-- {target['table']}.{target['field_prefix']}",
                f"-- Candidate condition: {target['columns']['md5']} is not null and not empty.",
                f"UPDATE {table}",
                f"SET {target_set_null(target)}",
                f"WHERE {pk} IN (",
                f"  SELECT {pk} FROM (",
                f"    SELECT {pk} FROM {table}",
                f"    WHERE {condition}",
                f"    ORDER BY {pk}",
                f"    LIMIT {int(batch_size)}",
                "  ) AS batch_ids",
                ");",
                "",
            ]
        )
    return "\n".join(lines)


def write_artifacts(args: argparse.Namespace) -> None:
    targets = parse_targets_from_ddl(args.source_ddl)
    validate_targets(targets)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.dml_template.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest_payload(targets), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.dml_template.write_text(render_dml_template(targets, args.batch_size), encoding="utf-8")
    print(f"Wrote manifest: {args.manifest}")
    print(f"Wrote DML template: {args.dml_template}")


def ensure_profile(profile_name: str, config_path: Path) -> dict[str, Any]:
    config, _ = db_skill.load_config(config_path)
    profile = db_skill.get_profile(config, profile_name)
    if profile.get("environment") != "prod":
        raise RunnerError(f"profile {profile_name} must have environment=prod")
    if profile.get("database", {}).get("type") != "mysql":
        raise RunnerError(f"profile {profile_name} must be mysql")
    if not db_skill.policy_value(profile, "allow_write", False):
        raise RunnerError(f"profile {profile_name} policy.allow_write must be true")
    return profile


def validate_execute_confirmation(confirm: str | None, profile: str, batch_size: int) -> None:
    if not confirm:
        raise RunnerError("--execute requires --confirm")
    checks = {
        "date": re.search(r"\b20\d{2}-\d{2}-\d{2}\b", confirm) is not None,
        "profile": profile in confirm,
        "batch_size": str(batch_size) in confirm,
        "backup": re.search(r"backup|备份|PITR", confirm, re.I) is not None,
        "writers_paused": re.search(r"paused|pause|暂停|停写|writers", confirm, re.I) is not None,
    }
    missing = [name for name, ok in checks.items() if not ok]
    if missing:
        raise RunnerError(f"--confirm missing required content: {', '.join(missing)}")


def report_path(out_dir: Path, mode: str) -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return out_dir / f"phone-security-clear-{mode}-{stamp}.json"


def write_report(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")


def count_candidates(cursor: Any, target: dict[str, Any]) -> int:
    sql = f"SELECT COUNT(1) FROM {quote_ident(target['table'])} WHERE {target_condition(target)}"
    cursor.execute(sql)
    return int(cursor.fetchone()[0])


def metadata_preflight(cursor: Any, targets: list[dict[str, Any]]) -> dict[str, Any]:
    table_names = sorted({target["table"] for target in targets})
    placeholders = ",".join(["%s"] * len(table_names))
    cursor.execute(
        f"""
        SELECT table_name, column_name, ordinal_position
        FROM information_schema.key_column_usage
        WHERE table_schema = DATABASE()
          AND constraint_name = 'PRIMARY'
          AND table_name IN ({placeholders})
        ORDER BY table_name, ordinal_position
        """,
        table_names,
    )
    pk_by_table: dict[str, list[str]] = {}
    for table, column, _ in cursor.fetchall():
        pk_by_table.setdefault(table, []).append(column)

    cursor.execute(
        f"""
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name IN ({placeholders})
        """,
        table_names,
    )
    columns_by_table: dict[str, set[str]] = {}
    for table, column in cursor.fetchall():
        columns_by_table.setdefault(table, set()).add(column)

    missing: list[str] = []
    for target in targets:
        table = target["table"]
        if pk_by_table.get(table) != [target["pk"]]:
            missing.append(f"{table} primary key is {pk_by_table.get(table)}, expected [{target['pk']}]")
        for column in target["columns"].values():
            if column not in columns_by_table.get(table, set()):
                missing.append(f"{table}.{column} missing")
    if missing:
        raise RunnerError("metadata preflight failed: " + "; ".join(missing))
    return {
        "tables_checked": len(table_names),
        "field_groups_checked": len(targets),
        "columns_checked": sum(len(target["columns"]) for target in targets),
    }


def is_lock_error(exc: Exception) -> bool:
    if not getattr(exc, "args", None):
        return False
    code = exc.args[0]
    return isinstance(code, int) and code in LOCK_ERROR_CODES


def execute_with_retry(connection: Any, cursor: Any, sql: str, params: list[Any], retries: int) -> int:
    attempt = 0
    while True:
        try:
            cursor.execute(sql, params)
            affected = int(getattr(cursor, "rowcount", 0) or 0)
            connection.commit()
            return affected
        except Exception as exc:
            connection.rollback()
            attempt += 1
            if attempt > retries or not is_lock_error(exc):
                raise
            time.sleep(min(2 * attempt, 10))


def select_batch_ids(cursor: Any, target: dict[str, Any], last_id: int, batch_size: int) -> list[int]:
    pk = quote_ident(target["pk"])
    sql = (
        f"SELECT {pk} FROM {quote_ident(target['table'])} FORCE INDEX (`PRIMARY`) "
        f"WHERE {pk} > %s AND ({target_condition(target)}) "
        f"ORDER BY {pk} LIMIT %s"
    )
    cursor.execute(sql, [last_id, batch_size])
    return [int(row[0]) for row in cursor.fetchall()]


def execute_target(
    connection: Any,
    cursor: Any,
    target: dict[str, Any],
    batch_size: int,
    sleep_ms: int,
    retries: int,
    max_passes: int,
) -> dict[str, Any]:
    before = count_candidates(cursor, target)
    total_updated = 0
    total_batches = 0

    for pass_no in range(1, max_passes + 1):
        last_id = 0
        pass_updated = 0
        while True:
            ids = select_batch_ids(cursor, target, last_id, batch_size)
            if not ids:
                break
            placeholders = ",".join(["%s"] * len(ids))
            pk = quote_ident(target["pk"])
            update_sql = (
                f"UPDATE {quote_ident(target['table'])} "
                f"SET {target_set_null(target)} "
                f"WHERE {pk} IN ({placeholders}) AND ({target_condition(target)})"
            )
            updated = execute_with_retry(connection, cursor, update_sql, ids, retries)
            total_updated += updated
            pass_updated += updated
            total_batches += 1
            last_id = ids[-1]
            if sleep_ms > 0:
                time.sleep(sleep_ms / 1000)

        remaining = count_candidates(cursor, target)
        if remaining == 0 or pass_updated == 0:
            break

    after = count_candidates(cursor, target)
    return {
        "table": target["table"],
        "field_prefix": target["field_prefix"],
        "candidate_rows_before": before,
        "updated_rows": total_updated,
        "batches": total_batches,
        "candidate_rows_after": after,
    }


def run_count_mode(args: argparse.Namespace, mode: str, targets: list[dict[str, Any]]) -> dict[str, Any]:
    profile = ensure_profile(args.profile, args.config)
    tunnel = connection = cursor = None
    try:
        tunnel, connection = db_skill.open_profile_connection(profile)
        cursor = connection.cursor()
        cursor.execute("SET SESSION innodb_lock_wait_timeout = 5")
        metadata = metadata_preflight(cursor, targets)
        rows = []
        for target in targets:
            rows.append(
                {
                    "table": target["table"],
                    "field_prefix": target["field_prefix"],
                    "candidate_rows": count_candidates(cursor, target),
                }
            )
        return {
            "mode": mode,
            "profile": args.profile,
            "batch_size": args.batch_size,
            "sleep_ms": args.sleep_ms,
            "metadata_preflight": metadata,
            "total_candidate_rows": sum(row["candidate_rows"] for row in rows),
            "targets": rows,
        }
    finally:
        db_skill.close_quietly(cursor)
        db_skill.close_quietly(connection)
        db_skill.close_quietly(tunnel)


def run_execute(args: argparse.Namespace, targets: list[dict[str, Any]]) -> dict[str, Any]:
    validate_execute_confirmation(args.confirm, args.profile, args.batch_size)
    profile = ensure_profile(args.profile, args.config)
    tunnel = connection = cursor = None
    results: list[dict[str, Any]] = []
    try:
        tunnel, connection = db_skill.open_profile_connection(profile)
        cursor = connection.cursor()
        cursor.execute("SET SESSION innodb_lock_wait_timeout = 5")
        metadata = metadata_preflight(cursor, targets)
        for target in targets:
            result = execute_target(
                connection,
                cursor,
                target,
                args.batch_size,
                args.sleep_ms,
                args.retries,
                args.max_passes,
            )
            results.append(result)
        return {
            "mode": "execute",
            "profile": args.profile,
            "batch_size": args.batch_size,
            "sleep_ms": args.sleep_ms,
            "retries": args.retries,
            "max_passes": args.max_passes,
            "metadata_preflight": metadata,
            "total_candidate_rows_before": sum(row["candidate_rows_before"] for row in results),
            "total_updated_rows": sum(row["updated_rows"] for row in results),
            "total_candidate_rows_after": sum(row["candidate_rows_after"] for row in results),
            "targets": results,
        }
    finally:
        db_skill.close_quietly(cursor)
        db_skill.close_quietly(connection)
        db_skill.close_quietly(tunnel)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clear production phone security fields in small batches")
    parser.add_argument("--config", type=Path, default=Path(db_skill.default_config_path()), help="database-sql-skill config")
    parser.add_argument("--profile", default="prod-mysql", help="database-sql-skill profile")
    parser.add_argument("--source-ddl", type=Path, default=DEFAULT_DDL, help="069 final DDL path")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="target manifest path")
    parser.add_argument("--dml-template", type=Path, default=DEFAULT_DML_TEMPLATE, help="DML template path")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR, help="report output directory")
    parser.add_argument("--batch-size", type=int, default=500, help="max rows per update batch")
    parser.add_argument("--sleep-ms", type=int, default=200, help="sleep after each committed batch")
    parser.add_argument("--retries", type=int, default=3, help="lock wait/deadlock retry count")
    parser.add_argument("--max-passes", type=int, default=3, help="max passes per target group")
    parser.add_argument("--confirm", help="required confirmation text for --execute")

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write-artifacts", action="store_true", help="generate manifest and DML template")
    mode.add_argument("--validate-artifacts", action="store_true", help="validate manifest against source DDL")
    mode.add_argument("--dry-run", action="store_true", help="count candidate rows only")
    mode.add_argument("--verify", action="store_true", help="count remaining candidate rows after execute")
    mode.add_argument("--execute", action="store_true", help="perform production updates")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.batch_size < 1:
        raise RunnerError("--batch-size must be positive")
    if args.sleep_ms < 0:
        raise RunnerError("--sleep-ms must be >= 0")

    if args.write_artifacts:
        write_artifacts(args)
        return 0

    targets = compare_manifest_to_ddl(args.manifest, args.source_ddl)
    if args.validate_artifacts:
        print(
            "OK: manifest matches source DDL "
            f"({EXPECTED_TABLES} tables, {EXPECTED_GROUPS} field groups, {EXPECTED_COLUMNS} columns)"
        )
        return 0

    mode = "execute" if args.execute else "verify" if args.verify else "dry-run"
    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    output = report_path(args.out_dir, mode)
    report: dict[str, Any] = {"mode": mode, "started_at": started_at, "status": "running"}
    try:
        if args.execute:
            payload = run_execute(args, targets)
        else:
            payload = run_count_mode(args, mode, targets)
        report.update(payload)
        report["status"] = "success"
        report["ended_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_report(output, report)
        print(f"Wrote report: {output}")
        if mode == "execute":
            print(
                "Summary: "
                f"before={report['total_candidate_rows_before']} "
                f"updated={report['total_updated_rows']} "
                f"after={report['total_candidate_rows_after']}"
            )
        else:
            print(f"Summary: candidates={report['total_candidate_rows']}")
        return 0
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        report["ended_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_report(output, report)
        print(f"Wrote failed report: {output}", file=sys.stderr)
        raise


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RunnerError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
