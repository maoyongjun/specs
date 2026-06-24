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
- [x] T007 AI 回复缓存写入放在发送前校验通过后，不依赖后续异步步骤补齐字段。
- [x] T008 `AppTask` 下游返回字段在返回前当前层覆盖，日志和返回体保持一致。
- [x] T009 本次明确新增 Redis key/TTL 行为；不改变接口契约、MQ body、数据库写入或外部请求。
- [x] T010 用户已确认缓存只按 `external_user_id` 维度、只覆盖 `AppTask` 主入口。
- [x] T011 测试映射：常量测试覆盖 key/TTL/文案；`AppTask` 测试覆盖缓存命中和未命中覆盖逻辑。

**检查点**：T006-T011 已有明确结论；未发现阻断实现的高风险。

## Phase 3：实现

- [ ] T012 按规格实现最小范围改动。
- [ ] T013 保持未声明的旧行为不变。
- [ ] T014 对 Redis key、TTL、触发文案和返回覆盖增加可测试断言点。
- [ ] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 或 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [ ] T016 新增或更新单元测试，覆盖关键行为。
- [ ] T017 测试中断言关键 Redis 参数内容，不只断言最终结果。
- [ ] T018 验证未命中文案、缓存不存在、旧标签/物流逻辑不回归。
- [ ] T019 运行目标模块测试或编译命令，并记录结果。
- [ ] T020 搜索确认没有残留旧口径或遗漏目标路径。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `110-ai-register-mail-cache` 规格文档。
- 验证方式：代码搜索、现有入口读取、测试目录确认。
- 自检结论：满足实现前强制门禁。

### D002 - 实现记录

- 待实现后填写。
