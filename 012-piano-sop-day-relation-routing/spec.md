# 功能规格：钢琴视频 Prompt 与 SOP 天数关系路由

**功能目录**: `012-piano-sop-day-relation-routing`  
**创建日期**: 2026-05-11  
**状态**: Implemented  
**输入**: 用户要求记录 `resolvePianoVideoPrompt` 中 `D%s` 改为 `D + logicalDay` 的改动，并新增 `SopReply` 针对 `sku=4` 钢琴作业的过去/未来作业路由规则。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 钢琴视频 Prompt 使用 D+logicalDay（优先级：P1）

钢琴视频识别的 prompt 模板中，`D%s` 表示作业天数占位。系统需要将它替换为 `D` 加 `logicalDay`，而不是把模板作为通用 `String.format` 模板处理。

**独立测试**：设置 `piano_video_prompt=请识别D%s钢琴作业`，构造 `logicalDay=2` 的作业消息，验证最终 prompt 为 `请识别D2钢琴作业`。

**验收场景**：

1. **Given** prompt 模板包含 `D%s` 且 `logicalDay=1`，**When** 解析钢琴视频 prompt，**Then** 输出包含 `D1`。
2. **Given** prompt 模板包含多个 `D%s` 且 `logicalDay=3`，**When** 解析钢琴视频 prompt，**Then** 每个 `D%s` 都替换为 `D3`。
3. **Given** prompt 模板不包含 `D%s`，**When** 解析钢琴视频 prompt，**Then** 保持原模板内容并打印未命中占位日志。

### 用户故事 2 - 钢琴过去作业按 recognizedDay 发送正常 SOP 点评（优先级：P1）

当 `sku=4` 的钢琴作业识别出实际歌曲天数 `recognizedDay` 小于当前逻辑天数 `currentDay` 时，系统应发送识别到的那一天的正常 SOP 点评。过去作业不再依赖 `homeworkDayRelation=PAST` 筛选，而是按 `homeworkDayRelation=CURRENT` 走普通当天作业配置。

**独立测试**：构造 `sku=4`、`currentDay=4`、识别结果 `recognizedDay=2`，验证配置路由使用 `day=2`，匹配参数使用 `homeworkDayRelation=CURRENT`，并打印钢琴过去作业覆写日志。

**验收场景**：

1. **Given** `sku=4` 且 `recognizedDay < currentDay`，**When** 发送 SOP 点评，**Then** 路由天数使用 `recognizedDay`，不是 `currentDay`。
2. **Given** `sku=4` 且 `recognizedDay < currentDay`，**When** 构造路由参数，**Then** `homeworkDayRelation` 使用 `CURRENT`，不使用 `PAST`。
3. **Given** 钢琴过去作业被处理，**When** 进入发送流程，**Then** 日志包含 `currentDay`、`recognizedDay`、实际路由天数和路由关系。

### 用户故事 3 - 钢琴未来作业发送固定预习话术且不计入点评进度（优先级：P1）

当 `sku=4` 的钢琴作业识别出 `recognizedDay` 大于 `currentDay` 时，系统不再依赖 `homeworkDayRelation=FUTURE` 筛选未来作业配置，而是直接发送固定话术。

固定话术：`预习的不错，上课跟着再好好学习指法，完善一下会更好`

**独立测试**：构造 `sku=4`、`currentDay=2`、识别结果 `recognizedDay=3`，验证不通过 `homeworkDayRelation=FUTURE` 选择 SOP 配置，直接发送固定话术，不写入点评进度、不打标签，并打印钢琴未来作业固定话术日志。

**验收场景**：

1. **Given** `sku=4` 且 `recognizedDay > currentDay`，**When** 发送 SOP 点评，**Then** 发送固定话术。
2. **Given** `sku=4` 且 `recognizedDay > currentDay`，**When** 构造或执行发送逻辑，**Then** 不依赖 `homeworkDayRelation=FUTURE` 匹配配置。
3. **Given** 钢琴未来作业固定话术发送成功，**When** 进入成功处理，**Then** 不调用点评进度持久化逻辑。
4. **Given** 钢琴未来作业固定话术发送成功，**When** 进入成功处理，**Then** 不调用打标签逻辑。
5. **Given** 钢琴未来作业被处理，**When** 进入固定话术分支，**Then** 日志包含 `currentDay`、`recognizedDay`、`submitDay`、`messageId` 和固定话术内容。

## 边界情况

- `logicalDay` 为空或 prompt 模板为空时，`resolvePianoVideoPrompt` 保持返回原模板。
- `D%s` 是钢琴视频 prompt 的业务占位；本需求不要求继续支持任意 `%s`、`%d` 或其他 `String.format` 占位。
- `recognizedDay` 非法或为空时，`SopReply` 沿用现有 `submitDay` 解析与回退逻辑。
- `sku` 不是 `4` 时，过去/未来作业关系仍沿用现有通用逻辑。
- `sku=4` 且 `recognizedDay == currentDay` 时，沿用当前作业的正常 SOP 路由。
- 固定预习话术需要遵守现有 `wxsend=false` 预览模式，不应在预览模式真实发送消息。
- 钢琴未来预习固定话术发送成功后，不计入点评进度，不打标签。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`PianoVideoHomeWorkHandleServiceImpl#resolvePianoVideoPrompt` MUST 将模板中的 `D%s` 替换为 `D` + `logicalDay`。
- **FR-003**：`D%s` 替换结果 MUST 为 `D1`、`D2` 等无额外符号的字符串。
- **FR-004**：`resolvePianoVideoPrompt` MUST 不再把整个 prompt 模板作为通用 `String.format` 模板处理。
- **FR-005**：`SopReply` MUST 只对 `sku=4` 应用本规格中的钢琴过去/未来作业特殊逻辑。
- **FR-006**：钢琴过去作业 MUST 以识别结果中的 `recognizedDay` 作为 SOP 路由天数。
- **FR-007**：钢琴过去作业 MUST 使用 `homeworkDayRelation=CURRENT` 进行路由参数匹配，不使用 `PAST`。
- **FR-008**：钢琴过去作业 MUST 打印包含 `currentDay`、`recognizedDay`、路由天数和路由关系的日志。
- **FR-009**：钢琴未来作业 MUST 不通过 `homeworkDayRelation=FUTURE` 筛选配置。
- **FR-010**：钢琴未来作业 MUST 发送固定话术 `预习的不错，上课跟着再好好学习指法，完善一下会更好`。
- **FR-011**：钢琴未来作业 MUST 打印包含 `currentDay`、`recognizedDay`、`submitDay`、`messageId` 和固定话术内容的日志。
- **FR-012**：钢琴未来作业固定话术发送成功后 MUST NOT 计入点评进度。
- **FR-013**：钢琴未来作业固定话术发送成功后 MUST NOT 执行打标签。
- **FR-014**：钢琴当前作业、非钢琴作业和识别未通过的作业 MUST 保持现有行为。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：`logicalDay=2` 且模板含 `D%s` 时，钢琴视频 prompt 输出 `D2`。
- **SC-003**：`sku=4`、`currentDay=4`、`recognizedDay=2` 时，SOP 路由使用 `day=2` 且 `homeworkDayRelation=CURRENT`。
- **SC-004**：`sku=4`、`currentDay=2`、`recognizedDay=3` 时，发送固定预习话术，不通过 FUTURE 配置分支，不写点评进度，不打标签。
- **SC-005**：过去作业和未来作业两个钢琴特殊分支均有可检索日志。
- **SC-006**：`fc/sop-reply` 模块编译通过。

## 假设

- `HomeWorkResultDto#getId()` 表示识别到的实际歌曲天数，可归一化为 `recognizedDay`。
- `resolveSkuId` 现有逻辑可继续作为 `sku=4` 钢琴判断来源。
- 钢琴未来作业固定话术视为一次成功 SOP 回复，仅回填识别结果；点评进度和打标签不沿用通用成功发送流程。
- `SopReply.java` 已按本规格实现钢琴过去/未来作业特殊逻辑。
