import json
import re
from pathlib import Path

import requests


BASE_URL = "https://test-api.opensplendid.cn/juzi-service"
ACCESS_KEY = "drh20262026"
SKU_ID = "4"
SPEAKER_ID = "113"
OPERATOR = "yaqi_config_20260623"
HOMEWORK_DIR = Path(r"C:\workspace\homework_yaqi")
ROOT = Path(r"C:\workspace\ju-chat\specs\108-yaqi-piano-homework-config")
OUT = ROOT / "out"
CREATED_JSON = ROOT / "created-records.json"


def request_json(session, method, path, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["X-Config-Key"] = ACCESS_KEY
    separator = "&" if "?" in path else "?"
    url = f"{BASE_URL}{path}{separator}key={ACCESS_KEY}"
    response = session.request(method, url, headers=headers, timeout=180, **kwargs)
    if not response.ok:
        body = response.text[:2000]
        raise RuntimeError(f"{method} {path} HTTP {response.status_code}: {body}")
    data = response.json()
    if isinstance(data, dict) and data.get("status") not in (None, 0, 200):
        raise RuntimeError(f"{method} {path} failed: {data}")
    return data


def unwrap(data):
    if isinstance(data, dict) and "data" in data:
        return data["data"]
    return data


def current_config(session):
    return unwrap(request_json(session, "GET", f"/admin/homework-config/config?skuId={SKU_ID}"))


def ensure_no_existing_yaqi(session):
    data = current_config(session)
    routes = data.get("routes", []) if isinstance(data, dict) else []
    hits = []
    for route in routes:
        strategy = route.get("strategy") or {}
        name = strategy.get("name") or ""
        if name.startswith("yaqi-piano-") or "&&113" in str(route.get("matchValue", "")):
            hits.append({"routeId": route.get("id"), "name": name, "matchValue": route.get("matchValue")})
    if hits:
        raise RuntimeError(f"found existing yaqi routes/config, abort to avoid duplicates: {hits}")


def create_strategy(session, name):
    data = unwrap(
        request_json(
            session,
            "POST",
            "/admin/homework-config/strategies",
            data={"name": name, "skuId": SKU_ID, "operator": OPERATOR},
        )
    )
    print(f"strategy\t{name}\t{data['id']}")
    return data


def action_base(action_type, order, condition_value):
    files = [
        ("type", (None, action_type)),
        ("orderIndex", (None, str(order))),
        ("operator", (None, OPERATOR)),
    ]
    if condition_value:
        files.extend(
            [
                ("conditionKey", (None, "question")),
                ("conditionValue", (None, condition_value)),
            ]
        )
    return files


def add_text_action(session, strategy_id, order, text, condition_value=None):
    files = action_base("TEXT", order, condition_value)
    files.append(("textContent", (None, text)))
    data = unwrap(
        request_json(
            session,
            "POST",
            f"/admin/homework-config/strategies/{strategy_id}/actions",
            files=files,
        )
    )
    print(f"action\tTEXT\t{strategy_id}\t{order}\t{data['id']}")
    return data


def add_video_channel_action(session, strategy_id, order, code, condition_value=None):
    files = action_base("VIDEO_CHANNEL", order, condition_value)
    normalized_code = code.upper()
    files.append(("videoChannelCode", (None, normalized_code)))
    files.append(("textContent", (None, normalized_code)))
    data = unwrap(
        request_json(
            session,
            "POST",
            f"/admin/homework-config/strategies/{strategy_id}/actions",
            files=files,
        )
    )
    print(f"action\tVIDEO_CHANNEL\t{strategy_id}\t{order}\t{code}\t{data['id']}")
    return data


def add_file_action(session, strategy_id, action_type, order, file_path, condition_value=None):
    content_type = "audio/mpeg" if action_type == "VOICE" else "image/jpeg"
    if file_path.suffix.lower() == ".png":
        content_type = "image/png"
    files = action_base(action_type, order, condition_value)
    with file_path.open("rb") as fp:
        files.append(("file", (file_path.name, fp, content_type)))
        data = unwrap(
            request_json(
                session,
                "POST",
                f"/admin/homework-config/strategies/{strategy_id}/actions",
                files=files,
            )
        )
    print(f"action\t{action_type}\t{strategy_id}\t{order}\t{file_path.name}\t{data['id']}")
    return data


def bind_route(session, day, strategy_id):
    payload = {
        "day": day,
        "commentIndex": 1,
        "commentMatchType": "EQ",
        "strategyId": strategy_id,
        "matchKey": "currentDay&&homeworkDayRelation&&speakerId",
        "matchValue": f"{day}&&CURRENT&&{SPEAKER_ID}",
        "skuId": SKU_ID,
    }
    request_json(
        session,
        "POST",
        f"/admin/homework-config/routes?operator={OPERATOR}",
        json=payload,
    )
    print(f"route\tday{day}\tstrategy={strategy_id}")
    return payload


def parse_order_and_video(path: Path, day: int):
    match = re.match(rf"^D{day}_(\d+)(?:_(V\d+))?\.[^.]+$", path.name, flags=re.IGNORECASE)
    if not match:
        raise ValueError(f"invalid file name for day {day}: {path}")
    return int(match.group(1)), match.group(2)


def add_action_for_file(session, strategy_id, day, path, condition_value=None):
    order, video_code = parse_order_and_video(path, day)
    suffix = path.suffix.lower()
    if video_code:
        return add_video_channel_action(session, strategy_id, order, video_code, condition_value)
    if suffix == ".txt":
        text = path.read_text(encoding="utf-8-sig").strip()
        if not text:
            raise ValueError(f"empty text file is only allowed for video channel placeholders: {path}")
        return add_text_action(session, strategy_id, order, text, condition_value)
    if suffix == ".mp3":
        return add_file_action(session, strategy_id, "VOICE", order, path, condition_value)
    if suffix in (".png", ".jpg", ".jpeg"):
        return add_file_action(session, strategy_id, "IMAGE", order, path, condition_value)
    raise ValueError(f"unsupported file type: {path}")


def day_files(day_dir: Path, day: int):
    files = [p for p in day_dir.iterdir() if p.is_file()]
    return sorted(files, key=lambda p: parse_order_and_video(p, day)[0])


def create_day1(session, created):
    day = 1
    strategy = create_strategy(session, "yaqi-piano-day1-comment1")
    created["strategies"].append(strategy)
    day_dir = HOMEWORK_DIR / "D1"
    for question_dir in sorted([p for p in day_dir.iterdir() if p.is_dir()], key=lambda p: p.name):
        question = question_dir.name
        for file_path in day_files(question_dir, day):
            action = add_action_for_file(session, strategy["id"], day, file_path, question)
            created["actions"].append({"day": day, "question": question, "file": str(file_path), "action": action})
    created["routes"].append(bind_route(session, day, strategy["id"]))


def create_common_day(session, created, day):
    strategy = create_strategy(session, f"yaqi-piano-day{day}-comment1")
    created["strategies"].append(strategy)
    for file_path in day_files(HOMEWORK_DIR / f"D{day}", day):
        action = add_action_for_file(session, strategy["id"], day, file_path)
        created["actions"].append({"day": day, "question": None, "file": str(file_path), "action": action})
    created["routes"].append(bind_route(session, day, strategy["id"]))


def main():
    created = {
        "baseUrl": BASE_URL,
        "operator": OPERATOR,
        "skuId": SKU_ID,
        "speakerId": SPEAKER_ID,
        "strategies": [],
        "actions": [],
        "routes": [],
    }
    with requests.Session() as session:
        ensure_no_existing_yaqi(session)
        create_day1(session, created)
        for day in (2, 3, 4):
            create_common_day(session, created, day)
        config = current_config(session)
    CREATED_JSON.write_text(json.dumps(created, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "sku4-config-after-create.json").write_text(
        json.dumps(config, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"created json\t{CREATED_JSON}")


if __name__ == "__main__":
    main()
