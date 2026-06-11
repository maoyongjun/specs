# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\070-living-finish-tag-missing-analysis`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast`
- 相关模块：直播观看进度保存、完课状态计算、企微标签 MQ 发送

## 当前目标

- 分析 `LivingStudyInfoRecordServiceImpl#doSave` 为什么没有触发完课标签。
- 用用户提供的 `2026-06-09 21:39:08` 日志还原代码分支。
- 给出数据库复核 SQL 和后续修复/补偿建议。

## 执行原则

- 本阶段只做排查文档，不修改业务代码。
- 结论必须区分日志已证明事实、代码推导和需要数据库确认的事实。
- 不把 `drh_live_camp_date` 查询失败误判为完课标签失败原因；该查询属于华彩豆展示/奖励前置。
- 完课标签以 `worksProducerBean.doSendQwTag(userId, liveId, MqDayEnum.finish)` 是否执行为准。

## 强制门禁

- 参数来源：`campId/liveId` 来自加密 `room` 头解析，`userId/seconds/degree/sliceId/studySource` 来自请求体。
- 状态门禁：只有 `status == 2` 且进入普通更新分支时才发送完课标签。
- 兼容分支：当前已完课、或 `LiveInfo.length` 为空/0 时，代码只更新观看时长等字段，不发送完课标签。
- 日志门禁：提供的日志只出现 `SLS_ASYNC` MQ 和不带 `status` 的 `drh_living_study_info` 更新 SQL，未出现 `QW_TAG` 或“完课-打标签完成”日志。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\controller\LivingController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\controller\BaseController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\service\impl\LivingStudyInfoRecordServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\mq\producer\WorksProducerBean.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\service\impl\LiveCampDateServiceImpl.java`

## 文档维护

- `spec.md` 记录问题、证据、结论、复核 SQL 和修复建议。
- `tasks.md` 记录代码事实确认、风险门禁和验证记录。
- `checklists/requirements.md` 记录规格完整性和参数完整性检查。
