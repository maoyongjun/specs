# 任务清单：图书问卷记录查询限制近 14 天

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段通过代码静态验证和目标模块编译记录关键行为。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认当前处于 `kkhc-idc/ai` 图书问卷记录查询链路。
- [x] T002 用代码搜索确认真实入口为 `BookQuestionRecordServiceImpl#getBookQuestionRecordByAppletUserId`。
- [x] T003 确认关键参数来源、赋值时机、下游读取字段和字段类型。
- [x] T004 确认本次不涉及配置来源、环境变量、Redis key、MQ topic/tag、Feign/FC/HTTP 调用或数据库写入。
- [x] T005 确认已有旧逻辑中必须保持不变的手机号兜底、排序、`limit 2`、返回 JSON 和类型标识。

**检查点**：T001-T005 已完成，可以进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在 `new XxxDto()`、空 JSON、空 Map 或只赋值部分字段的占位传参；结论：仅保留旧逻辑手机号为空时返回空 `JSONObject`。
- [x] T007 检查是否存在调用后赋值、异步后赋值、或依赖后续流程补齐字段；结论：不存在。
- [x] T008 检查每个下游读取字段是否在调用前已有确定来源，或在当前层现算现用；结论：`queryPhone` 和 `queryStartTime` 均在查询前确定。
- [x] T009 检查本次方案是否改变调用顺序、接口契约、外部请求、MQ body、Redis TTL、数据库写入或异步行为；结论：不改变。
- [x] T010 对需要用户确认的业务语义变化做记录；结论：无额外需确认事项。
- [x] T011 为每个关键行为建立测试映射，覆盖两个查询均追加 `createTime` 条件和旧逻辑不回归。

**检查点**：T006-T011 已完成，风险可控。

## Phase 3：实现

- [x] T012 按规格实现最小范围改动。
- [x] T013 保持未声明的旧行为不变。
- [x] T014 对数据库查询参数增加可静态验证点：两个 wrapper 均包含 `getCreateTime >= queryStartTime`。
- [x] T015 同步更新 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist 中因实现产生的口径变化。

## Phase 4：测试与验证

- [x] T016 本次未新增单元测试；以静态验证和目标模块编译覆盖关键行为。
- [x] T017 静态验证两个查询关键下游参数内容，不只检查最终返回。
- [x] T018 验证边界情况和旧逻辑不回归。
- [x] T019 运行目标模块测试或编译命令，并记录结果。
- [x] T020 搜索确认没有残留旧调用、旧字段、旧口径；目标方法两个查询均已追加时间条件。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `042-book-question-record-14-day-query-limit` Spec Kit 文档，覆盖规格、任务、执行说明和质量清单。
- 验证方式：读取 `_template`，对照用户需求和目标代码填写。
- 自检结论：满足强制门禁，允许进入实现。

### D002 - 实现记录

- 实现内容：在 `BookQuestionRecordServiceImpl#getBookQuestionRecordByAppletUserId` 中新增近 14 天起始时间，并给两张表查询追加 `createTime >= queryStartTime`。
- 测试命令：`mvn -pl ai -am -DskipTests compile`，执行目录 `C:\workspace\ju-chat\kkhc\kkhc-idc`。
- 测试结果：`BUILD SUCCESS`；`kkhc-idc`、`base-common`、`ai-common`、`tablestore-common`、`ai` 均编译成功。
- 自检结论：参数来源、调用顺序和旧返回逻辑保持稳定；剩余风险为未新增数据库集成测试，已用静态验证确认两个 wrapper 均包含时间条件。

### D003 - 暂无纠正记录

- 当前没有需要纠正的补充项。
