# 规格执行说明

本目录记录 `P1级接口安全整改清单.csv` 中接口与影响数据库表的整理结果。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\072-p1-interface-security-table-impact`
- CSV 输入：`C:\Users\EDY\OneDrive\Desktop\P1级接口安全整改清单.csv`
- 目标项目：`C:\workspace\ju-chat\kkhc`、`C:\workspace\drh`
- 相关模块：`kkhc-idc app/lms/ai`、`kkhc-bizcenter app`、`drh-kk-cms`、`drh-media-process`

## 当前目标

- 整理 CSV 中 13 条非空接口整改项。
- 形成接口到数据库表、手机号字段和当前代码状态的矩阵。
- 区分 CSV 原始待修改点、当前代码静态状态和后续验证要点。

## 执行原则

- 本规格只创建文档，不修改业务代码、不新增 DDL、不执行回填。
- CSV 备注只能作为输入线索，最终状态以当前代码静态搜索结果为准。
- 已在当前代码中出现 `phoneMd5`、`phone_mask` 或 `phone_md5` 的接口，不能继续简单标记为未整改，必须记录为已部分整改或需复核。
- 对仍按 `phone`、`getPhone`、`reciver_phone` 查询或返回的入口，必须记录影响表、字段方向和验证要点。
- 非 HTTP 链路单独标记为风险，不并入 HTTP 接口矩阵的必改入口。

## 强制门禁

- 每条 CSV 非空记录必须落到矩阵或非 HTTP 风险小节。
- 每个矩阵项必须写清楚影响表和手机号字段方向。
- 每个当前状态必须有静态搜索证据或引用既有规格来源。
- 不允许在本目录内生成 SQL、回填脚本或业务代码补丁。

## 重点代码位置

- `kkhc/kkhc-idc/app|lms|ai/src/main/java`
- `kkhc/kkhc-idc/lms-common|ai-common/src/main/java`
- `kkhc/kkhc-bizcenter/app/src/main/java`
- `C:\workspace\drh\drh-kk-cms\src\main`
- `C:\workspace\drh\drh-media-process\src\main`

## 文档维护

- `spec.md` 描述接口矩阵、表聚合视图、当前代码状态和验收标准。
- `tasks.md` 记录静态核对、文档创建和后续验证任务。
- `checklists/requirements.md` 用于确认本规格无模板占位符、无实现扩散、无未记录风险。
