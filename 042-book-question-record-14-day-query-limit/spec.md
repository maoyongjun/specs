# 功能规格：图书问卷记录查询限制近 14 天

**功能目录**：`042-book-question-record-14-day-query-limit`  
**创建日期**：`2026-05-29`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs` 新建 Spec Kit 文档，并修改 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\service\book\impl\BookQuestionRecordServiceImpl.java`，查询 `BookQuestionRecordDO` 和 `ExternalBookQuestionRecordDO` 时增加查询创建时间 14 天内的限制。

## 背景

- 当前问题：图书问卷物流记录按手机号查询时只按 `id desc limit 2` 获取最近记录，可能返回超过 14 天的历史记录。
- 当前行为：`BookQuestionRecordServiceImpl#getBookQuestionRecordByAppletUserId` 分别查询 `drh_book_question_record` 和 `drh_external_book_question_record`，按手机号匹配并每张表最多取 2 条。
- 目标行为：两张表查询均只返回创建时间在近 14 天窗口内的记录。
- 非目标：不修改接口入参、返回 JSON 结构、手机号兜底逻辑、排序规则、每表 `limit 2`、记录类型标识、物流字段或其他业务链路。

## 用户场景与测试

### 用户故事 1 - 查询只返回近 14 天图书问卷记录（优先级：P1）

业务查询某学员图书问卷物流记录时，只希望展示或使用近 14 天内创建的有效记录，避免过期历史记录干扰后续判断。

**独立测试**：构造同一手机号下 14 天内和 14 天前的 `BookQuestionRecordDO`、`ExternalBookQuestionRecordDO` 数据，调用查询方法后只应返回 14 天内记录。

**验收场景**：

1. **Given** 同一手机号在 `drh_book_question_record` 中存在 14 天内记录和超过 14 天记录，**When** 调用 `getBookQuestionRecordByAppletUserId`，**Then** 返回结果只包含 14 天内的 `BookQuestionRecordDO` 记录。
2. **Given** 同一手机号在 `drh_external_book_question_record` 中存在 14 天内记录和超过 14 天记录，**When** 调用 `getBookQuestionRecordByAppletUserId`，**Then** 返回结果只包含 14 天内的 `ExternalBookQuestionRecordDO` 记录。
3. **Given** 该手机号两张表均无 14 天内记录，**When** 调用查询方法，**Then** 返回空 `JSONObject` 或仅保留旧逻辑允许的空结果，不返回过期记录。

### 用户故事 2 - 旧查询行为保持不变（优先级：P2）

除新增创建时间窗口外，现有调用方依赖的手机号解析、排序、数量限制和返回字段保持稳定。

**独立测试**：同一手机号存在多条 14 天内记录时，确认每张表仍按 `id desc` 取最多 2 条，并按旧逻辑组装 `lIds`、`aesId`、`type` 和 `bookList`。

**验收场景**：

1. **Given** `appletUserId` 对应用户存在非空手机号，**When** 入参手机号与用户手机号不同，**Then** 仍优先使用用户手机号查询。
2. **Given** 查询到两张表的有效记录，**When** 组装响应，**Then** `BookQuestionRecordDO` 的 `type` 仍为 `1`，`ExternalBookQuestionRecordDO` 的 `type` 仍为 `2`。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `appletUserId`：来源 `getBookQuestionRecordByAppletUserId` 入参；赋值时机为调用前；当前方法用于查询 `AppletUserDo`。
  - `phone`：来源 `getBookQuestionRecordByAppletUserId` 入参；赋值时机为调用前；作为 `queryPhone` 初始值。
  - `queryPhone`：优先来源 `AppletUserDo#getPhone`，否则使用入参 `phone`；在查询两张表前确定。
  - `queryStartTime`：来源当前 JVM 时间 `LocalDateTime.now().minusDays(14)`；在查询两张表前现算现用。
- 下游读取字段清单：
  - `getBookQuestionRecordByAppletUserId` 读取 `BookQuestionRecordDO#getPhone`、`getCreateTime`、`getId`、`getLIds`、`getAesId`。
  - `getBookQuestionRecordByAppletUserId` 读取 `ExternalBookQuestionRecordDO#getPhone`、`getCreateTime`、`getId`、`getLIds`、`getAesId`。
  - `getBookQuestionRecordByAppletUserId` 读取 `AppletUserDo#getPhone`、`getChannelId`。
- 空对象 / 占位对象风险：
  - 手机号为空时返回 `new JSONObject()` 是已有行为，本次保留；无新增占位 DTO、空 Map 或跨层占位参数。
- 调用顺序风险：
  - 不存在查询后才赋值的关键参数；`queryStartTime` 在两个数据库查询前计算。
- 旧逻辑保持：
  - 保持优先使用 `AppletUserDo#getPhone`、手机号为空直接返回、两张表各自查询、`orderByDesc(id)`、`limit 2`、`bookList` 结构、`type=1/2`、非空 `lIds` 覆盖主结果和 `channelId` 写入逻辑。
- 需要用户确认的设计选择：
  - 无。本次需求明确为追加 14 天创建时间限制，不涉及接口契约或额外远程调用。

## 边界情况

- `appletUserId` 为空：沿用入参 `phone` 查询，并追加近 14 天限制。
- `AppletUserDo` 不存在或手机号为空：沿用入参 `phone` 查询，并追加近 14 天限制。
- `queryPhone` 为空：沿用旧逻辑直接返回空 `JSONObject`。
- `createTime` 为空：数据库 `create_time >= queryStartTime` 条件不会命中，视为不满足近 14 天限制。
- 14 天边界：使用 `>= LocalDateTime.now().minusDays(14)`，边界时刻记录可被查询。
- 记录数量：新增时间过滤后仍每张表最多返回 2 条。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在查询 `BookQuestionRecordDO` 时追加 `createTime >= 当前时间 - 14 天` 条件。
- **FR-002**：系统 MUST 在查询 `ExternalBookQuestionRecordDO` 时追加 `createTime >= 当前时间 - 14 天` 条件。
- **FR-003**：系统 MUST 在同一次方法调用中让两张表查询使用同一个 14 天起始时间，避免边界时间不一致。
- **FR-004**：系统 MUST 保持原有手机号解析、排序、每表 `limit 2` 和返回 JSON 结构不变。
- **FR-005**：系统 MUST NOT 新增远程调用、MQ、Redis、数据库写入或接口契约变更。
- **FR-006**：验证记录 MUST 覆盖两个查询均已追加 `createTime` 条件。

## 成功标准

- **SC-001**：目标方法中 `BookQuestionRecordDO` 查询包含 `BookQuestionRecordDO::getCreateTime` 的近 14 天下限条件。
- **SC-002**：目标方法中 `ExternalBookQuestionRecordDO` 查询包含 `ExternalBookQuestionRecordDO::getCreateTime` 的近 14 天下限条件。
- **SC-003**：目标模块编译或静态验证通过，且未发现旧查询的手机号、排序、数量限制和返回字段被改动。

## 假设

- `BookQuestionRecordDO#createTime` 和 `ExternalBookQuestionRecordDO#createTime` 均映射数据库 `create_time` 字段，类型为 `LocalDateTime`。
- “创建时间 14 天内”按近 14 天理解，即 `create_time >= 当前时间 - 14 天`。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 已明确本次不修改接口契约、返回结构、远程调用、MQ、Redis 或数据库写入。

### D002 - 实现记录

- 实现内容：在 `BookQuestionRecordServiceImpl#getBookQuestionRecordByAppletUserId` 中新增近 14 天查询起始时间，并给 `BookQuestionRecordDO`、`ExternalBookQuestionRecordDO` 两个查询追加 `createTime >= queryStartTime` 条件。
- 影响范围：仅影响当前方法读取两张图书问卷记录表的查询过滤。
- 测试命令：`mvn -pl ai -am -DskipTests compile`，执行目录 `C:\workspace\ju-chat\kkhc\kkhc-idc`。
- 测试结果：`BUILD SUCCESS`；`kkhc-idc`、`base-common`、`ai-common`、`tablestore-common`、`ai` 均编译成功。
- 自检结论：两个查询均已追加同一个 `queryStartTime` 下限条件，旧手机号解析、排序、`limit 2` 和返回结构保持不变。

### D003 - 暂无纠正记录

- 当前没有用户补充、测试失败、代码审查发现或参数遗漏引发的纠正项。
