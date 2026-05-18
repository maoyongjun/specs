# 任务清单：AI 上线接口凌晨时段配置校验

**输入**：来自 `specs/018-ai-dawn-time-window-validation/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过代码检查或目标模块构建验证四个上线入口在非法时间段下被正确拦截。

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标接口为 `AiController` 的 `on`、`onV2`、`batchOn`、`batchOnV2`
- [x] T003 明确凌晨时段规则、工作时间段 `7:00-23:00` 以及 `50%` 占比门槛

## Phase 2：实现

- [x] T004 在四个上线入口前增加凌晨时段配置校验
- [x] T005 复用或对齐现有时间区间语义，确保跨天判断与参考逻辑一致
- [x] T006 为非法配置返回包含“配置时间不正确”和具体凌晨时段的错误提示
- [x] T007 保证合法配置不影响原有上线流程

## Phase 3：验证

- [x] T008 验证 `[1:00-6:00]` 这类纯凌晨配置会被拦截
- [x] T009 验证工作时间占比小于 `50%` 的配置会被拦截
- [x] T010 验证工作时间占比达到 `50%` 及以上的配置不会被误拦截
- [x] T011 记录验证结果和剩余风险
