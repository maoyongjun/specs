# 规格执行说明

本目录记录 `zhangkai` 声乐作业点评配置同步、新增和验证过程。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\043-homework-config-zhangkai-vocal`
- 目标服务：`C:\workspace\ju-chat\data-RC\juzi-service`
- 运行接口：`http://localhost:9011`
- 相关模块：作业点评配置页、`HomeworkConfigAdminController`、`HomeworkConfigService`
- 相关表：`drh_ai_config_homework_strategy`、`drh_ai_config_homework_action`、`drh_ai_config_homework_route`

## 当前目标

- 将正式只读库中的作业点评配置三表同步到测试库，测试库原三表配置先清理再导入。
- 生成 Day1-Day6 第二次点评克隆语音，保存到 `C:\workspace\homework_file\kelong`。
- 为声乐 `skuId=5`、企业微信 id `zhangkai` 新增专属作业点评策略、动作、路由。
- 生成本次新增配置的 SQL，且不包含正式到测试的全量同步数据。

## 执行原则

- 不把数据库密码、TTS key、token 写入本目录文档或 SQL。
- 只操作作业点评配置三张表，不处理其他模块配置。
- 新增路由必须同时限定 `skuId=5`、`homeworkDayRelation`、`qwUserId_RLike=zhangkai`，避免影响已有默认配置。
- 空策略表示 SOP 不自动回复，由人工处理。
- 所有通过接口创建的策略、动作、路由，必须在执行记录里保留可复核的返回 id 或校验摘要。

## 重点代码位置

- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\controller\admin\HomeworkConfigAdminController.java`
- `C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\homeworkconfig\service\HomeworkConfigService.java`
- `C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\sop\SopConfigSender.java`
- `C:\workspace\ju-chat\tts_http_demo\src\main\java\com\bytedance\tts\demo\tts_http_demo.py`

## 文档维护

- `spec.md` 描述业务目标、配置口径、边界和验收标准。
- `tasks.md` 记录事实确认、执行步骤、验证结果和纠正记录。
- `checklists/requirements.md` 记录规格质量和参数完整性门禁。
- `zhangkai-homework-config-added.sql` 只记录本次新增配置 SQL。
