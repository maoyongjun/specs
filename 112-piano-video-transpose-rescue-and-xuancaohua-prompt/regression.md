# 真实调用回归记录

> 说明：V2 完整识别链路（`PianoHomeWorkVideoV2Task` → 异步调用 `FcOssFFmpeg-3278/VideoToNoteSeq` 提取音序 → Redis 取结果 → 工程侧模板匹配/决策 → 注入提示词调 Gemini）依赖部署在阿里云的函数计算、Redis 与 Gemini 代理。**本地开发沙箱无 FC 凭证、且 `VideoToNoteSeq` 不在本工作区**，无法在本地真实驱动整条链路。
>
> 因此本文件分两部分：(A) 回归用例与期望（用户给定）+ 与本次改动后代码逻辑的一致性分析；(B) 实测结果表（待在部署环境执行后回填）。其中噪声样本 a8bdb7b2（即原始问题日志样本）的音序已知，已由单元测试锁定结果，可直接确认。

## A. 回归用例与期望

### 假设当天 = D4（expectedDay=D4）

| 视频 | 期望识别 | 期望作业类型 | 与代码逻辑一致性分析 |
| --- | --- | --- | --- |
| V1-1.mp4 | D1 四季歌 | 过去作业（补交） | 四季歌含 Fa、无萱草花开头指纹；D1 命中后 recognizedId=1<4 → 补交。 |
| V1-2.mp4 | D1 四季歌 | 过去作业（补交） | 同上。 |
| V2-1.mp4 | D2 铁血丹心（隐含） | 过去作业（补交） | 用户未显式给 D4 下 V2 期望，按 D2<4 应为补交；以实测为准。 |
| V3-1.mp4 | D3 或 D4 沧海一声笑 | 当日作业（D4）/或 D3 | 沧海组 dayMin/dayMax={3,4}；expectedDay=D4 落在组内 → recognizedId=4 今日作业；若工程侧未高置信则交 Gemini 在 D3/D4 间按左手和弦判。 |
| V5-1.mp4 | D5 萱草花 | 见备注 | 萱草花开头指纹 `3 3 3 5` → D5 组（dayMin/dayMax={5,6}）。**备注：expectedDay=D4 时 D5>D4 按代码应为「提前提交」**；用户原文写「当日作业」疑为笔误或指 V3，待实测/用户澄清。 |

### 假设今天 = D2（expectedDay=D2）

| 视频 | 期望识别 | 期望作业类型 | 与代码逻辑一致性分析 |
| --- | --- | --- | --- |
| V5-1.mp4 | D5 萱草花 | 未来作业（提前提交） | D5>D2 → 提前提交，与代码 `resolveTemplateSubmissionType` 一致。 |
| V1-1.mp4 | D1 四季歌 | 过去作业（补交） | D1<D2 → 补交。 |

### 应识别为 -1（非作业/人工复核）

| 视频 | 期望 | 与代码逻辑一致性分析 |
| --- | --- | --- |
| a8bdb7b2…e86aa4792c1f.mp4 | id=-1 | **即本次问题原始日志样本**，音序 `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3`。本次修复后：移调补救因连续短语过低不再凑成高置信 D2 → 落「低分人工复核」id=-1。**已由单元测试 `handleRequest_transposedOutOfScaleNoise_shouldShortCircuitToManualReview` 锁定**（断言 id=-1、isHomeWork=否、needHumanReview=true、不调 Gemini）。 |
| ec62a262…42988134f7a3.mp4 | id=-1 | 期望非课程曲目/噪声 → 低分人工复核或课程外音级拦截 → id=-1。音序未知，待实测。 |
| e57f1dda…3d14fbf6a327.mp4 | 沧海一声笑(D3/D4) 或 id=-1 | 介于沧海与不可判之间：若音序稳定命中沧海组则 D3/D4，否则低分人工复核 id=-1。音序未知，待实测。 |

## B. 实测结果（待部署环境执行后回填）

执行方式（在可访问 FC/Redis/Gemini 的环境）：以 `PianoHomeWorkVideoV2Task` 的请求体驱动，关键参数：
```json
{
  "prompt": "<prompt-v2-revised.md 的提示词，含 ${audioseq}/${engineeringContext} 占位与 expectedDay 已格式化>",
  "file_url": "<视频URL>",
  "expectedDay": "D4 或 D2",
  "taskId": "<回归批次ID>"
}
```
关注返回 JSON 的 `id`、`title`、`coreElements.recognizedDay`、`coreElements.submissionType`、`needHumanReview`，以及日志中的 `engineeringContext.templateScores` / `engineeringDecision`。

| 视频 | 假设当天 | 期望 | 实测 id/title/recognizedDay/submissionType | 实测音序(noteSequenceText) | 结论 |
| --- | --- | --- | --- | --- | --- |
| V1-1.mp4 | D4 | D1/补交 | 待回填 | 待回填 | 待回填 |
| V1-2.mp4 | D4 | D1/补交 | 待回填 | 待回填 | 待回填 |
| V2-1.mp4 | D4 | D2/补交 | 待回填 | 待回填 | 待回填 |
| V3-1.mp4 | D4 | D3或D4 | 待回填 | 待回填 | 待回填 |
| V5-1.mp4 | D4 | D5/(提前?) | 待回填 | 待回填 | 待回填 |
| V5-1.mp4 | D2 | D5/提前提交 | 待回填 | 待回填 | 待回填 |
| 1-1.mp4(V1-1) | D2 | D1/补交 | 待回填 | 待回填 | 待回填 |
| a8bdb7b2….mp4 | 任意 | id=-1 | 单测已锁定 id=-1（若 VideoToNoteSeq 复现同音序则确定）| D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3 | 单测通过 |
| ec62a262….mp4 | 任意 | id=-1 | 待回填 | 待回填 | 待回填 |
| e57f1dda….mp4 | 任意 | 沧海或 -1 | 待回填 | 待回填 | 待回填 |

视频地址：
- https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V1-1.mp4
- https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V1-2.mp4
- https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V2-1.mp4
- https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V3-1.mp4
- https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V5-1.mp4
- https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_fb19fed680d94327b9e47831834dc17e/link_msg/19b8e245-7478-4102-8ef9-a5950b827bd9/a8bdb7b2-828b-448b-b21a-e86aa4792c1f.mp4
- https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_950f035ddfe848bb955395f7f37dd813/link_msg/2165eee8-c654-42b6-9266-20169e43a4a2/ec62a262-1162-450d-a544-42988134f7a3.mp4
- https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_fb19fed680d94327b9e47831834dc17e/link_msg/fe73816b-a9fa-4443-85c6-daf802cf999e/e57f1dda-661b-4596-a6b3-3d14fbf6a327.mp4

## 备注

- 本地仅能跑单元测试（已全绿，60/60）。要得到上表「实测」列，需在部署环境执行；或由用户提供各视频经 `VideoToNoteSeq` 提取的音序，我可在本地直接跑 `PianoNoteSequenceTemplateMatcher.match` + 工程侧决策回填工程侧结论（Gemini 侧仍需线上）。
- D4 假设下 V5「当日作业」与代码语义（D5>D4=提前提交）不一致，待用户澄清或以实测为准。
