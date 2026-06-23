import json
from pathlib import Path


ROOT = Path(r"C:\workspace\ju-chat\specs\108-yaqi-piano-homework-config")
OUT = ROOT / "out"
CONFIG_PATH = OUT / "sku4-config-after-create.json"
SUMMARY_PATH = ROOT / "verification-summary.json"

EXPECTED = {
    1: {
        "节奏有问题": ["VOICE", "VIDEO_CHANNEL", "TEXT", "VOICE", "TEXT", "VOICE"],
        "翘指": ["VOICE", "VIDEO_CHANNEL", "VOICE", "VOICE", "VOICE"],
        "折指": ["VOICE", "VIDEO_CHANNEL", "VOICE", "VOICE", "VOICE"],
    },
    2: [("VOICE", ""), ("IMAGE", ""), ("TEXT", ""), ("VOICE", ""), ("VOICE", "")],
    3: [("VOICE", ""), ("IMAGE", ""), ("VOICE", ""), ("IMAGE", ""), ("VOICE", "")],
    4: [("VOICE", ""), ("VOICE", "")],
}


def load_config():
    data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return data.get("routes") or []


def conditions(expr_key, expr_value):
    key = (expr_key or "").strip()
    value = (expr_value or "").strip()
    if not key:
        return []
    keys = [item.strip() for item in key.split("&&")]
    values = [item.strip() for item in value.split("&&")]
    if len(keys) != len(values):
        raise AssertionError(f"invalid condition expression: {key} / {value}")
    return list(zip(keys, values))


def match_route(route, day, speaker_id, relation="CURRENT", comment_index=1):
    if int(route.get("day") or 0) != day:
        return False
    if str(route.get("skuId")) != "4":
        return False
    route_index = int(route.get("commentIndex") or 0)
    route_type = (route.get("commentMatchType") or "EQ").upper()
    if route_type == "GTE":
        if comment_index < route_index:
            return False
    elif comment_index != route_index:
        return False
    params = {
        "currentDay": str(day),
        "homeworkDayRelation": relation,
        "speakerId": str(speaker_id),
    }
    route_conditions = conditions(route.get("matchKey"), route.get("matchValue"))
    if not route_conditions:
        return True
    return all(params.get(key) == value for key, value in route_conditions)


def select_route(routes, day, speaker_id):
    matches = [route for route in routes if match_route(route, day, speaker_id)]
    param_matches = [route for route in matches if route.get("matchKey")]
    if param_matches:
        return sorted(param_matches, key=lambda r: int(r.get("id") or 0))[0]
    if matches:
        return sorted(matches, key=lambda r: int(r.get("id") or 0))[0]
    return None


def action_matches(action, question):
    key = (action.get("conditionKey") or "").strip()
    value = (action.get("conditionValue") or "").strip()
    if not key:
        return True
    if key != "question":
        return False
    actual = {item.strip() for item in question.split(",") if item.strip()}
    expected = {item.strip() for item in value.split(",") if item.strip()}
    return expected.issubset(actual)


def selected_action_types(route, question=""):
    actions = ((route.get("strategy") or {}).get("actions") or [])
    selected = []
    selected_problem = ""
    for action in sorted(actions, key=lambda item: (int(item.get("orderIndex") or 0), int(item.get("id") or 0))):
        if not action_matches(action, question):
            continue
        value = action.get("conditionValue") or ""
        problem_key = "|".join([item for item in value.split(",") if "有问题" in item])
        if problem_key:
            if not selected_problem:
                selected_problem = problem_key
            elif selected_problem != problem_key:
                continue
        selected.append(action.get("type"))
    return selected


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    routes = load_config()
    summary = {
        "routeCount": len(routes),
        "liyao": [],
        "yaqi": [],
        "otherSpeaker": [],
        "day1Questions": {},
    }

    for route in routes:
        strategy = route.get("strategy") or {}
        name = strategy.get("name") or ""
        if name.startswith("yaqi-piano-"):
            expect(route.get("matchKey") == "currentDay&&homeworkDayRelation&&speakerId", f"bad yaqi matchKey: {route}")
            expect(str(route.get("matchValue", "")).endswith("&&113"), f"bad yaqi matchValue: {route}")

    for day in (1, 2, 3, 4):
        yaqi_route = select_route(routes, day, "113")
        expect(yaqi_route is not None, f"missing yaqi day{day} route")
        yaqi_name = (yaqi_route.get("strategy") or {}).get("name")
        expect(yaqi_name == f"yaqi-piano-day{day}-comment1", f"bad yaqi day{day}: {yaqi_name}")
        summary["yaqi"].append({"day": day, "routeId": yaqi_route.get("id"), "name": yaqi_name})

        liyao_route = select_route(routes, day, "110")
        expect(liyao_route is not None, f"missing liyao day{day} route")
        liyao_name = (liyao_route.get("strategy") or {}).get("name")
        expect(not str(liyao_name).startswith("yaqi-piano-"), f"liyao matched yaqi on day{day}")
        summary["liyao"].append({"day": day, "routeId": liyao_route.get("id"), "name": liyao_name})

        other_route = select_route(routes, day, "999")
        other_name = (other_route.get("strategy") or {}).get("name") if other_route else None
        expect(other_route is None or not str(other_name).startswith("yaqi-piano-"), f"other speaker matched yaqi day{day}")
        summary["otherSpeaker"].append({"day": day, "routeId": other_route.get("id") if other_route else None, "name": other_name})

    day1_route = select_route(routes, 1, "113")
    for question, expected_types in EXPECTED[1].items():
        actual = selected_action_types(day1_route, question)
        expect(actual == expected_types, f"D1 {question} expected {expected_types}, got {actual}")
        summary["day1Questions"][question] = actual

    for day in (2, 3, 4):
        route = select_route(routes, day, "113")
        actions = (route.get("strategy") or {}).get("actions") or []
        actual = [(action.get("type"), action.get("conditionKey") or "") for action in sorted(actions, key=lambda item: int(item.get("orderIndex") or 0))]
        expect(actual == EXPECTED[day], f"D{day} actions expected {EXPECTED[day]}, got {actual}")

    SUMMARY_PATH.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
