# -*- coding: utf-8 -*-
"""Create liuyuan vocal homework-review config through localhost admin APIs."""

import json
from pathlib import Path

import requests


BASE_URL = "http://localhost:9011"
ACCESS_KEY = "drh20262026"
SKU_ID = "5"
OPERATOR = "liuyuan_config_20260601"
HOMEWORK_DIR = Path(r"C:\workspace\homework_file")
CLONED_DIR = HOMEWORK_DIR / "kelong"
OUTPUT_JSON = Path(r"C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal\created-records.json")

FIRST_TEXTS = {
    1: "收到您第一节课《万疆》的作业了，我现在给您点评，您耐心听完，今天学习情况不错！明天也要坚持来上第二节课！",
    2: "大海啊故乡这节课，教学的内容是能够帮我们去打开喉咙，锻炼气息的，我再把技巧给您讲解下！",
    3: "很多同学都觉得今天这节课很难，要唱高音，但您表现的很棒，今天的技巧都掌握了，我听完了你提交的作业，我马上给你点评！明天是很关键的一节课，一定要来参加！",
    4: "今天对于节奏的掌握感觉怎么样？跟得上歌曲的节奏不？我看你学的很用心，我先给你点评！",
    5: "看来咱们经过4天的学习，已经和当时没上课的您有很大的提升啊！但是对于技巧和方法的运用上，我再给您讲讲，您稍等 我给您发语音！",
    6: "同学您好啊！今天是最后一节课了，赵老师还是用心给你点评，您也耐心听完赵老师讲的，我们学习不要半途而废！坚持下去！",
}

SECOND_TEXTS = {
    1: "好嘞！同学很用心！这是第二次提交《万疆》了，我先听听咱们这次对比第一次没有没进步哈！",
    2: "同学，收到你的作业啦，我刚听完你的作业，在整段的表现上，有小进步，但是还有需要注意的细节，我发语音你听听",
    3: "很棒！很多同学看到高音的歌曲，就不敢提交作业了，您是第二次提交了，看来您很用心在学习，我马上给你点评",
    4: "收到作业啦～ 今天的课程上的怎么样？学习一定是要坚持并且长期学习下去的，不能够半途而废哦，我先听听咱们这次提交的情况哈",
    5: "今天是倒数第二节课了！您依然很用心的在跟着我学习，我先听听您的作业",
    6: "好嘞同学！今天是最后一天一起学习啦，我听完你的作业了，您听听",
}

THIRD_TEXTS = {
    1: "我听完了！确实是有在勤加练习，特别好学！我也很开心能够遇到勤奋的同学，相信您这样坚持勤练下去，咱们一起能学有所成！",
    2: "嗯！能修正一些细节上的唱法，很不错，喉咙一定要打开、放开、让声音出来，换气的时候要大口吸气，慢慢吐出来，这样就能让气息越来越稳！",
    3: "这一次稍微好很多了，气的感觉已经上来了，剩下的就是稳住，您要是有时间，多看看第二节课的回放，把咱们气息的运用多巩固巩固，这样以后唱高音就更没问题啦！",
    4: "才开始可以不用着急去抓节拍和节奏，先跟着自己拍掌的频率来唱，这样就能够掌握的更好！",
}


def request_json(session, method, path, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["X-Config-Key"] = ACCESS_KEY
    response = session.request(method, BASE_URL + path, headers=headers, timeout=120, **kwargs)
    response.raise_for_status()
    data = response.json()
    if isinstance(data, dict) and data.get("status") not in (None, 0, 200):
        raise RuntimeError(f"{method} {path} failed: {data}")
    return data


def unwrap(data):
    if isinstance(data, dict) and "data" in data:
        return data["data"]
    return data


def first_voice_file(day):
    path = CLONED_DIR / "first-mp3" / f"day{day}-first.mp3"
    if not path.exists() or path.stat().st_size <= 0:
        raise FileNotFoundError(f"missing converted first voice for day {day}: {path}")
    return path


def second_voice_file(day):
    path = CLONED_DIR / f"day{day}-second.mp3"
    if not path.exists() or path.stat().st_size <= 0:
        raise FileNotFoundError(f"missing cloned voice for day {day}: {path}")
    return path


def ensure_no_existing_liuyuan_routes(session):
    data = unwrap(request_json(session, "GET", f"/admin/homework-config/config?skuId={SKU_ID}"))
    routes = data.get("routes", []) if isinstance(data, dict) else []
    hits = [
        route for route in routes
        if "liuyuan" in str(route.get("matchValue", "")).lower()
    ]
    if hits:
        raise RuntimeError(f"found existing liuyuan routes, abort to avoid duplicates: {len(hits)}")


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


def add_text_action(session, strategy_id, order, text, delay_ms=2000):
    files = [
        ("type", (None, "TEXT")),
        ("orderIndex", (None, str(order))),
        ("textContent", (None, text)),
        ("delayMillis", (None, str(delay_ms))),
        ("operator", (None, OPERATOR)),
    ]
    data = unwrap(request_json(session, "POST", f"/admin/homework-config/strategies/{strategy_id}/actions", files=files))
    print(f"action\tTEXT\t{strategy_id}\t{data['id']}")
    return data


def add_voice_action(session, strategy_id, order, file_path):
    with file_path.open("rb") as fp:
        files = [
            ("type", (None, "VOICE")),
            ("orderIndex", (None, str(order))),
            ("operator", (None, OPERATOR)),
            ("file", (file_path.name, fp, "audio/mpeg")),
        ]
        data = unwrap(request_json(session, "POST", f"/admin/homework-config/strategies/{strategy_id}/actions", files=files))
    print(f"action\tVOICE\t{strategy_id}\t{data['id']}")
    return data


def bind_route(session, day, comment_index, match_type, relation, strategy_id):
    payload = {
        "day": day,
        "commentIndex": comment_index,
        "commentMatchType": match_type,
        "strategyId": strategy_id,
        "matchKey": "currentDay&&homeworkDayRelation&&qwUserId_RLike",
        "matchValue": f"{day}&&{relation}&&liuyuan",
        "skuId": SKU_ID,
    }
    request_json(
        session,
        "POST",
        f"/admin/homework-config/routes?operator={OPERATOR}",
        json=payload,
    )
    print(f"route\tday{day}\t{comment_index}\t{match_type}\t{relation}\t{strategy_id}")
    return payload


def main():
    created = {"operator": OPERATOR, "strategies": [], "actions": [], "routes": []}
    with requests.Session() as session:
        ensure_no_existing_liuyuan_routes(session)

        for day in range(1, 7):
            strategy = create_strategy(session, f"liuyuan-vocal-day{day}-comment1")
            created["strategies"].append(strategy)
            created["actions"].append(add_text_action(session, strategy["id"], 1, FIRST_TEXTS[day]))
            created["actions"].append(add_voice_action(session, strategy["id"], 2, first_voice_file(day)))
            created["routes"].append(bind_route(session, day, 1, "EQ", "CURRENT", strategy["id"]))

        for day in range(1, 7):
            strategy = create_strategy(session, f"liuyuan-vocal-day{day}-comment2")
            created["strategies"].append(strategy)
            created["actions"].append(add_text_action(session, strategy["id"], 1, SECOND_TEXTS[day]))
            created["actions"].append(add_voice_action(session, strategy["id"], 2, second_voice_file(day)))
            created["routes"].append(bind_route(session, day, 2, "EQ", "CURRENT", strategy["id"]))

        for day in range(1, 5):
            strategy = create_strategy(session, f"liuyuan-vocal-day{day}-comment3")
            created["strategies"].append(strategy)
            created["actions"].append(add_text_action(session, strategy["id"], 1, THIRD_TEXTS[day]))
            created["routes"].append(bind_route(session, day, 3, "EQ", "CURRENT", strategy["id"]))

        manual_current = {
            1: (4, "GTE", "comment4plus-manual"),
            2: (4, "GTE", "comment4plus-manual"),
            3: (4, "GTE", "comment4plus-manual"),
            4: (4, "GTE", "comment4plus-manual"),
            5: (3, "GTE", "comment3plus-manual"),
            6: (3, "GTE", "comment3plus-manual"),
        }
        for day, (comment_index, match_type, suffix) in manual_current.items():
            strategy = create_strategy(session, f"liuyuan-vocal-day{day}-{suffix}")
            created["strategies"].append(strategy)
            created["routes"].append(bind_route(session, day, comment_index, match_type, "CURRENT", strategy["id"]))

        for relation in ("PAST", "FUTURE"):
            for day in range(1, 7):
                strategy = create_strategy(session, f"liuyuan-vocal-day{day}-{relation.lower()}-manual")
                created["strategies"].append(strategy)
                created["routes"].append(bind_route(session, day, 1, "GTE", relation, strategy["id"]))

    OUTPUT_JSON.write_text(json.dumps(created, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"created json\t{OUTPUT_JSON}")


if __name__ == "__main__":
    main()
