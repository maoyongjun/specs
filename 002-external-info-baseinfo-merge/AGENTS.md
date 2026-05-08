# 规格执行说明

本目录记录 `002-external-info-baseinfo-merge` 功能规格，作用范围仅限当前规格目录及其子目录。

## 当前阶段

- 本阶段已建立 Spec Kit 文档并生成 `tasks.md`。
- 用户明确要求不编码；任务清单只用于后续实现安排。
- 当前目录应包含 `AGENTS.md`、`spec.md`、`tasks.md` 和 `checklists/requirements.md`。

## 后续实现约束

- 目标改动模块为 `C:\workspace\ju-chat\data-RC\juzi-service`。
- 新增公开接口 `POST /api/external-info/baseInfo`，不新增 admin 页面。
- 请求体只要求 `external_key`，并将同一个 key 原样传给两个 FC。
- 测试环境按 `mq.juzi_tag == "test"` 判断，调用 `ai-service/external-select-test` 和 `ai-service/external-profile`。
- 非测试环境调用 `ai-service/external-select` 和 `ai-service/prod-external-profile`。
- 后续实现优先沿用现有 `BaseResponse`、`FcInvokeInput`、`FcInvokeUtils.doSyncTaskReturnJSONObj` 和 controller/service 分层风格。
- 两个 FC 需要并发同步调用，汇总后再返回接口响应。
- 合并时先放入 profile 返回字段，再放入 external-select 返回字段；同名字段以 external-select 为准。
- 单边失败时返回成功函数数据，并通过 `data._fc_errors` 标记失败来源、函数名和错误信息。
- 两边都失败或 `external_key` 为空时返回业务错误。
- juzi-service 不解释、不过滤、不转换 FC 业务字段，只负责调用、合并和失败标记。

## 文档维护

- `spec.md` 描述用户场景、功能需求、边界情况和成功标准。
- `checklists/requirements.md` 用于进入计划或实现前的规格质量检查。
- 如后续需求变化，先更新 `spec.md`，再同步检查清单状态。
- 如后续需求变化，先更新 `spec.md`，再同步 `tasks.md` 与检查清单。
