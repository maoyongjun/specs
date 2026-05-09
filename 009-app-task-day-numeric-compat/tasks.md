# 任务清单：AppTask day 数字入参兼容

**输入**：来自 `specs/009-app-task-day-numeric-compat/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过 `external-task` 模块单元测试验证。

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标文件为 `AppTask.java`、`DownTask.java` 和共享归一化类
- [x] T003 明确只兼容 `day` 的 `0` 到 `6` 数字字符串，不调整其他字段

## Phase 2：实现

- [x] T004 新增共享 `TaskDayNormalizer` 归一化逻辑
- [x] T005 在 `handleRequest` 入参校验前使用归一化后的 `day`
- [x] T006 在 `resolveTaskCandidates` 拼接任务配置 key 前使用归一化后的 `day`
- [x] T007 保持原有 `d0` 到 `d6` 输入兼容
- [x] T008 在 `DownTask` 入参校验前使用归一化后的 `day`

## Phase 3：测试

- [x] T009 添加单元测试覆盖共享归一化和数字 `0` 到 `6`
- [x] T010 运行 `external-task` 模块测试
- [x] T011 记录验证结果和剩余风险

## 执行记录

### D001 - 实现记录

- 新增 `TaskDayNormalizer.normalize`，将 `0` 到 `6` 转为 `d0` 到 `d6`。
- `AppTask` 和 `DownTask` 复用同一套归一化逻辑。
- `D0` 到 `D6` 也会归一化为小写 `d0` 到 `d6`，避免大小写导致配置 key 失配。
- 无效值保持原值，不新增默认任务分支。
- 新增单测 `shouldNormalizeTaskDayValues` 和 `shouldNormalizeNumericDayValuesFromZeroToSix`。
- 修正 `shouldUseInlineTestEnvironmentConfigForProvidedInput` 中未使用的 resolver 断言，并避免该单测访问远程配置 API。

### D002 - 验证记录

- 执行命令：`mvn -pl external-task -am '-Dtest=AppTaskTest' '-DskipTests=false' '-Dmaven.test.skip=false' '-Dsurefire.failIfNoSpecifiedTests=false' test`
- 执行结果：BUILD SUCCESS。
- 测试结果：`Tests run: 4, Failures: 0, Errors: 0, Skipped: 0`。
- 剩余风险：当前未新增会写 Redis 的 `DownTask` 集成测试；`DownTask` 的兼容性通过共享归一化类和代码调用保证。
