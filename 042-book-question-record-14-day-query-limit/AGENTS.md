# 规格执行说明

本目录记录 `042-book-question-record-14-day-query-limit`。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\042-book-question-record-14-day-query-limit`
- 目标项目：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 相关模块：`ai` 服务中的图书问卷物流记录查询链路

## 当前目标

- 在 `BookQuestionRecordServiceImpl#getBookQuestionRecordByAppletUserId` 查询 `BookQuestionRecordDO` 时增加创建时间近 14 天限制。
- 在同一方法查询 `ExternalBookQuestionRecordDO` 时增加创建时间近 14 天限制。
- 保持手机号解析、结果组装、类型标识、按 `id desc` 取最近 2 条等旧行为不变。

## 执行原则

- 先读代码，再定方案，后实现。
- 不扩大接口契约，不新增数据库结构，不调整返回 JSON 字段。
- 时间窗口在当前 service 层现算现用，两个查询共用同一个起始时间。
- 查询限制只追加到当前两张表的读取条件，不影响其他物流提醒、补偿或发货链路。

## 强制门禁

- 参数来源：`appletUserId`、`phone` 来自接口入参；`queryPhone` 优先使用 `AppletUserDo#getPhone`。
- 赋值时机：`queryPhone` 在查询两张表前确定；14 天起始时间在查询前计算。
- 占位对象：手机号为空时返回空 `JSONObject` 是旧逻辑，本次不改变。
- 下游读取：本方法读取 `lIds`、`aesId`、`channelId` 并组装 `bookList`。
- 旧逻辑保持：保留按手机号过滤、按 `id desc` 排序、每张表 `limit 2`、类型 `1/2` 和非空 `lIds` 覆盖主结果的逻辑。
- 影响范围：仅影响数据库查询过滤条件，不改外部调用、MQ、Redis、数据库写入或异步行为。
- 测试映射：通过代码静态验证和模块编译确认 `createTime` 字段可用、查询条件已追加。

## 重点代码位置

- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\lms\service\book\impl\BookQuestionRecordServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\BookQuestionRecordDO.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\book\ExternalBookQuestionRecordDO.java`

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
