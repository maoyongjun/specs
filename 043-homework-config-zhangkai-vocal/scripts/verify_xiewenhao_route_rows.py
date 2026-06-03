# -*- coding: utf-8 -*-
"""Verify liuyuan/xiewenhao route rows with SopConfigSender-compatible matching."""

import json
import argparse
from pathlib import Path


INPUT = Path(r"C:\workspace\ju-chat\target\db-sync\test_xiewenhao_route_rows_20260603.json")
OUTPUT = Path(r"C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal\xiewenhao-verification-summary.json")

FIRST_COMMENT_ACTIONS = {
    1: ["TEXT", "VOICE", "VOICE"],
    2: ["TEXT", "VOICE", "VOICE"],
    3: ["TEXT", "VOICE", "VOICE", "VOICE"],
    4: ["TEXT", "VOICE", "VOICE"],
    5: ["TEXT", "VOICE", "VOICE"],
    6: ["TEXT", "VOICE"],
}


def split_and(value):
    return [part.strip() for part in (value or "").split("&&") if part.strip()]


def split_values(value):
    return [part.strip() for part in (value or "").replace("，", ",").split(",") if part.strip()]


def parse_conditions(key_expr, value_expr):
    keys = split_and(key_expr)
    values = split_and(value_expr)
    if not keys:
        return []
    if len(keys) != len(values):
        return None
    return list(zip(keys, values))


def is_comment_matched(route, comment_index):
    route_index = int(route.get("comment_index") or 0)
    match_type = (route.get("comment_match_type") or "EQ").strip().upper()
    return comment_index >= route_index if match_type == "GTE" else comment_index == route_index


def is_better_gte(candidate, current):
    if current is None:
        return True
    candidate_index = int(candidate.get("comment_index") or -1)
    current_index = int(current.get("comment_index") or -1)
    if candidate_index != current_index:
        return candidate_index > current_index
    return int(candidate.get("route_id") or -1) > int(current.get("route_id") or -1)


def value_satisfied(key, actual, expected):
    actual = (actual or "").strip()
    expected = (expected or "").strip()
    if not actual or not expected:
        return False
    if key.lower() == "qwuserid_rlike":
        actual_lower = actual.lower()
        return any(item.lower() in actual_lower for item in split_values(expected))
    return set(split_values(actual)).issuperset(set(split_values(expected)))


def all_conditions_matched(conditions, params):
    if not conditions:
        return False
    for key, expected in conditions:
        if not value_satisfied(key, params.get(key, ""), expected):
            return False
    return True


def select_route(routes, day, comment_index, relation, qw_user_id):
    params = {
        "skuId": "5",
        "currentDay": str(day),
        "homeworkDayRelation": relation,
        "qwUserId_RLike": qw_user_id,
    }
    matched_eq = None
    matched_gte = None
    for route in routes:
        if int(route.get("day_num") or 0) != day:
            continue
        if (route.get("sku_id") or "*").strip() != "5":
            continue
        if not is_comment_matched(route, comment_index):
            continue
        conditions = parse_conditions(route.get("match_key"), route.get("match_value"))
        if conditions is None or not all_conditions_matched(conditions, params):
            continue
        match_type = (route.get("comment_match_type") or "EQ").strip().upper()
        if match_type == "GTE":
            if is_better_gte(route, matched_gte):
                matched_gte = route
        elif matched_eq is None:
            matched_eq = route
    return matched_eq or matched_gte


def action_types(route):
    raw = route.get("action_types") if route else ""
    return [item for item in raw.split(",") if item]


def expect(route, expected_name, expected_actions):
    actual_name = route.get("strategy_name") if route else None
    actual_actions = action_types(route)
    if actual_name != expected_name:
        raise AssertionError(f"expected {expected_name}, got {actual_name}")
    if actual_actions != expected_actions:
        raise AssertionError(f"{expected_name} actions expected {expected_actions}, got {actual_actions}")
    return {"routeId": route.get("route_id"), "name": actual_name, "actions": actual_actions}


def verify_user(routes, qw_user_id):
    result = {
        "current_comment1": [],
        "current_comment2": [],
        "current_comment3": [],
        "current_manual": [],
        "past_manual": [],
        "future_manual": [],
    }
    for day in range(1, 7):
        result["current_comment1"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "CURRENT", qw_user_id), f"liuyuan-vocal-day{day}-comment1", FIRST_COMMENT_ACTIONS[day]),
        })
        result["current_comment2"].append({
            "day": day,
            **expect(select_route(routes, day, 2, "CURRENT", qw_user_id), f"liuyuan-vocal-day{day}-comment2", ["TEXT", "VOICE"]),
        })
        result["past_manual"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "PAST", qw_user_id), f"liuyuan-vocal-day{day}-past-manual", []),
        })
        result["future_manual"].append({
            "day": day,
            **expect(select_route(routes, day, 1, "FUTURE", qw_user_id), f"liuyuan-vocal-day{day}-future-manual", []),
        })

    for day in range(1, 5):
        result["current_comment3"].append({
            "day": day,
            **expect(select_route(routes, day, 3, "CURRENT", qw_user_id), f"liuyuan-vocal-day{day}-comment3", ["TEXT"]),
        })
        result["current_manual"].append({
            "day": day,
            "commentIndex": 4,
            **expect(select_route(routes, day, 4, "CURRENT", qw_user_id), f"liuyuan-vocal-day{day}-comment4plus-manual", []),
        })

    for day in (5, 6):
        result["current_manual"].append({
            "day": day,
            "commentIndex": 3,
            **expect(select_route(routes, day, 3, "CURRENT", qw_user_id), f"liuyuan-vocal-day{day}-comment3plus-manual", []),
        })
    return result


def main():
    parser = argparse.ArgumentParser(description="Verify liuyuan/xiewenhao homework route rows.")
    parser.add_argument("--input", default=str(INPUT))
    parser.add_argument("--output", default=str(OUTPUT))
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    payload = json.loads(input_path.read_text(encoding="utf-8"))
    routes = payload.get("rows") or []
    if len(routes) != 34:
        raise AssertionError(f"expected 34 route rows, got {len(routes)}")
    summary = {
        "routeCount": len(routes),
        "liuyuan": verify_user(routes, "liuyuan"),
        "xiewenhao": verify_user(routes, "xiewenhao"),
        "other_user": [],
    }
    for day in range(1, 7):
        route = select_route(routes, day, 1, "CURRENT", "wangwu")
        if route is not None:
            raise AssertionError(f"other user matched route on day{day}: {route}")
        summary["other_user"].append({"day": day, "matched": False})
    output_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({
        "routeCount": summary["routeCount"],
        "liuyuanComment1": len(summary["liuyuan"]["current_comment1"]),
        "xiewenhaoComment1": len(summary["xiewenhao"]["current_comment1"]),
        "otherUserMatched": any(item["matched"] for item in summary["other_user"]),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
