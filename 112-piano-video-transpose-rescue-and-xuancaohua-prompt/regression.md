# 真实调用回归记录

> 说明：本次 D005 已真实调用部署在阿里云的 `FcOssFFmpeg-3278/VideoToNoteSeq`，通过 Redis 取回音序，再用当前本地 V2 工程代码执行模板匹配、低分/课程外音级/假高置信 D2 短路和作业关系判定。  
> 本次未调用 Gemini；因此 `NEEDS_GEMINI` 的样本只记录工程侧候选，完整线上最终 JSON 仍需以 Gemini 调用结果为准。高置信工程侧覆盖与人工复核短路样本不依赖 Gemini 分类。

## A. 回归用例与期望

### 假设当天 = D4（expectedDay=D4）

| 视频 | 期望识别 | 期望作业类型 | 与代码逻辑一致性分析 |
| --- | --- | --- | --- |
| V1-1.mp4 | D1 四季歌 | 过去作业（补交） | 四季歌含 Fa、无萱草花开头指纹；D1 命中后 recognizedId=1<4 → 补交。 |
| V1-2.mp4 | D1 四季歌 | 过去作业（补交） | 同上。 |
| V2-1.mp4 | 未明确指定 | 未明确指定 | 用户未显式给 D4 下 V2 期望；本次仅记录实测结果，不纳入期望通过/失败。 |
| V3-1.mp4 | D3 或 D4 沧海一声笑 | 当日作业（D4）/或 D3 | 沧海组 dayMin/dayMax={3,4}；expectedDay=D4 落在组内 → recognizedId=4 今日作业；若工程侧未高置信则交 Gemini 在 D3/D4 间按左手和弦判。 |
| V5-1.mp4 | D5 萱草花 | 未来作业（提前提交） | 萱草花开头指纹 `3 3 3 5` → D5 组（dayMin/dayMax={5,6}）。expectedDay=D4 时 D5>D4，按代码为「提前提交」。用户已确认前文「当日作业」是口误。 |

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

## B. D005 实测结果（2026-06-26）

执行方式：

- Runner：`scripts/RealPianoRegressionRunner.java`
- 明细 JSON：`out/real-regression-results.json`
- 真实调用：`FcOssFFmpeg-3278/VideoToNoteSeq`
- Redis：使用用户提供的 `db=3`、`redis_host`、`redis_password`；同时作为本地轮询环境变量和 FC event 透传字段。
- FC 响应：每次 `invokeFunction` 返回 HTTP 202，但响应头没有 `x-fc-stateful-async-invocation-id`；与现有 V2 代码一致，告警后继续按 `cacheKey` 轮询 Redis，所有 10 条均成功取回结果。

汇总结论：9 条有明确期望的断言全部通过；`V2-1_D4` 用户未给明确期望，仅记录实际结果。`V5-1_D4` 识别为 D5《萱草花》且判定「提前提交」，用户已确认这是正确结果，前文「当日作业」为口误。

| 视频/场景 | 期望 | 实测 id/title/recognizedDay/submissionType | resultType | 音序摘要 | 结论 |
| --- | --- | --- | --- | --- | --- |
| V1-1.mp4 / D4 | D1/补交 | `1 / 四季歌 / D1 / 补交作业` | `ENGINEERING_HIGH_CONFIDENCE` | `E5 E5 D5 C5 ... B4 C5 A4`（35 有效音） | 通过 |
| V1-2.mp4 / D4 | D1/补交 | `1 / 四季歌 / D1 / 补交作业` | `ENGINEERING_HIGH_CONFIDENCE` | `E5 E5 D5 C5 ... B4 C5 A4`（34 有效音） | 通过 |
| V2-1.mp4 / D4 | 未指定明确期望 | `-1 / 未知 / 未知 / 未知` | `FAKE_HIGH_CONFIDENCE_D2` | `E2 G2 C4 D2 G2 G2 G2 G2 C4 D2 G2 G2 A2` | 仅记录：音序短且连续短语低，触发假高置信 D2 防护，短路人工 |
| V3-1.mp4 / D4 | D3 或 D4 沧海一声笑 | `4 / 沧海一声笑 / D4 / 今日作业` | `NEEDS_GEMINI` | `A4 G4 E4 D4 C4 ... G4 D4 C4 D4`（26 有效音） | 工程候选通过；未高置信，线上最终仍会交 Gemini |
| V5-1.mp4 / D4 | D5/提前提交（未来作业） | `5 / 萱草花 / D5 / 提前提交` | `ENGINEERING_HIGH_CONFIDENCE` | `E5 E5 E4 G3 ... F3 E3 A4 C5`（39 有效音） | 通过 |
| V5-1.mp4 / D2 | D5/未来作业 | `5 / 萱草花 / D5 / 提前提交` | `ENGINEERING_HIGH_CONFIDENCE` | 同 V5-1/D4 | 通过 |
| V1-1.mp4 / D2 | D1/过去作业 | `1 / 四季歌 / D1 / 补交作业` | `ENGINEERING_HIGH_CONFIDENCE` | 同 V1-1/D4 | 通过 |
| a8bdb7b2….mp4 / D4 | id=-1 | `-1 / 未知 / 未知 / 未知` | `LOW_SCORE_MANUAL_REVIEW` | `D3 F3 F#3 F#3 C#3 F#3 B3 F#3 D#3 D#3 D3 C#3 C#3` | 通过 |
| ec62a262….mp4 / D4 | id=-1 | `-1 / 未知 / 未知 / 未知` | `OUT_OF_SCALE_MANUAL_REVIEW` | `C4 A2 B3 B3 ... E4 C#4 C#4 C#4`（68 有效音，outOfScaleRatio=0.37） | 通过 |
| e57f1dda….mp4 / D4 | 沧海一声笑或 id=-1 | `4 / 沧海一声笑 / D4 / 今日作业` | `ENGINEERING_HIGH_CONFIDENCE` | `C4 D4 E4 F4 G4 ... A4 G4 E4 C4 D4`（38 有效音） | 通过 |

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

- 完整 `noteSequenceText`、`templateScores`、`engineeringDecision`、`verdict` 均在 `out/real-regression-results.json`。
- 本次未调用 Gemini；`V3-1_D4` 的工程侧候选已满足 D3/D4 沧海预期，但线上完整最终结果仍依赖 Gemini 对视频画面/和弦细节的判断。
- D4 假设下 V5 为 D5>D4，属于未来作业/提前提交；用户已确认前文「当日作业」是口误。

## C. D007 追加回归：雅琪低质量沧海误判组X

来源：用户提供线上真实日志，未重新调用 FC。

视频：
https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_a93136d290a946898e7d9a45532e56aa/link_msg/580d5a31-af8a-4184-b729-0f7f75ecc831/870dce3f-e477-445a-b84c-fb2f3172d6dc.mp4

日志音序：
`C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3`

旧结果：
`speakerId=113`，`recognizedGroup=组X(但愿人长久)`，`groupXScore=0.80`，`groupYScore=0.61`，`scoreGap=0.19`，误判为但愿人长久补交作业。

期望：
用户说明该视频应按《沧海一声笑》方向理解，但由于弹得差、音序不稳定，不应硬判沧海或但愿人长久；应返回 `id=-1`、`needHumanReview=true`，走人工介入告警。

修复后验证：

| 样本 | speakerId | 旧结果 | 新结果 | 结论 |
| --- | --- | --- | --- | --- |
| 870dce3f…d6dc.mp4 / 日志音序 | 113 | `组X(但愿人长久)` | `未匹配` → `id=-1` 人工介入，不调 Gemini | 通过 |

测试：
`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'` → 62/62 通过。

## D. D008 追加回归：低质量升半音沧海误判铁血丹心

来源：用户提供线上真实日志，未重新调用 FC。

视频：
https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_efee6b26c4e94897b1ab246834a82545/link_msg/7808ec9f-93ea-4a0d-a1c1-97f122658f21/a4b39ceb-e6d6-4a37-a61f-3a1dffeff09c.mp4

日志音序：
`A#4 G#4 F4 D#4 C#4 A#2 F4 D#4 C#4 A#3 G#3 A#3 G#3 G#2 A#3 G#3 A#3 C#4 D#4 F4 G#4 A#4 G#4 F4 D#4 C#4 D4 D#4`

旧结果：
`recognizedDay=D2`，`title=铁血丹心`，`bestScore=0.91`，`scoreGap=0.76`，`priorityReason=原调匹配分低，整体移调6半音后命中D2`，误判为铁血丹心补交作业。

期望：
用户说明该视频应为《沧海一声笑》，只是弹得不好；工程侧不应被 6 半音远距离 D2 候选抢走。修复后挡掉远距离硬凑，保留近距离整体升半音候选，最终识别为 D4《沧海一声笑》（expectedDay=D4 时今日作业）。

修复后验证：

| 样本 | 旧结果 | 新结果 | 结论 |
| --- | --- | --- | --- |
| a4b39ceb…f09c.mp4 / 日志音序 | `D2 / 铁血丹心 / 整体移调6半音` | `D4 / 沧海一声笑 / 整体移调1半音 / 今日作业` | 通过 |

测试：
`mvn -f fc/pom.xml -pl Gemini-Api test -Dtest='PianoNoteSequenceTemplateMatcherTest,PianoHomeWorkVideoV2TaskTest'` → 64/64 通过。
