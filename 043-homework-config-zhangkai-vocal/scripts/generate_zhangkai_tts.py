# -*- coding: utf-8 -*-
"""Generate zhangkai Day1-Day6 second-review cloned voice files.

This script reuses the local ByteDance TTS demo credentials from the existing
demo file and does not duplicate secrets in this Spec Kit directory.
"""

import base64
import importlib.util
import json
from pathlib import Path

import requests


ROOT = Path(r"C:\workspace\ju-chat")
DEMO_PATH = ROOT / "tts_http_demo" / "src" / "main" / "java" / "com" / "bytedance" / "tts" / "demo" / "tts_http_demo.py"
OUTPUT_DIR = Path(r"C:\workspace\homework_file\kelong")
SPEAKER = "S_xOAzRIZR1"

TEXTS = {
    "day1-second.mp3": "您看啊，在经过第一次你提交作业了过后，这次再唱万疆这首歌，能感受到明显的进步！特别在喉咙的使用上，比第一次要放开许多了，声音放出来了，特别棒！但是还需要注意勤加练习！",
    "day2-second.mp3": "大海 就是我故乡，这句歌词在唱的时候啊，一定要注意断句，并且要想想在课程中的时候我教学如何呼吸、换气的，这样你才能更好、更流利的去掌握换气，并通顺的唱出这首歌，并且这个方法学会了过后，您再唱别的歌，也不会气换不过来",
    "day3-second.mp3": "在唱高音的时候啊，特别是唱到大这个字的时候，喉咙放开，然后腹部用力，让气顶上来，你刚提交的这个作业里，稍微有一些这样的感觉了，气只要顶上来了，高音就不是问题！",
    "day4-second.mp3": "同学，是不是对于节奏的掌握还是觉得有点摸不着脑袋？其实很简单，今天我在课程中讲课的时候呢，你应该有注意到我在拍手、并在唱康定情歌，其实拍手是有利于我们找到节奏，然后再跟着节奏去唱的，所以你可以试试这种方式来让自己找到节奏",
    "day5-second.mp3": "这下又进步许多了！在唱让海风吹拂了五千年的时候呀，还是我说的老问题，喉咙打开，别着急闭合，让气放出来，顶上来，这样去唱就能够做到让音变得更长！",
    "day6-second.mp3": "今天是最后一节课啦！同学您在唱歌上真的是很用心很刻苦的在跟着我学习！节奏和节拍的运用咱们可能还暂时掌控不了，但是您别担心，如果有机会跟着我学习长期课程，相信咱们一定能越唱越好！",
}


def load_demo_config():
    spec = importlib.util.spec_from_file_location("tts_http_demo", DEMO_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.appID, module.accessKey, module.resourceID, module.url


def generate_one(session, url, headers, text, output_path):
    payload = {
        "user": {"uid": "zhangkai-homework-config"},
        "req_params": {
            "text": text,
            "speaker": SPEAKER,
            "audio_params": {
                "format": "mp3",
                "sample_rate": 24000,
                "enable_timestamp": True,
            },
            "additions": json.dumps(
                {
                    "explicit_language": "zh",
                    "disable_markdown_filter": True,
                    "enable_timestamp": True,
                },
                ensure_ascii=False,
            ),
        },
    }

    with session.post(url, headers=headers, json=payload, stream=True, timeout=120) as response:
        response.raise_for_status()
        audio = bytearray()
        for chunk in response.iter_lines(decode_unicode=True):
            if not chunk:
                continue
            data = json.loads(chunk)
            code = data.get("code", 0)
            if code == 0 and data.get("data"):
                audio.extend(base64.b64decode(data["data"]))
            elif code == 20000000:
                break
            elif code and code > 0:
                raise RuntimeError(f"TTS error for {output_path.name}: {data}")

    if not audio:
        raise RuntimeError(f"TTS returned empty audio for {output_path.name}")
    output_path.write_bytes(audio)
    return len(audio)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    app_id, access_key, resource_id, url = load_demo_config()
    headers = {
        "X-Api-App-Id": app_id,
        "X-Api-Access-Key": access_key,
        "X-Api-Resource-Id": resource_id,
        "Content-Type": "application/json",
        "Connection": "keep-alive",
    }
    with requests.Session() as session:
        for filename, text in TEXTS.items():
            output_path = OUTPUT_DIR / filename
            size = generate_one(session, url, headers, text, output_path)
            print(f"{filename}\t{size}")


if __name__ == "__main__":
    main()
