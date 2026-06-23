# 功能规格：雅琪钢琴作业点评配置同步与绑定

**功能目录**：`108-yaqi-piano-homework-config`  
**创建日期**：`2026-06-23`  
**状态**：Completed  
**输入**：将正式环境作业点评配置三表同步到测试环境；只操作 `drh_ai_config_homework_strategy`、`drh_ai_config_homework_action`、`drh_ai_config_homework_route`。将原钢琴配置归属李瑶 `speakerId=110`，并基于 `C:\workspace\homework_yaqi` 为雅琪 `speakerId=113` 新建 D1-D4 钢琴作业点评策略、动作和路由。

## 背景

- 当前问题：测试环境作业点评三表和正式环境存在差异，且雅琪钢琴作业点评素材尚未配置到测试环境。
- 当前行为：测试环境 `skuId=4` 钢琴 route 仍使用 `homeworkDayRelation` 单条件，例如 `day4-1-prod` 只区分 `CURRENT`，未按 `speakerId` 区分李瑶和雅琪。
- 目标行为：测试三表先与正式环境对齐；原钢琴 route 改为 `speakerId=110`；新增雅琪 D1-D4 当前作业第 1 次点评 route，按 `speakerId=113` 命中。
- 非目标：不改业务代码、不改接口、不新增表结构、不操作其他模板表或非作业点评表，不对生产库执行写入。

## 用户场景与测试

### 用户故事 1 - 测试环境三表对齐正式环境（优先级：P1）

测试环境作业点评配置需要先以正式环境为基线，避免在过期测试数据上叠加雅琪配置。

**独立测试**：同步前后分别统计正式和测试三表 enabled/total 行数。

**验收场景**：

1. **Given** 正式库三表可读，**When** 执行测试库同步，**Then** 测试库三表行数与正式库一致。
2. **Given** 测试库原三表已有数据，**When** 同步前，**Then** 先导出测试三表备份和正式三表快照。

### 用户故事 2 - 原钢琴配置归属李瑶（优先级：P1）

原有钢琴作业点评 route 应继续服务李瑶老师，不被雅琪新增配置覆盖。

**独立测试**：查询 `skuId=4` route，确认原 route 的 `matchKey/matchValue` 已包含 `speakerId=110`。

**验收场景**：

1. **Given** 原 route 为 `homeworkDayRelation=CURRENT`，**When** 执行归属更新，**Then** 变为 `currentDay&&homeworkDayRelation&&speakerId=<day>&&CURRENT&&110`。
2. **Given** `speakerId=110` 的运行时参数，**When** 匹配原钢琴 route，**Then** 仍命中原 `dayX-...` strategy。

### 用户故事 3 - 雅琪 D1-D4 作业点评命中（优先级：P1）

雅琪 `speakerId=113` 的钢琴 D1-D4 当前作业第 1 次点评，应按素材目录顺序发送内容。

**独立测试**：通过测试接口和 `SopConfigSender` 兼容逻辑验证 `speakerId=113` 命中新建 route。

**验收场景**：

1. **Given** `speakerId=113`、`currentDay=1`、`homeworkDayRelation=CURRENT`，**When** `question=节奏有问题/翘指/折指`，**Then** 只发送 D1 对应问题分组的 actions。
2. **Given** `speakerId=113`、`currentDay=2..4`、`homeworkDayRelation=CURRENT`，**When** 第 1 次点评，**Then** 按 D2-D4 文件序号发送通用 actions。
3. **Given** `speakerId` 不是 113，**When** 匹配雅琪 route，**Then** 不命中雅琪配置。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `skuId=4`：来源用户需求和 `SkuIdEnum` 既有口径；创建 strategy、bind route 时显式传入。
  - `speakerId=110/113`：来源用户指定；route `matchValue` 写入，运行时由 `juzi-service`/`sop-reply` 已补齐为 String。
  - `currentDay`：route 绑定时用表字段 `day_num` 或素材目录 D 编号写入；运行时由 `SopReply.resolveRouteParams` 提供。
  - `homeworkDayRelation`：原 route 的 `matchValue` 或新增固定 `CURRENT`；运行时由 SOP 自动参数提供。
  - `question`：识别结果 `question1~question4` 拼接后写入 `HomeWorkResultDto.question`；action 条件按目录名匹配。
  - `orderIndex`：来源文件名 `_1/_2/_3...`；接口创建 action 时显式传入。
  - `VIDEO_CHANNEL`：来源文件名后缀 `_Vxx`；接口字段为 `videoChannelCode=Vxx`，不上传空 txt。
- 下游读取字段清单：
  - `HomeworkConfigService.bindRoute` 读取 `day`、`commentIndex`、`commentMatchType`、`strategyId`、`matchKey`、`matchValue`、`skuId`。
  - `HomeworkConfigService.addAction` 读取 `type`、`orderIndex`、`textContent`、`videoChannelCode`、`conditionKey`、`conditionValue`、`file`。
  - `SopConfigSender.selectMatchedRoute` 读取 route 的 `day`、`commentIndex`、`commentMatchType`、`matchKey`、`matchValue`、`skuId`。
  - `SopConfigSender.selectMatchedActions` 读取 action 的 `conditionKey`、`conditionValue`、`orderIndex`、`type` 和素材 URL。
- 空对象 / 占位对象风险：
  - `_Vxx.txt` 是视频号占位文件，不能作为 TEXT 或文件上传；必须映射为 `VIDEO_CHANNEL`。
  - D1 下每个 question 分组都必须有条件，否则多个问题分组会混发。
- 调用顺序风险：
  - 必须先同步三表，再更新李瑶 route，再创建雅琪 strategy/action，最后绑定雅琪 route。
  - 必须先上传文件生成 material URL，再写 action 记录。
  - 必须创建 strategy 后才能 bind route。
- 旧逻辑保持：
  - 不修改非 `skuId=4` route 的 speaker 归属。
  - 不修改声乐、模板、AI route、私域、MQ、Redis 和代码逻辑。
  - 原钢琴配置保留原 strategy 和 actions，仅通过 route 条件限定到 `speakerId=110`。
- 需要用户确认的设计选择：
  - 已通过用户“PLEASE IMPLEMENT THIS PLAN”确认：全量覆盖测试三表、D1 question 使用目录原值、允许写测试库和调用测试接口。

## 边界情况

- 如果正式库导出失败，不执行测试库覆盖。
- 如果测试库备份失败，不执行测试库覆盖。
- 如果任一文件上传失败，不绑定对应雅琪 route。
- 如果测试环境已有 `yaqi-piano-day*-comment1` 或 `speakerId=113` 雅琪 route，脚本先停止，避免重复新增。
- 如果识别结果只输出 `手型有问题` 而非 `翘指/折指`，本次按计划不兼容，后续再补归并或双条件。

## 需求

### 功能需求

- **FR-001**：系统 MUST 备份测试环境三张作业点评配置表。
- **FR-002**：系统 MUST 从正式环境导出三表快照，并全量覆盖测试环境三表。
- **FR-003**：系统 MUST 只写测试库 `dev-mysql`，生产库只读。
- **FR-004**：系统 MUST 将测试环境原启用 `skuId=4` route 改为包含 `speakerId=110` 的组合条件。
- **FR-005**：系统 MUST 为雅琪 `speakerId=113` 新建 D1-D4 当前作业第 1 次点评配置。
- **FR-006**：系统 MUST 按文件名序号设置 action `orderIndex`，按扩展名和 `_Vxx` 后缀选择 action 类型。
- **FR-007**：系统 MUST NOT 操作其他模板表、业务表或非作业点评三表。

## 成功标准

- **SC-001**：同步后测试三表行数与正式三表行数一致。
- **SC-002**：原 `skuId=4` route 全部限定 `speakerId=110`。
- **SC-003**：测试接口返回 `yaqi-piano-day1-comment1` 到 `yaqi-piano-day4-comment1`。
- **SC-004**：`speakerId=113` 命中雅琪 route，`speakerId=110` 命中原李瑶 route。
- **SC-005**：执行产物包含备份、同步 SQL、接口创建记录、验证摘要。

## 假设

- `speakerId=110` 是李瑶，`speakerId=113` 是雅琪。
- `skuId=4` 表示钢琴。
- `C:\workspace\homework_yaqi` 中 D1-D4 是本次唯一需要新增的雅琪素材。
- 文件名中的 `_1/_2/_3` 是发送顺序，不是点评次数。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成表名、接口、字段来源、调用顺序和验证口径确认。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 数据库同步：已备份测试三表并导出正式三表快照；测试三表已全量覆盖为正式环境数据。同步后测试三表计数为 strategy `80`、action `316`、route `73`。
- 代码部署：本地 `data-RC/master` 原先超前远端 2 个提交（speakerId 透传、`VIDEO_CHANNEL` 动作支持），已推送到远端 `master`；测试接口探测 `VIDEO_CHANNEL` 创建成功。
- route 更新：原启用 `skuId=4` 钢琴 route 更新 14 条，均为 `currentDay&&homeworkDayRelation&&speakerId`，且旧配置全部以 `&&110` 结尾。
- 雅琪创建：通过测试接口创建 `yaqi-piano-day1-comment1` 至 `yaqi-piano-day4-comment1`，strategy id `87/88/89/90`，route id `125/126/127/128`，action id `359-386`。
- 最终验证：`HomeworkConfigServiceVideoChannelTest` 通过 `2` 项；`piano-speaker-summary.json` 为旧 route `14`、雅琪 route `4`、旧 speaker 违规 `0`、雅琪 speaker 违规 `0`；`verification-summary.json` 确认 D1 三个 question 分组和 D2-D4 顺序均符合预期。

### D003 - 正式同步准备记录

- 用户要求：将数据同步到正式环境。
- 生产前置检查：`https://api.opensplendid.cn/juzi-service/homework-config.html?key=drh20262026` 返回页面中未包含 `VIDEO_CHANNEL`；测试环境同页已包含 `VIDEO_CHANNEL`。据此判断正式 `juzi-service` 尚未部署本次 `VIDEO_CHANNEL` 配置代码。
- 发布权限检查：Jenkins API 返回 `403 Authentication required`；SSH 到 Jenkins 服务器 `root@60.205.247.168` 返回 `Permission denied`，当前会话无法完成正式代码部署。
- 已完成准备：导出正式当前三表快照到 `out/prod-before-yaqi-sync-*.json`，生成正式增量 SQL `sql/prod-sync-yaqi-piano-config.sql` 和回滚 SQL `sql/rollback-prod-yaqi-piano-config.sql`，并完成 `db_skill.py analyze`。
- 风险结论：未执行正式写库。原因是正式代码未支持 `VIDEO_CHANNEL`/speakerId 路由前，直接写入正式数据可能导致配置接口或 SOP 运行时异常。

### D004 - 正式同步执行记录

- 触发：用户确认“现在正式库已部署了，同步到正式环境”。
- 部署确认：正式 `https://api.opensplendid.cn/juzi-service/homework-config.html?key=drh20262026` 已包含 `VIDEO_CHANNEL`。
- 写库执行：使用 `prod-mysql` 执行 `sql/prod-sync-yaqi-piano-config.sql`，带 `--allow-write` 和确认文本；影响行数 `50`。
- 写入结果：雅琪启用 strategy `4` 条、action `28` 条、route `4` 条；正式三表最终 enabled/total 计数为 strategy `79/84`、action `219/344`、route `77/77`。
- 验证结果：`prod-piano-speaker-summary-after-final-sync.json` 显示旧钢琴 route `14` 条、雅琪 route `4` 条，旧 speaker 违规 `0`、雅琪 speaker 违规 `0`；正式接口 `GET /admin/homework-config/config?skuId=4` 返回 200，`prod-verification-summary.json` 验证李瑶 `110` 命中旧配置、雅琪 `113` 命中 D1-D4 新配置、其他 speaker 不命中。
