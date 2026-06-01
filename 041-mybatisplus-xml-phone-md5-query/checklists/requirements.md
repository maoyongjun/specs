# 规格质量检查清单：MyBatis XML 手机号 MD5 查询兼容

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-05-29`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确兼容性、异常处理和错误提示要求。
- [x] 明确后续实现必须增加测试或静态验证记录。

## 需求完整性

- [x] 无待澄清标记或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。
- [x] 已列出下游读取字段清单。
- [x] 已识别 `new CreateExternalBookQuestionRecordDto()` 后只 set 部分字段的风险。
- [x] 已要求 `phoneMd5` 在调用 Mapper 前赋值，或在当前层现算现用。
- [x] 已明确不得在 Mapper 调用后才补 `phoneMd5`。
- [x] 已为 XML Mapper 参数和 SQL 字段增加验证方案。
- [x] 已记录业务语义差异：查询接口可接受 MD5，保存 / 更新接口不可接受 MD5。
- [x] 已要求全量扫描其他 Mapper XML 的手机号使用点，并记录分类处理结果。

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约。
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志和 fallback。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP，除非规格明确要求联调。
- [x] 补充需求已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 专项检查：XML phone 查询

- [x] 已明确 XML 中 `phone = #{input.phone}` 需要改为 `phone_md5 = #{input.phoneMd5}`。
- [x] 已明确 `queryHistoryPageWhere`、`queryHistoryPageWhere2`、`queryHistoryPageWhere3` 都需要检查。
- [x] 已明确 `queryHistoryExpressNoList` 的两个 UNION 分支都需要检查。
- [x] 已明确 `queryHistoryExpressNoListCount` 的两个 UNION 分支都需要检查。
- [x] 已明确 SQL 日志或 Mapper 单测需要验证不再使用 `phone = ?`。
- [x] 已明确不能只检查 `ExternalBookQuestionRecordMapper.xml`，其他 XML 也必须扫描。
- [x] 已明确扫描形态包括等值、IN、LIKE、JOIN、NULL 判断和 SELECT 展示。
- [x] 已明确 `phone like` 不能直接套用 MD5 模糊查询，必须业务确认。
- [x] 已明确 `phone is null/not null` 与 `select phone` 需要评估安全字段替代方案。

## 专项检查：phone 入参规则

- [x] 查询接口允许明文手机号。
- [x] 查询接口允许前端加密手机号。
- [x] 查询接口允许 32 位 MD5 手机号，并直接作为 `phoneMd5` 使用。
- [x] 保存接口不允许 32 位 MD5 手机号。
- [x] 更新接口不允许 32 位 MD5 手机号。
- [x] 保存 / 更新接口传错时错误提示固定为 `手机号加密格式不符`。

## 备注

- 本阶段只创建文档，不进入代码实现。
- 后续实现前必须先完成 `tasks.md` 的 Phase 1 和 Phase 2。
