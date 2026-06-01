# -*- coding: utf-8 -*-
"""Verify liuyuan homework-review routing with SopConfigSender-compatible logic."""

import json
from pathlib import Path

import requests


BASE_URL = "http://localhost:9011"
OUT = Path(r"C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal\verification-summary.json")

FIRST_COMMENT_ACTIONS = {
    1: ["TEXT", "VOICE", "VOICE"],
    2: ["TEXT", "VOICE", "VOICE"],
    3: ["TEXT", "VOICE", "VOICE", "VOICE"],
    4: ["TEXT", "VOICE", "VOICE"],
    5: ["TEXT", "VOICE", "VOICE"],
    6: ["TEXT", "VOICE"],
}


def load_routes():
    response = requests.get(f"{BASE_URL}/api/homework-config/config?skuId=5", timeout=120)
    response.raise_for_status()
    data = response.json()
    return data.get("routes") or []


def split_and(value):
    value = (value or "").strip()
    return [part.strip() for part in value.split("&&") if part.strip()]


def split_values(value):
    value = (value or "").strip()
    return [part.strip() for part in value.replace("，", ",").split(",") if part.strip()]


def parse_conditions(key_expr, value_expr):
    keys = split_and(key_expr)
    values = split_and(value_expr)
    if not keys:
        return []
    if len(keys) != len(values):
        return None
    return list(zip(keys, values))


def is_comment_matched(route, comment_index):
    route_index = int(route.get("commentIndex") or 0)
    match_type = (route.get("commentMatchType") or "EQ").strip().upper()
    if match_type == "GTE":
        return comment_index >= route_index
    return comment_index == route_index


def value_satisfied(key, actual, expected):
    actual = (actual or "").strip()
    expected = (expected or "").strip()
    if not actual or not expected:
        return False
    if key.lower() == "qwuserid_rlike":
        actual_lower = actual.lower()
        return any(item.lower() in actual_lower for item in split_values(expected))
    actual_values = set(split_values(actual))
    expected_values = set(split_values(expected))
    return actual_values.issuperset(expected_values)


def all_conditions_matched(conditions, params):
    if not conditions:
        return False
    for key, expected in conditions:
        if not value_satisfied(key, params.get(key, ""), expected):
            return False
    return True


def is_better_gte(candidate, current):
    if current is None:
        return True
    candidate_index = int(candidate.get("commentIndex") or -1)
    current_index = int(current.get("commentIndex") or -1)
    if candidate_index != current_index:
        return candidate_index > current_index
    return int(candidate.get("id") or -1) > int(current.get("id") or -1)


def select_route(routes, day, comment_index, relation, qw_user_id):
    params = {
        "skuId": "5",
        "currentDay": str(day),
        "homeworkDayRelation": relation,
        "qwUserId_RLike": qw_user_id,
    }
    matched_eq_param = None
    matched_gte_param = None
    matched_eq_default = None
    matched_gte_default = None
    for route in routes:
        if int(route.get("day") or 0) != day:
            continue
        if (route.get("skuId") or "*").strip() != "5":
            continue
        if not is_comment_matched(route, comment_index):
            continue
        match_type = (route.get("commentMatchType") or "EQ").strip().upper()
        conditions = parse_conditions(route.get("matchKey"), route.get("matchValue"))
        if conditions is None:
            continue
        if not conditions:
            if match_type == "GTE":
                if is_better_gte(route, matched_gte_default):
                    matched_gte_default = route
            elif matched_eq_default is None:
                matched_eq_default = route
            continue
        if not all_conditions_matched(conditions, params):
            continue
        if match_type == "GTE":
            if is_better_gte(route, matched_gte_param):
                matched_gte_param = route
        elif matched_eq_param is None:
            matched_eq_param = route
    return matched_eq_param or matched_gte_param or matched_eq_default or matched_gte_default


def action_types(route):
    if not route or not route.get("strategy"):
        return []
    return [action.get("type") for action in route["strategy"].get("actions") or []]


def expect(route, expected_name, expected_actions):
    actual_name = route.get("strategy", {}).get("name") if route else None
    actual_actions = action_types(route)
    if actual_name != expected_name:
        raise AssertionError(f"expected {expected_name}, got {actual_name}")
    if actual_actions != expected_actions:
        raise AssertionError(f"{expected_name} actions expected {expected_actions}, got {actual_actions}")
    return {"routeId": route.get("id"), "name": actual_name, "actions": actual_actions}


def main():
    routes = load_routes()
    results = {
        "current_comment1": [],
        "current_comment2": [],
        "current_comment3": [],
        "current_manual": [],
        "past_manual": [],
        "future_manual": [],
        "other_user": [],
    }

    for day in range(1, 7):
        results["current_comment1"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "CURRENT", "liuyuan"), f"liuyuan-vocal-day{day}-comment1", FIRST_COMMENT_ACTIONS[day]),
        })
        results["current_comment2"].append({
            "day": day,
            **expect(select_route(routes, day, 2, "CURRENT", "liuyuan"), f"liuyuan-vocal-day{day}-comment2", ["TEXT", "VOICE"]),
        })
        results["past_manual"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "PAST", "liuyuan"), f"liuyuan-vocal-day{day}-past-manual", []),
        })
        results["future_manual"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "FUTURE", "liuyuan"), f"liuyuan-vocal-day{day}-future-manual", []),
        })

    for day in range(1, 5):
        results["current_comment3"].append({
            "day": day,
            **expect(select_route(routes, day, 3, "CURRENT", "liuyuan"), f"liuyuan-vocal-day{day}-comment3", ["TEXT"]),
        })
        results["current_manual"].append({
            "day": day,
            "commentIndex": 4,
            **expect(select_route(routes, day, 4, "CURRENT", "liuyuan"), f"liuyuan-vocal-day{day}-comment4plus-manual", []),
        })

    for day in (5, 6):
        results["current_manual"].append({
            "day": day,
            "commentIndex": 3,
            **expect(select_route(routes, day, 3, "CURRENT", "liuyuan"), f"liuyuan-vocal-day{day}-comment3plus-manual", []),
        })

    for day in range(1, 7):
        route = select_route(routes, day, 1, "CURRENT", "wangwu")
        name = route.get("strategy", {}).get("name") if route else None
        if name and name.startswith("liuyuan-vocal-"):
            raise AssertionError(f"other user matched liuyuan route on day{day}: {name}")
        results["other_user"].append({"day": day, "routeId": route.get("id") if route else None, "name": name})

    OUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
