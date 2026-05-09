# 功能规格：任务处理 day 数字入参兼容

**功能目录**: `009-app-task-day-numeric-compat`  
**创建日期**: 2026-05-09  
**状态**: Ready for Implementation  
**输入**: 用户要求 `C:\workspace\ju-chat\coze_plugin\external-task\src\main\java\com\drh\service\AppTask.java` 中参数 `day` 兼容 `0,1,2,3,4,5,6`，并转换成 `d0,d1,d2,d3,d4,d5,d6`；追加要求 `DownTask` 也需要同样兼容。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 数字 day 能匹配现有任务配置（优先级：P1）

调用方可能传入数字字符串 `0` 到 `6` 作为 `day`。系统需要在解析任务候选列表前将这些值转换为现有任务配置使用的 `d0` 到 `d6`，从而复用当前 `task_list_dN...` 配置。

**独立测试**：构造 `day=0` 到 `day=6` 的请求，调用候选任务解析逻辑，验证使用的是 `task_list_d0` 到 `task_list_d6` 对应配置。

**验收场景**：

1. **Given** 请求入参 `day` 为 `"0"`，**When** 解析任务候选列表，**Then** 系统按 `d0` 分支读取 `task_list` 和 `task_list_d0`。
2. **Given** 请求入参 `day` 为 `"1"` 到 `"6"`，**When** 解析任务候选列表，**Then** 系统按对应 `d1` 到 `d6` 分支读取任务配置。
3. **Given** 请求入参仍为 `"d0"` 到 `"d6"`，**When** 解析任务候选列表，**Then** 原有行为不变。

### 用户故事 2 - DownTask 使用同一套 day 归一化（优先级：P1）

调用方在完成任务下发缓存时也可能传入数字字符串 `0` 到 `6`。`DownTask` 需要在入参校验阶段使用同一套归一化逻辑，避免两个 handler 对 `day` 的兼容行为不一致。

**独立测试**：验证共享归一化工具将 `0` 到 `6` 转为 `d0` 到 `d6`，并确认 `DownTask` 调用该工具处理 `day`。

**验收场景**：

1. **Given** `DownTask` 请求入参 `day` 为 `"0"` 到 `"6"`，**When** handler 读取参数，**Then** 内部 `day` 值按对应 `d0` 到 `d6` 使用。
2. **Given** `DownTask` 请求入参 `day` 为 `"d0"` 到 `"d6"`，**When** handler 读取参数，**Then** 原有输入保持可用。

## 边界情况

- `day` 为空、空白或缺失时，保持不生成任务结果。
- `day` 为 `7`、`d7` 或其他非法值时，不映射到任何 `dN`，保持无候选任务行为。
- 归一化只影响 `day`，不改变 `task_class_session`、`class_session`、`pendpay`、`external_key`、`task_name` 等字段。
- 不修改配置中心、Redis、OTS 或外部 key 的语义。

## 需求 *(必填)*

- **FR-001**：系统 MUST 在 `C:\workspace\ju-chat\specs` 下创建本 Spec Kit 目录。
- **FR-002**：`AppTask` 和 `DownTask` MUST 将数字字符串 `0` 到 `6` 归一化为 `d0` 到 `d6`。
- **FR-003**：归一化 MUST 发生在任务候选配置 key 拼接前。
- **FR-004**：原有 `d0` 到 `d6` 输入 MUST 继续可用。
- **FR-005**：非法 `day` 值 MUST NOT 被错误映射为有效任务日。
- **FR-006**：单元测试 MUST 覆盖数字 `0` 到 `6` 的映射。
- **FR-007**：`AppTask` 和 `DownTask` MUST 复用同一套 `day` 归一化逻辑，避免行为分叉。

## 成功标准 *(必填)*

- **SC-001**：本目录包含 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`。
- **SC-002**：`day=0` 解析结果包含 `d0` 对应任务。
- **SC-003**：`day=1` 到 `day=6` 解析结果分别包含对应 `d1` 到 `d6` 任务。
- **SC-004**：现有 `d2` 相关单测继续通过。
- **SC-005**：共享归一化测试覆盖 `0`、`6`、`d2`、`D2`、非法值和空白值。
- **SC-006**：`external-task` 模块测试通过。

## 假设

- 调用方传入的是 JSON 字符串或可被 `JSONObject#getString("day")` 读取为字符串的数字值。
- 当前配置 key 已统一使用 `d0` 到 `d6` 形式。
- 本需求只处理 `AppTask` 和 `DownTask` 的 `day` 读取，不涉及上游入参协议变更。
