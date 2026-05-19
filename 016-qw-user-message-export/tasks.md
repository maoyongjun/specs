# 任务清单：企微用户近三个月消息导出与 5 月 8 日以来开口率统计

**输入**：来自 `specs/016-qw-user-message-export/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：当前阶段只验证 Spec Kit 文档存在且需求完整；后续实现阶段需要验证 `userIds.txt` 读取、OTS 查询、payload 解析、txt 输出、10MB 文件切分和异常续跑能力。  

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确当前阶段只编写文档，不修改业务代码
- [x] T003 明确后续目标是创建一个可运行的消息导出项目或模块
- [x] T004 明确输入文件为项目目录下的 `userIds.txt`
- [x] T005 明确 `userIds.txt` 每行一个 `qwUserId`
- [x] T006 明确导出时间范围为最近三个月
- [x] T007 明确使用 OTS `timestamp` 字段筛选时间范围
- [x] T008 明确只导出用户发送的消息，即 `isSelf=false`
- [x] T009 明确目标消息类型为 `type in (2, 7)`
- [x] T010 明确从 `payload` JSON 中解析 `text` 字段
- [x] T011 明确每条消息写入 `txt` 一行
- [x] T012 明确单个输出文件达到或即将超过 10MB 时切换新文件
- [x] T013 明确查询 OTS 可参考 `OtsUtil#getLatestMessage`
- [x] T014 明确后续编码前需确认 `qwUserId` 对应的 OTS 查询字段

## Phase 2：后续实现准备

- [x] T015 确认后续导出项目所在目录和技术栈
- [x] T016 确认 `qwUserId` 在 `juzi_private_message` / `juzi_private_message_index` 中对应字段
- [ ] T017 确认是否需要对重复 `qwUserId` 去重，默认建议去重
- [x] T018 确认输出目录命名规则，默认建议每次运行生成独立批次目录
- [x] T019 确认输出文件命名规则，默认建议 `messages_001.txt`、`messages_002.txt`
- [x] T020 确认单条消息超过 10MB 时的处理策略，默认建议记录异常并跳过主输出
- [x] T021 确认导出行附加 `union_id` 与格式化 `timestamp`，默认不附加 `qwUserId` 或 `message_id`

## Phase 3：后续编码任务

- [x] T022 创建导出项目或模块
- [ ] T023 实现读取项目目录下 `userIds.txt`
- [ ] T024 实现空行和空白裁剪
- [ ] T025 实现重复 `qwUserId` 处理策略
- [x] T026 初始化 OTS `SyncClient`，复用现有环境变量配置口径
- [x] T027 基于 `OtsUtil#getLatestMessage` 的方式构造 `SearchRequest`
- [x] T028 使用表 `juzi_private_message` 和索引 `juzi_private_message_index`
- [x] T029 使用 `timestamp >= startTimestamp` 和 `timestamp <= endTimestamp` 查询最近三个月
- [x] T030 添加 `isSelf=false` 查询条件
- [x] T031 添加 `type in (2, 7)` 查询条件
- [x] T032 添加 `qwUserId` 对应字段的查询条件
- [x] T033 实现 OTS 查询分页，导出完整时间范围内的全部匹配消息
- [x] T034 读取必要列：`payload`、`timestamp`、`isSelf`、`type`、`external_user_id`，以及错误追踪所需主键或 `message_id`
- [x] T035 解析 `payload` JSON
- [x] T036 提取 `payload.text`
- [x] T037 跳过空 `text` 或仅空白 `text`
- [x] T038 将消息内部换行规范化为单行
- [x] T039 按 `timestamp ASC` 顺序写入输出文件
- [x] T040 实现 UTF-8 文本写入
- [x] T041 实现输出文件 10MB 阈值检测
- [x] T042 实现超过阈值前切换到新文件
- [x] T043 确保单条消息不会被拆分到多个文件
- [x] T044 实现单个用户查询失败时记录错误并继续后续用户
- [x] T045 实现单条消息解析失败时记录错误并继续后续消息
- [x] T046 实现导出完成统计输出
- [x] T047 如 OTS 行包含 `recall=1`，按现有口径跳过撤回消息

## Phase 4：后续验证

- [ ] T048 验证 `userIds.txt` 不存在时提示明确错误且不生成空结果
- [ ] T049 验证 `userIds.txt` 空文件时提示明确错误且不生成空结果
- [ ] T050 验证空行、前后空格被正确处理
- [ ] T051 验证重复 `qwUserId` 按确认策略处理
- [ ] T052 验证最近三个月内 `type=2` 用户消息被导出
- [ ] T053 验证最近三个月内 `type=7` 用户消息被导出
- [ ] T054 验证三个月前消息不被导出
- [ ] T055 验证 `isSelf=true` 消息不被导出
- [ ] T056 验证其他 `type` 消息不被导出
- [ ] T057 验证 `payload.text` 正确写入输出文件
- [ ] T058 验证空 `payload.text` 不写入输出文件
- [ ] T059 验证非法 `payload` 被记录且不中断任务
- [ ] T060 验证消息内部换行被规范化为单行
- [ ] T061 验证输出文件每条消息一行
- [ ] T062 验证单个输出文件超过 10MB 前自动切换新文件
- [ ] T063 验证文件切分不截断单条消息
- [ ] T064 验证输出文件使用 UTF-8 编码
- [ ] T065 验证导出完成后统计信息准确
- [ ] T066 验证部分用户查询失败时其他用户仍可完成导出

## Phase 5：开口率统计需求确认

- [ ] T067 确认统计窗口为 5 月 8 日到统计执行当天，时区按 `Asia/Shanghai`
- [ ] T068 确认新增学员识别文案与 `external_user_id` 去重规则，包含两种招呼语
- [ ] T069 确认开口判定口径为 `isSelf=false`、沿用现有 `is_group` 筛选、且不限制 `type`
- [ ] T070 确认开口率公式、分母为 0 时的输出以及样本消息选择规则
- [ ] T071 确认已开口/未开口名单输出字段和 `contact_name` 来源
- [ ] T072 确认统计对象为 `15313122087`、`15110220704`、`15110180421`、`15110220914`

## Phase 6：开口率统计编码任务

- [ ] T073 创建开口率统计模块或报表入口
- [ ] T074 读取待统计 `user_id` 列表
- [ ] T075 按统计窗口查询建联文案并按 `external_user_id` 去重
- [ ] T076 对新增学员执行开口判定查询
- [ ] T077 按 `user_id` 汇总新增学员数、已开口数、未开口数和开口率
- [ ] T078 输出已开口名单的 `contact_name`、`message_id`、`payload`
- [ ] T079 输出未开口名单的 `contact_name`
- [ ] T080 处理无新增学员、多条命中和空 `contact_name` 边界

## Phase 7：开口率统计验证

- [ ] T081 验证 5 月 8 日边界和当天边界
- [ ] T082 验证建联文案识别和 `external_user_id` 去重
- [ ] T083 验证 `isSelf=false`、`is_group` 筛选和 `type` 不限制
- [ ] T084 验证开口率数值和 `0%` 场景
- [ ] T085 验证已开口/未开口名单输出和样本 `message_id`、`payload`
- [ ] T086 验证四个指定 `user_id` 的统计结果
- [ ] T087 验证历史学员不参与统计，且两种招呼语本身都不算开口

## Phase 8：全量学员开口率模式

- [x] T088 新增全量学员开口率模式入口，例如 `open-rate-all`
- [x] T089 允许全量学员模式不依赖建联文案入组
- [x] T090 仍在全量学员模式中排除招呼语本身作为开口消息
- [x] T091 为全量学员模式输出独立 TXT 报表并标识 scope
- [x] T092 验证全量学员模式下的分母、开口率和名单输出

## 执行记录

### D001 - 文档记录

- 已按用户要求在 `C:\workspace\ju-chat\specs` 下创建 Spec Kit 文档。
- 当前阶段未创建实际导出项目，未修改业务代码，未连接 OTS。
- 已记录输入文件 `userIds.txt` 的读取要求。
- 已记录最近三个月、`timestamp`、`isSelf=false`、`type in (2, 7)` 的查询要求。
- 已记录从 `payload.text` 提取文本并写入 `txt` 的输出要求。
- 已记录单个文件 10MB 切分要求。
- 已记录参考 `OtsUtil#getLatestMessage` 的 OTS 查询方式。
- 已记录后续编码前需要确认 `qwUserId` 对应 OTS 字段。
- 已记录 5 月 8 日到统计执行当天的开口率统计窗口。
- 已记录新增学员按建联文案识别并按 `external_user_id` 去重的统计口径。
- 已记录需要统计的四个 `user_id` 以及已开口/未开口名单输出字段。
- 已记录历史学员不参与统计，且招呼语本身不算开口。
