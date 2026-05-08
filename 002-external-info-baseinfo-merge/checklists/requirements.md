# 规格质量检查清单：External Info BaseInfo 合并查询

**用途**：在进入计划或实现前验证规格完整性和质量  
**创建日期**：2026-05-06  
**功能**：[spec.md](../spec.md)

## 内容质量

- [x] 规格聚焦接口可见行为：一个 `external_key` 换取合并后的用户上下文 JSON。
- [x] 明确记录接口路径 `POST /api/external-info/baseInfo`。
- [x] 明确记录测试环境与生产环境的 FC 函数名切换规则。
- [x] 明确记录合并顺序和同名字段覆盖规则。
- [x] 明确记录部分失败返回策略和 `_fc_errors` 字段。
- [x] 面向产品、测试和开发均可读。
- [x] 所有必填章节已完成。

## 需求完整性

- [x] 无 `[NEEDS CLARIFICATION]` 标记残留。
- [x] 需求可测试且无歧义。
- [x] 成功标准可衡量。
- [x] 成功标准与接口结果绑定。
- [x] 所有验收场景已定义。
- [x] 边界情况已识别。
- [x] 范围边界清晰：本阶段只写规格文档和 `tasks.md`，不编码。
- [x] 依赖和假设已识别。

## 功能就绪度

- [x] 所有功能需求都有清晰验收条件。
- [x] 用户场景覆盖正常合并、环境切换和部分失败。
- [x] 功能满足成功标准中定义的可衡量结果。
- [x] 规格文档与任务清单职责分离。
- [x] 后续实现范围限定为 `data-RC/juzi-service`。
- [x] 后续实现约束明确要求沿用现有 `BaseResponse`、`FcInvokeInput`、`FcInvokeUtils` 和 controller/service 风格。

## 备注

- 本次按现有 `specs/001-video-channel-placeholder-send` 的 Spec Kit 文档方式补充 `AGENTS.md`、`spec.md` 和 `checklists/requirements.md`。
- 按用户后续要求，本目录已生成 `tasks.md`；任务清单仅用于后续实现安排。
- 本次不修改 `C:\workspace\ju-chat\data-RC\juzi-service` 中任何业务代码。
