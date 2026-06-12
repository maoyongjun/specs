# 规格质量检查清单：juzi-service drh_phone_security_region 数据刷新接口

**用途**：验证需求完整性、参数完整性和实施就绪度  
**创建日期**：`2026-06-12`  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 明确目标项目、模块、入口和核心实现位置。（`data-RC\juzi-service`，`com.drh.data.juzi.phonesecurity` + `controller.admin`，见 AGENTS.md 重点代码位置）
- [x] 明确用户目标、成功标准和非目标。（spec.md 背景/非目标/SC-001~006）
- [x] 明确新增、修改和禁止改变的行为。（全部新增文件；FR-013 禁止修改现有类；FR-007 禁止写 segment/明文）
- [x] 明确日志、时间、延迟、幂等、fallback、兼容性或异常处理要求。（FR-008 异常只记日志；幂等按 phone_md5；日志前缀 `phone_security_region_refresh_`；日志不含明文）
- [x] 明确后续实现必须增加测试或静态验证记录。（FR-014，tasks.md T011 测试映射）

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 或未替换占位内容残留。
- [x] 需求可测试且无明显歧义。（FR 全部为 MUST/MUST NOT 形式）
- [x] 成功标准可衡量。（SC-002 重跑 insertedCount 趋零；SC-004 静态检查；SC-006 测试通过）
- [x] 验收场景覆盖正常路径、边界路径和不回归路径。（用户故事 1-4 共 10 个 Given-When-Then）
- [x] 边界情况已识别，并明确跳过、兜底、抛错或记录日志的策略。（spec.md 边界情况 10 条，每条带计数器与处理策略）

## 参数完整性门禁

- [x] 已列出关键参数来源和赋值时机。（防漏分析：phoneMask/phoneMd5/phoneAes/rawPhone/segment/province/city）
- [x] 已列出下游读取字段清单。（预检/解密/号段查询/INSERT 四类下游的读取参数）
- [x] 没有未解释的 `new XxxDto()`、空 JSON、空 Map 或占位参数。（T006 结论：无，候选行不可变构造）
- [x] 下游读取字段在调用前已赋值，或在当前层现算现用。（T008 结论：全部当前层现算）
- [x] 不存在未处理的调用后赋值风险。（T007 结论：无）
- [x] 外部接口、Feign、FC、MQ、Redis 或数据库写入的关键参数已有下游参数断言方案。（FR-014：INSERT 列与参数值断言、FC 解密入参 businessType=2 断言、预检 SQL 断言）
- [x] 若修复会改变调用顺序、接口契约、远程调用或业务语义，已记录并完成用户确认。（三项设计选择已于 2026-06-12 确认，记录于 spec.md）

## 实施就绪度

- [x] 实现范围已限定，不扩散到无关模块。（仅 juzi-service 两个包，全部新增文件）
- [x] 不新增数据库表、不新增对外 API、不修改 MQ/Redis/配置契约，除非规格明确要求。（不新增表；新增 admin 管理接口与 FC 解密调用为规格明确要求且已确认）
- [x] 已确认旧逻辑中必须保持不变的过滤、异常、日志、延迟和 fallback。（T005 结论；FR-013）
- [x] 每个关键需求至少有一条测试、编译或静态验证任务。（T011 测试映射覆盖 FR-002~FR-013）
- [x] 单元测试计划避免真实访问 Redis、OTS、Center、RocketMQ、FC 或外部 HTTP，除非规格明确要求联调。（FR-014：mock JdbcTemplate 与 DecryptClient，不真实访问 DB/FC）
- [x] 补充需求或纠正需求时，已同步更新 `spec.md`、`tasks.md` 和 `AGENTS.md`。（流程已约定，Dxxx 追加）

## 备注

- 强制门禁未完成前，不进入实现。
- 发现模型未识别的历史代码风险时，先补文档和测试映射，再改代码。
- 运行时假设（两表存在性、DDL 默认值、uk_phone_md5）依赖 start() preflight 与运维核查 `SHOW CREATE TABLE`，不属于代码可静态验证范围。
