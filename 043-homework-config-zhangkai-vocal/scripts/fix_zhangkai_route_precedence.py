# -*- coding: utf-8 -*-
"""Rebind zhangkai routes with currentDay prefix so runtime matching wins."""

import requests


BASE_URL = "http://localhost:9011"
ACCESS_KEY = "drh20262026"
OPERATOR = "zhangkai_config_20260601"
SKU_ID = "5"


def request_json(session, method, path, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["X-Config-Key"] = ACCESS_KEY
    response = session.request(method, BASE_URL + path, headers=headers, timeout=60, **kwargs)
    response.raise_for_status()
    if response.text:
        data = response.json()
        if isinstance(data, dict) and data.get("status") not in (None, 0, 200):
            raise RuntimeError(data)
        return data
    return None


def route_relation(route):
    value = route.get("matchValue") or ""
    parts = [part.strip() for part in value.split("&&") if part.strip()]
    if len(parts) >= 3:
        return parts[1]
    if len(parts) >= 2:
        return parts[0]
    return value.strip()


def main():
    with requests.Session() as session:
        config = request_json(session, "GET", f"/admin/homework-config/config?skuId={SKU_ID}")["data"]
        routes = [
            route for route in config.get("routes", [])
            if route.get("strategy")
            and str(route["strategy"].get("name", "")).startswith("zhangkai-vocal-")
            and "zhangkai" in str(route.get("matchValue", ""))
        ]
        print(f"found\t{len(routes)}")
        for route in routes:
            relation = route_relation(route)
            day = route["day"]
            payload = {
                "day": day,
                "commentIndex": route["commentIndex"],
                "commentMatchType": route.get("commentMatchType") or "EQ",
                "strategyId": route["strategy"]["id"],
                "matchKey": "currentDay&&homeworkDayRelation&&qwUserId_RLike",
                "matchValue": f"{day}&&{relation}&&zhangkai",
                "skuId": SKU_ID,
            }
            request_json(session, "DELETE", f"/admin/homework-config/routes/{route['id']}")
            request_json(
                session,
                "POST",
                f"/admin/homework-config/routes?operator={OPERATOR}",
                json=payload,
            )
            print(f"rebound\tday{day}\t{route['commentIndex']}\t{payload['commentMatchType']}\t{relation}\t{payload['strategyId']}")


if __name__ == "__main__":
    main()
