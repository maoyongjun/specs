# -*- coding: utf-8 -*-
"""Replace Day1-Day5 first-comment voice actions with split MP3 files."""

import json
from pathlib import Path

import requests


BASE_URL = "http://localhost:9011"
ACCESS_KEY = "drh20262026"
SKU_ID = "5"
OPERATOR = "liuyuan_config_20260601_split_voice"
HOMEWORK_DIR = Path(r"C:\workspace\homework_file")
OUTPUT_JSON = Path(
    r"C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal\split-voice-update-records.json"
)


def request_json(session, method, path, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["X-Config-Key"] = ACCESS_KEY
    response = session.request(method, BASE_URL + path, headers=headers, timeout=120, **kwargs)
    response.raise_for_status()
    if not response.text:
        return None
    data = response.json()
    if isinstance(data, dict) and data.get("status") not in (None, 0, 200):
        raise RuntimeError(f"{method} {path} failed: {data}")
    return data


def unwrap(data):
    if isinstance(data, dict) and "data" in data:
        return data["data"]
    return data


def split_voice_files(day):
    files = sorted(HOMEWORK_DIR.glob(f"{day}-*.MP3"))
    if not files:
        files = sorted(HOMEWORK_DIR.glob(f"{day}-*.mp3"))
    if not files:
        raise FileNotFoundError(f"missing split voice files for day {day}")
    for file_path in files:
        if file_path.stat().st_size <= 0:
            raise ValueError(f"empty split voice file: {file_path}")
    return files


def load_comment1_strategies(session):
    config = unwrap(request_json(session, "GET", f"/admin/homework-config/config?skuId={SKU_ID}"))
    result = {}
    for route in config.get("routes") or []:
        strategy = route.get("strategy") or {}
        name = strategy.get("name") or ""
        for day in range(1, 6):
            if name == f"liuyuan-vocal-day{day}-comment1":
                result[day] = strategy
    missing = [day for day in range(1, 6) if day not in result]
    if missing:
        raise RuntimeError(f"missing comment1 strategies for days: {missing}")
    return result


def delete_action(session, strategy_id, action_id):
    request_json(
        session,
        "DELETE",
        f"/admin/homework-config/strategies/{strategy_id}/actions/{action_id}?operator={OPERATOR}",
    )


def add_voice_action(session, strategy_id, order_index, file_path):
    with file_path.open("rb") as fp:
        files = [
            ("type", (None, "VOICE")),
            ("orderIndex", (None, str(order_index))),
            ("operator", (None, OPERATOR)),
            ("file", (file_path.name, fp, "audio/mpeg")),
        ]
        data = unwrap(
            request_json(
                session,
                "POST",
                f"/admin/homework-config/strategies/{strategy_id}/actions",
                files=files,
            )
        )
    return data


def main():
    records = {"operator": OPERATOR, "deletedVoiceActions": [], "addedVoiceActions": []}
    with requests.Session() as session:
        strategies = load_comment1_strategies(session)
        for day in range(1, 6):
            strategy = strategies[day]
            strategy_id = strategy["id"]
            active_voice_actions = [
                action for action in strategy.get("actions") or []
                if action.get("type") == "VOICE"
            ]
            for action in active_voice_actions:
                delete_action(session, strategy_id, action["id"])
                record = {
                    "day": day,
                    "strategyId": strategy_id,
                    "actionId": action["id"],
                    "orderIndex": action.get("orderIndex"),
                    "materialUrl": action.get("materialUrl"),
                    "ossUrl": action.get("ossUrl"),
                }
                records["deletedVoiceActions"].append(record)
                print(f"deleted\tday{day}\tstrategy={strategy_id}\taction={action['id']}")

            for offset, file_path in enumerate(split_voice_files(day), start=2):
                action = add_voice_action(session, strategy_id, offset, file_path)
                record = {
                    "day": day,
                    "strategyId": strategy_id,
                    "file": str(file_path),
                    "action": action,
                }
                records["addedVoiceActions"].append(record)
                print(f"added\tday{day}\torder={offset}\taction={action['id']}\tfile={file_path.name}")

    OUTPUT_JSON.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"record\t{OUTPUT_JSON}")


if __name__ == "__main__":
    main()
