# 规格执行说明

本目录记录 `external-info-select` 返回 `speaker_name` 的需求、实现任务和验证结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\062-external-info-select-speaker-name`
- 目标项目：
  - `C:\workspace\ju-chat\coze_plugin\external-info-select`
  - `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 相关模块：
  - FC/Coze 插件：`com.drh.select.service.AppTask`
  - 插件中心接口封装：`com.drh.select.util.CenterUtil`
  - idc-ai 内部接口：`com.kkhc.idc.crm.controller.AiController`
  - idc-ai 服务层：`com.kkhc.idc.crm.service.ai.AiService`、`AiServiceImpl`

## 当前目标

- 在 legacy `external_key` 流程中，根据 `camp_date_id` 查询营期 `speakerId`。
- 根据 `speakerId` 查询 `drh_speaker.name`，并在最终返回 JSON 中追加 `speaker_name`。
- 对成功查询到的 `speakerId -> name` 在 `external-info-select` 侧做 6 小时 JVM 本地缓存。
- 在 `idc-ai` 增加读取 `drh_speaker` 的内部接口。

## 执行原则

- 先读代码，再定方案，后实现。
- 不改变 `private-domain` 流程。
- 不新增数据库表、不改 MQ、不改 Redis key、不改变已有字段语义。
- `speaker_name` 查询失败、缺失或参数非法时只记录日志并跳过字段，不影响原返回。
- 远程调用必须使用已有 `sys_domain` 和内部 token 风格。
- 只缓存成功查到的非空 speaker name；空值和失败不缓存。
- 单元测试避免真实访问 Redis、OTS、Center 或外部 HTTP。

## 强制门禁

实现前必须确认：

- `camp_date_id` 来源：legacy `external_key` 第 3 段，在 `AppTask.handleRequest` 进入 Coze JSON 生成前已解析。
- `speakerId` 来源：`idc-ai /ai/getCampInfoByCampDateId` 返回的 `LiveCampDateDO.speakerId`。
- `speaker_name` 来源：新增 `idc-ai /ai/getSpeakerInfoBySpeakerId` 返回的 `SpeakerDO.name`。
- 下游读取：Coze 调用方读取最终 JSON 的 `speaker_name` 字段。
- 旧逻辑保持：`DayEnum.createCozeJson` 的字段白名单、敏感词、转账金额、图书物流、设备信息和 `day` 字符串转换逻辑不改。

## 重点代码位置

- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\util\CenterUtil.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\controller\AiController.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\AiService.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`

## 文档维护

- `spec.md` 描述目标、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务和验证记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
