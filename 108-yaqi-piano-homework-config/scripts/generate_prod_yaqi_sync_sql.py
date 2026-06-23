import json
from pathlib import Path


ROOT = Path(r"C:\workspace\ju-chat\specs\108-yaqi-piano-homework-config")
OUT = ROOT / "out"
SQL_DIR = ROOT / "sql"
CREATED_PATH = ROOT / "created-records.json"
PROD_ROUTE_PATH = OUT / "prod-before-yaqi-sync-route.json"
SYNC_SQL_PATH = SQL_DIR / "prod-sync-yaqi-piano-config.sql"
ROLLBACK_SQL_PATH = SQL_DIR / "rollback-prod-yaqi-piano-config.sql"
PREVIEW_PATH = OUT / "prod-yaqi-sync-preview.json"
OPERATOR = "yaqi_prod_sync_20260623"


def sql_string(value):
    if value is None:
        return "NULL"
    text = str(value)
    return "'" + text.replace("\\", "\\\\").replace("'", "''") + "'"


def sql_number(value):
    if value is None:
        return "NULL"
    return str(value)


def load_rows(path):
    return json.loads(path.read_text(encoding="utf-8"))["rows"]


def strategy_name(day):
    return f"yaqi-piano-day{day}-comment1"


def strategy_subquery(name):
    return (
        "SELECT id FROM drh_ai_config_homework_strategy "
        f"WHERE strategy_name = {sql_string(name)} AND enabled = 1 "
        "ORDER BY id DESC LIMIT 1"
    )


def build_action_insert(item):
    action = item["action"]
    name = strategy_name(item["day"])
    columns = [
        "strategy_id",
        "order_index",
        "action_type",
        "condition_key",
        "condition_value",
        "text_content",
        "material_url",
        "oss_url",
        "voice_duration_millis",
        "pdf_file_name",
        "pdf_file_size_bytes",
        "delay_millis",
        "enabled",
        "created_by",
        "updated_by",
        "created_at",
        "updated_at",
    ]
    values = [
        "s.id",
        sql_number(action.get("orderIndex")),
        sql_string(action.get("type")),
        sql_string(action.get("conditionKey") or ""),
        sql_string(action.get("conditionValue") or ""),
        sql_string(action.get("textContent") or action.get("videoChannelCode")),
        sql_string(action.get("materialUrl")),
        sql_string(action.get("ossUrl")),
        sql_number(action.get("voiceDurationMillis")),
        sql_string(action.get("pdfFileName")),
        sql_number(action.get("pdfFileSizeBytes")),
        sql_number(action.get("delayMillis")),
        "1",
        sql_string(OPERATOR),
        sql_string(OPERATOR),
        "NOW(6)",
        "NOW(6)",
    ]
    return (
        f"INSERT INTO drh_ai_config_homework_action ({', '.join(columns)})\n"
        f"SELECT {', '.join(values)}\n"
        f"FROM ({strategy_subquery(name)}) s;"
    )


def build_route_insert(route):
    name = strategy_name(route["day"])
    return (
        "INSERT INTO drh_ai_config_homework_route "
        "(day_num, comment_index, comment_match_type, match_key, match_value, sku_id, strategy_id, enabled, created_by, updated_by, created_at, updated_at)\n"
        f"SELECT {route['day']}, {route['commentIndex']}, {sql_string(route['commentMatchType'])}, "
        f"{sql_string(route['matchKey'])}, {sql_string(route['matchValue'])}, {sql_string(route['skuId'])}, "
        f"s.id, 1, {sql_string(OPERATOR)}, {sql_string(OPERATOR)}, NOW(6), NOW(6)\n"
        f"FROM ({strategy_subquery(name)}) s;"
    )


def main():
    created = json.loads(CREATED_PATH.read_text(encoding="utf-8"))
    prod_routes = load_rows(PROD_ROUTE_PATH)
    old_sku4_routes = [
        row for row in prod_routes
        if str(row.get("sku_id")) == "4" and int(row.get("enabled") or 0) == 1
    ]
    existing_yaqi_routes = [
        row for row in prod_routes
        if str(row.get("sku_id")) == "4" and "&&113" in str(row.get("match_value") or "")
    ]

    statements = [
        "-- Production incremental sync for Yaqi piano homework config.",
        "-- Scope: drh_ai_config_homework_strategy/action/route only.",
        "DELETE r\nFROM drh_ai_config_homework_route r\nJOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id\nWHERE s.strategy_name LIKE 'yaqi-piano-%';",
        "DELETE a\nFROM drh_ai_config_homework_action a\nJOIN drh_ai_config_homework_strategy s ON s.id = a.strategy_id\nWHERE s.strategy_name LIKE 'yaqi-piano-%';",
        "DELETE FROM drh_ai_config_homework_strategy\nWHERE strategy_name LIKE 'yaqi-piano-%';",
        (
            "UPDATE drh_ai_config_homework_route r\n"
            "JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id\n"
            "SET r.match_key = 'currentDay&&homeworkDayRelation&&speakerId',\n"
            "    r.match_value = CONCAT(\n"
            "      r.day_num,\n"
            "      '&&',\n"
            "      CASE\n"
            "        WHEN r.match_key = 'currentDay&&homeworkDayRelation&&speakerId' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(r.match_value, '&&', 2), '&&', -1)\n"
            "        WHEN r.match_key = 'homeworkDayRelation' THEN r.match_value\n"
            "        WHEN r.match_value LIKE '%&&%' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(r.match_value, '&&', 2), '&&', -1)\n"
            "        ELSE r.match_value\n"
            "      END,\n"
            "      '&&110'\n"
            "    ),\n"
            f"    r.updated_by = {sql_string(OPERATOR)},\n"
            "    r.updated_at = NOW(6)\n"
            "WHERE r.enabled = 1\n"
            "  AND r.sku_id = '4'\n"
            "  AND s.strategy_name NOT LIKE 'yaqi-piano-%';"
        ),
    ]

    for day in (1, 2, 3, 4):
        statements.append(
            "INSERT INTO drh_ai_config_homework_strategy "
            "(strategy_name, sku_id, enabled, remark, created_by, updated_by, created_at, updated_at)\n"
            f"VALUES ({sql_string(strategy_name(day))}, '4', 1, '', {sql_string(OPERATOR)}, {sql_string(OPERATOR)}, NOW(6), NOW(6));"
        )
    for action in created["actions"]:
        statements.append(build_action_insert(action))
    for route in created["routes"]:
        statements.append(build_route_insert(route))
    statements.append(
        "SELECT\n"
        "  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE strategy_name LIKE 'yaqi-piano-%' AND enabled = 1) AS yaqi_enabled_strategy,\n"
        "  (SELECT COUNT(*) FROM drh_ai_config_homework_action a JOIN drh_ai_config_homework_strategy s ON s.id = a.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%' AND a.enabled = 1) AS yaqi_enabled_action,\n"
        "  (SELECT COUNT(*) FROM drh_ai_config_homework_route r JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%' AND r.enabled = 1) AS yaqi_enabled_route;"
    )
    SYNC_SQL_PATH.write_text("\n\n".join(statements) + "\n", encoding="utf-8")

    rollback = [
        "-- Rollback for production Yaqi piano homework config sync.",
        "DELETE r\nFROM drh_ai_config_homework_route r\nJOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id\nWHERE s.strategy_name LIKE 'yaqi-piano-%';",
        "DELETE a\nFROM drh_ai_config_homework_action a\nJOIN drh_ai_config_homework_strategy s ON s.id = a.strategy_id\nWHERE s.strategy_name LIKE 'yaqi-piano-%';",
        "DELETE FROM drh_ai_config_homework_strategy\nWHERE strategy_name LIKE 'yaqi-piano-%';",
    ]
    for route in old_sku4_routes:
        rollback.append(
            "UPDATE drh_ai_config_homework_route\n"
            f"SET match_key = {sql_string(route.get('match_key') or '')},\n"
            f"    match_value = {sql_string(route.get('match_value') or '')},\n"
            f"    updated_by = {sql_string(OPERATOR + '_rollback')},\n"
            "    updated_at = NOW(6)\n"
            f"WHERE id = {route['id']};"
        )
    rollback.append(
        "SELECT\n"
        "  (SELECT COUNT(*) FROM drh_ai_config_homework_strategy WHERE strategy_name LIKE 'yaqi-piano-%') AS remaining_yaqi_strategy,\n"
        "  (SELECT COUNT(*) FROM drh_ai_config_homework_route r JOIN drh_ai_config_homework_strategy s ON s.id = r.strategy_id WHERE s.strategy_name LIKE 'yaqi-piano-%') AS remaining_yaqi_route;"
    )
    ROLLBACK_SQL_PATH.write_text("\n\n".join(rollback) + "\n", encoding="utf-8")

    preview = {
        "operator": OPERATOR,
        "prodOldSku4EnabledRoutes": len(old_sku4_routes),
        "prodExistingYaqiLikeRoutes": len(existing_yaqi_routes),
        "newStrategies": 4,
        "newActions": len(created["actions"]),
        "newRoutes": len(created["routes"]),
        "syncSql": str(SYNC_SQL_PATH),
        "rollbackSql": str(ROLLBACK_SQL_PATH),
    }
    PREVIEW_PATH.write_text(json.dumps(preview, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(preview, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
