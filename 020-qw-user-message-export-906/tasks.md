# 任务清单：私聊聊天记录 CSV 导出

**输入**：来自 `specs/020-qw-user-message-export-906/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：当前阶段只验证 Spec Kit 文档存在且需求完整；后续实现阶段需要验证三账号范围、私聊过滤、群聊排除、不按 `chat_name` 前缀筛选和固定七列 CSV 输出，其中 `message_source` 保持原值、`isSelf` 按老师/学员转换，且 `union_id` / `timestamp` 可正确回填。

## Phase 1：规格与范围

- [x] T001 创建 `specs/020-qw-user-message-export-906` 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确当前阶段只编写文档，不修改业务代码
- [x] T003 明确后续目标是修改 `qw-user-message-export`
- [x] T004 明确账号范围仅限 `yangfan`、`LiYan`、`ZengYan`
- [x] T005 明确老师和用户双方消息都要导出，不做 `isSelf` 过滤
- [x] T006 明确排除群聊消息
- [x] T007 明确仅查询最近 15 天的聊天记录
- [x] T008 明确 `chat_name` 不做前缀过滤
- [x] T009 明确输出字段为 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text`
- [x] T010 明确输出列顺序固定且使用 CSV 表头与逗号分隔，且 `message_source` / `isSelf` / `union_id` / `timestamp` 语义清晰

## Phase 2：实现准备

- [ ] T011 确认后续导出项目中的账号映射方式，默认按 `qwUserId`
- [ ] T012 确认最近 15 天时间边界和时区口径
- [ ] T013 确认 `chat_name` 的字段来源
- [ ] T014 确认 `contact_name` 的字段来源
- [ ] T014a 确认 `union_id` 的字段来源和缺失处理策略
- [ ] T014b 确认 `timestamp` 的展示格式和时区口径
- [ ] T015 确认私聊/群聊判定字段与现有代码口径
- [ ] T016 确认是否需要去重或保留重复聊天记录
- [ ] T017 确认输出目录和 CSV 文件命名规则
- [ ] T018 确认空文本、空白文本、换行文本和 CSV 转义策略

## Phase 3：后续编码任务

- [ ] T019 在导出项目中增加三账号过滤逻辑
- [ ] T020 增加最近 15 天时间范围过滤逻辑
- [ ] T021 移除对 `isSelf` 的过滤依赖
- [ ] T022 增加群聊排除逻辑
- [ ] T023 移除 `chat_name` 前缀筛选逻辑
- [ ] T024 统一输出字段为 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text` 的 CSV 结构
- [ ] T025 实现分页查询，确保全量导出不漏数
- [ ] T026 实现文本单行化与 CSV 转义，避免换行或逗号破坏输出
- [ ] T027 保证输出顺序稳定且只包含目标列

## Phase 4：后续验证

- [ ] T028 验证只导出 `yangfan`、`LiYan`、`ZengYan`
- [ ] T029 验证最近 15 天以外的消息不被导出
- [ ] T030 验证老师和用户消息都被导出
- [ ] T031 验证群聊消息被排除
- [ ] T032 验证不同前缀的 `chat_name` 都能被导出
- [ ] T033 验证输出固定为七列 CSV 且包含表头
- [ ] T034 验证输出按 `message_source,isSelf,chat_name,contact_name,union_id,timestamp,text` 排列
- [ ] T035 验证 CSV 转义后仍可被正确解析
- [ ] T036 验证分页场景下不漏记录

## 执行记录

### D001 - 文档记录

- 已按用户要求在 `C:\workspace\ju-chat\specs` 下创建 Spec Kit 文档。
- 当前阶段未修改业务代码。
- 已记录三账号范围、私聊范围、群聊排除和 `chat_name` 不按前缀过滤的规则。
- 已记录最近 15 天的时间范围规则。
- 已记录输出字段固定为 `message_source`、`isSelf`、`chat_name`、`contact_name`、`union_id`、`timestamp`、`text`。
- 已记录输出格式采用 CSV 输出，其中 `message_source` 原样输出、`isSelf` 转换为老师/学员标签。
