# 规格质量检查清单：手机号安全补充接口整改

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-11`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。
- [x] 明确用户目标、成功标准和非目标。
- [x] 明确新增、修改和禁止改变的行为。
- [x] 明确导出、短信发送、任务调度、XML 写入和旧字段兼容要求。
- [x] 明确后续实现必须增加测试、编译或静态验证记录。

## 需求完整性

- [x] 无待澄清标记或未替换模板项。
- [x] 需求可测试且无明显歧义。
- [x] 成功标准可衡量。
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。
- [x] 边界情况已识别，并明确跳过、兜底、失败或记录风险的策略。

## 参数完整性门禁

- [x] 已列出 `condition.phone`、`AppletPlayerInput.phone`、`DealSmsDto.phone` 的来源和赋值时机。
- [x] 已列出 Wrapper、Mapper XML、导出 DTO 和保存接口的下游读取字段清单。
- [x] 已识别 `DealSmsDto` 后补手机号路径，要求补明文时同步补安全字段。
- [x] 已要求下游读取字段在调用前赋值，或在当前层现算现用。
- [x] 已记录 `select ap.*` 和 `saveSmsDtosBatch` 明文写入风险。
- [x] 已为外部短信发送、XML 写入和数据库保存建立下游参数断言方案。
- [x] 已确认本规格不改变接口路径、HTTP 方法、短信模板、任务调度或 DDL。

## 实施就绪度

- [x] 实现范围已限定为三个补充对象，不扩散到无关模块。
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约。
- [x] 已确认旧逻辑中必须保持不变的分页、导出列名、短信发送、异常和过滤条件。
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。
- [x] 单元测试计划避免真实访问 Redis、RocketMQ、FC 或外部 HTTP，除非后续明确联调。
- [x] 用户补充 `drh_sms_deal` 后，已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。

## 静态证据清单

- [x] `LeadsNoqwSendMsgTaskDetailServiceImpl:121` 当前仍有 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 查询证据。
- [x] `LeadsNoqwSendMsgTaskDetailDO` 当前只有 `phone`，缺安全字段证据。
- [x] `AppletPlayerServiceImpl:104/187/237` 已计算 `phoneMd5`，查询侧已部分整改。
- [x] `AppletPlayerMapper.xml:30` 当前 `select ap.*`，存在明文输出风险。
- [x] `AppletPlayOutput:46` 当前 `@CsvField("手机号") private String phone`，存在导出明文风险。
- [x] `HandoverPlusMapper.xml:5` 当前 `drh_sms_deal` INSERT 只写 `phone`。
- [x] `HandoverPlusMapper.xml:17/46/73/97` 当前短信 SELECT 只读 `lu.phone`。
- [x] `DealSmsDto` 当前只有 `phone`，缺 `phoneMask/phoneMd5/phoneAes`。

## 备注

- 强制门禁未完成前，不进入实现。
- 发现模型未识别的历史代码风险时，先补文档和测试映射，再改代码。
