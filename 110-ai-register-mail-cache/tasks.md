# 任务清单：AI 登记邮寄缓存联动

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `fc`、`coze_plugin` 和 `specs` 多仓库/目录协作。
- [x] T002 搜索确认 AI 回复入口为 `ai-reply` 的 `CozeUtil.sendJuzi`、`delay-mq` 的 `CozeUtil.sendJuzi` 和 `CozeUtilV2.sendJuzi`。
- [x] T003 确认关键参数 `external_user_id` 来自 `EmpExternalDto` 或 `external_key` 解析，均在使用前已赋值。
- [x] T004 确认只新增 Redis key 契约，不改 MQ topic/tag、FC body、OTS 表或外部 HTTP 参数。
- [x] T005 确认旧逻辑中敏感词重试、撤回、人工回复、空内容、`无法回答`、MD5 缓存和用户信息保存必须保持不变。

**检查点**：T001-T005 已完成，可以进入实现。

## Phase 2：风险门禁

- [x] T006 `AppTask` 存在静态空 JSON 早退对象；早退场景不做缓存覆盖。
- [x] T007 AI 回复缓存写入放在 answer 生成并打印日志后，不依赖后续发送步骤补齐字段。
- [x] T008 `AppTask` 下游返回字段在返回前当前层覆盖，日志和返回体保持一致。
- [x] T009 本次明确新增 Redis key/TTL 行为；不改变接口契约、MQ body、数据库写入或外部请求。
- [x] T010 用户已确认缓存只按 `external_user_id` 维度、只覆盖 `AppTask` 主入口。
- [x] T011 测试映射：常量测试覆盖 key/TTL/文案；`AppTask` 测试覆盖缓存命中和未命中覆盖逻辑。

**检查点**：T006-T011 已有明确结论；未发现阻断实现的高风险。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对 Redis key、TTL、触发文案和返回覆盖增加可测试断言点。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T016 新增或更新单元测试，覆盖关键行为。
- [x] T017 测试中断言关键 Redis 参数内容，不只断言最终结果。
- [x] T018 验证未命中文案、缓存不存在、旧标签/物流逻辑不回归。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧口径或遗漏目标路径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `110-ai-register-mail-cache` 规格文档。
- 验证方式：代码搜索、现有入口读取、测试目录确认。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 实现内容：新增登记邮寄缓存常量和测试；AI answer 生成命中文案即写 Redis；`AppTask` 返回前读取缓存并覆盖 `if_register`。
- 测试命令：`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl ai-reply -Dtest=RedisContantsTest test`；`mvn -f C:\workspace\ju-chat\fc\pom.xml -pl delay-mq -Dtest=RedisContantsTest test`；`mvn -f C:\workspace\ju-chat\coze_plugin\pom.xml -pl external-info-select -Dmaven.test.skip=false -DskipTests=false -Dtest=AppTaskCourierStatusRegisterCompatTest,RedisContantsTest test`。
- 测试结果：三条命令均 BUILD SUCCESS。
- 自检结论：参数来源、调用顺序和旧逻辑保持已复核；本次纠正将写入时机前移到 answer 生成点。

### D003 - 纠正记录：缓存写入时机前移

- 触发原因：用户反馈已看到命中文案的 AI 生成日志，但未看到缓存写入日志。
- 修正内容：缓存写入从 `sendJuzi` 入口前移到 answer 内容清洗并打印日志之后。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`。
- 验证结果：`ai-reply` 4 tests、`delay-mq` 3 tests、`external-info-select` 10 tests 全部通过。
