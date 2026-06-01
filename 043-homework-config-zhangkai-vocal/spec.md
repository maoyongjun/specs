# 功能规格：zhangkai 声乐作业点评配置

**功能目录**：`043-homework-config-zhangkai-vocal`  
**创建日期**：`2026-06-01`  
**状态**：Draft  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档。先将正式环境作业点评配置三表同步到测试环境，并清理测试环境原作业点评配置。按 `C:\workspace\homework_file\点评说明.txt` 生成需要克隆的语音，输出到 `C:\workspace\homework_file\kelong`。通过 `localhost:9011` 测试环境接口维护声乐 `skuId=5`、企业微信 id `zhangkai` 的作业点评配置，并生成本次新增 SQL。第三次有明确文本则文本回复，Day5/Day6 第三次人工回复，第四次及以上全部人工回复；过去和未来作业先配置空策略。

## 背景

- 当前问题：测试库作业点评配置需要先与正式只读库对齐，再新增 `zhangkai` 专属声乐 SOP 点评配置。
- 当前行为：测试环境已有作业点评配置，但可能与正式不一致；`点评说明.txt` 中新增配置尚未维护到测试环境。
- 目标行为：测试环境三表先按正式库重建，再通过配置页接口新增 `zhangkai` 专属策略和路由；新增配置只命中 `zhangkai`，不影响其他企业微信 id。
- 非目标：不修改作业点评服务代码，不新增表结构，不改其他模块配置，不把全量同步数据混入本次新增 SQL。

## 用户场景与测试

### 用户故事 1 - 测试配置与正式配置对齐（优先级：P1）

测试环境作业点评配置需要以正式只读库为基线，避免在旧测试数据上叠加配置。

**独立测试**：同步后分别统计三张表行数，确认测试库与正式只读库一致。

**验收场景**：

1. **Given** 正式只读库三张配置表可访问，**When** 执行同步，**Then** 测试库三张配置表与正式库行数一致。
2. **Given** 测试库存在旧配置，**When** 同步开始，**Then** 仅清理并重建作业点评配置三表。

### 用户故事 2 - zhangkai 当前作业自动点评（优先级：P1）

企业微信 id 为 `zhangkai` 的声乐作业，需要按说明文件配置第 1、2、3 次回复，第 4 次及以上交给人工处理。

**独立测试**：调用配置查询接口，分别验证 Day1-Day6 的当前作业路由命中新增策略。

**验收场景**：

1. **Given** `skuId=5`、`homeworkDayRelation=CURRENT`、`qwUserId_RLike=zhangkai`，**When** 第 1 次提交 Day1-Day6 作业，**Then** 命中文字 + 对应现有语音策略。
2. **Given** 同样匹配参数，**When** 第 2 次提交 Day1-Day6 作业，**Then** 命中文字 + 对应克隆语音策略。
3. **Given** 同样匹配参数，**When** 第 3 次提交 Day1-Day4 作业，**Then** 命中说明文件中明确的第三次文本策略。
4. **Given** 同样匹配参数，**When** Day5 或 Day6 第 3 次、或任意 Day 第 4 次及以上，**Then** 命中空策略，SOP 不自动回复。

### 用户故事 3 - 过去/未来作业先人工处理（优先级：P1）

`zhangkai` 的过去作业和未来作业当前不配置自动话术，后续有文字和语音后再补。

**独立测试**：带 `homeworkDayRelation=PAST` 或 `FUTURE` 查询配置，确认命中空策略。

**验收场景**：

1. **Given** `homeworkDayRelation=PAST` 且 `qwUserId_RLike=zhangkai`，**When** 任意 Day 作业匹配，**Then** 命中空策略。
2. **Given** `homeworkDayRelation=FUTURE` 且 `qwUserId_RLike=zhangkai`，**When** 任意 Day 作业匹配，**Then** 命中空策略。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `skuId=5`：来源于代码 `SkuIdEnum.VOCAL_MUSIC`，接口创建 strategy 和 route 时显式传入。
  - `qwUserId_RLike=zhangkai`：来源于用户需求，route `matchKey/matchValue` 写入，SOP 下游按企业微信 id 包含匹配。
  - `homeworkDayRelation`：来源于 `SopReply.resolveRouteParams` 自动参数，route 中区分 `CURRENT`、`PAST`、`FUTURE`。
  - `commentIndex`：来源于 SOP 点评次数，route 中第 1、2、3 次使用 `EQ` 或 `GTE`。
  - `materialUrl`、`ossUrl`、`voiceDurationMillis`：来源于配置接口上传文件后的返回结果，再用于生成新增 SQL。
- 下游读取字段清单：
  - `HomeworkConfigService.bindRoute` 读取 `day`、`commentIndex`、`commentMatchType`、`matchKey`、`matchValue`、`skuId`、`strategyId`。
  - `SopConfigSender.selectMatchedRoute` 读取 route 的 `day`、`commentIndex`、`commentMatchType`、`matchKey`、`matchValue`、`skuId`。
  - `SopConfigSender.sendSingleAction` 读取 action 的 `type`、`textContent`、`materialUrl`、`voiceDurationMillis`、`delayMillis`。
- 空对象 / 占位对象风险：
  - 空策略是明确业务语义：匹配后 actions 为空，`sendByConfigAndCount` 返回 0，用于人工回复，不是误传占位对象。
- 调用顺序风险：
  - 必须先创建 strategy，再创建 action，最后 bind route；route 不允许绑定不存在的 strategy。
  - 必须先生成并核查语音文件，再上传创建 VOICE action。
- 旧逻辑保持：
  - 不修改默认声乐配置、不修改钢琴配置、不修改其他企业微信 id 的 action 条件。
  - 新增 route 必须比旧默认 route 更具体，且仅在 `zhangkai` 命中。
  - `PAST`、`FUTURE` 仅对 `zhangkai` 用空策略兜住，不改变其他用户的过去/未来作业逻辑。
- 需要用户确认的设计选择：
  - Day6 第 3 次说明文件未给文本，已确认按人工回复空策略处理。

## 边界情况

- 如果正式只读库导出失败，不允许清理测试库。
- 如果任一克隆语音生成失败，不继续创建对应 VOICE action。
- 如果 `localhost:9011` 接口返回非 2xx，不写新增 SQL，先记录失败。
- 如果已有同名 `zhangkai` 策略或 route，执行前应识别并避免重复新增；必要时以执行记录说明处理方式。
- 第 4 次及以上必须被空策略覆盖，不能落回旧默认 `GTE=3` 或其他通用策略。

## 需求

### 功能需求

- **FR-001**：系统 MUST 将正式只读库三张作业点评配置表同步到测试库。
- **FR-002**：系统 MUST 生成 Day1-Day6 第二次点评克隆语音，并保存到 `C:\workspace\homework_file\kelong`。
- **FR-003**：系统 MUST 为 `skuId=5`、`qwUserId_RLike=zhangkai` 配置当前作业第 1、2 次文字 + 语音回复。
- **FR-004**：系统 MUST 为 Day1-Day4 第 3 次配置明确文本回复。
- **FR-005**：系统 MUST 为 Day5/Day6 第 3 次、Day1-Day6 第 4 次及以上配置空策略。
- **FR-006**：系统 MUST 为 Day1-Day6 的 `PAST`、`FUTURE` 作业配置空策略。
- **FR-007**：系统 MUST 生成只包含本次新增配置的 SQL。
- **FR-008**：系统 MUST NOT 修改非作业点评三表或其他企业微信 id 的现有配置。

## 成功标准

- **SC-001**：测试库三张作业点评配置表与正式只读库行数一致。
- **SC-002**：`C:\workspace\homework_file\kelong` 下存在 6 个非空 mp3 文件。
- **SC-003**：`GET /api/homework-config/config?skuId=5` 返回的 routes 中包含 `zhangkai` 专属 `CURRENT`、`PAST`、`FUTURE` route。
- **SC-004**：Day1-Day6 第 4 次及以上对 `zhangkai` 命中空策略。
- **SC-005**：新增 SQL 仅包含本次 `zhangkai` 的 strategy/action/route。

## 假设

- `skuId=5` 表示声乐。
- `qwUserId_RLike` 匹配企业微信 id，值 `zhangkai` 可命中目标老师账号。
- 空策略表示 SOP 不自动回复，由人工处理。
- 本次新增 SQL 不包含正式到测试的全量同步数据。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成接口、表、参数来源、下游读取字段和边界情况梳理。
- 本阶段未记录任何数据库密码或 TTS key。

### D002 - 实现记录

- `<执行后填写：三表同步、语音生成、接口新增配置、SQL 生成和验证结果。>`

### D003 - 纠正记录模板

- 触发原因：`<用户补充 / 测试失败 / 接口返回异常 / 参数遗漏>`
- 修正内容：`<写清楚旧口径和新口径>`
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`
- 验证结果：`<测试或静态验证结果>`
