# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\038-app-task-courier-status-if-register-compat`
- 目标项目 1：`C:\workspace\ju-chat\coze_plugin\external-info-select`
- 目标项目 2：`C:\workspace\ju-chat\kkhc\kkhc-idc\ai`
- 相关模块：`AppTask` 图书物流返回字段、`AiServiceImpl` 物流消息“已填写”补偿打标

## 当前目标

- 当 `AppTask` 最终参与 Coze 返回组装的数据中 `courier_status=是` 时，补偿返回 `if_register=是`。
- 在 `AiServiceImpl.compensateWriteOverTagIfNeeded` 中对“已填写”标签补偿 FC 调用增加 `RateLimitUtil.limitRun` 限流。
- 保持现有物流查询、标签识别、FC 入参、异常日志和主流程不阻断行为不变。

## 执行原则

- 先确认字段来源和调用顺序，再实现最小改动。
- 不新增外部接口、数据库字段、MQ 协议、Nacos 配置或标签写入之外的新副作用。
- 不把已有工作区改动混入本需求，不回滚无关文件。
- 单元测试必须覆盖正常路径、跳过路径和关键参数，不只看最终返回。

## 强制门禁

- `courier_status` 来源：`AppTask#setTushu` 生成后合并到 `jsonObject`，后续可能被 `otsInfo` 覆盖；补偿必须放在 `DayEnum.createCozeJson` 前。
- `if_register` 来源：原有“已填写”标签识别仍保留；新增补偿只在 `courier_status=是` 时写返回字段。
- `RateLimitUtil.limitRun` 依赖 `userRedisTemplateJuziSend` 和 Redis key；新增打标 key 必须独立于消息发送 key。
- FC 调用失败仍由 `invokeFc` 捕获并记录日志，不阻断 `sendJuzi` 主流程。

## 重点代码位置

- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\main\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImpl.java`
- `C:\workspace\ju-chat\coze_plugin\external-info-select\src\test\java\com\drh\select\service\AppTaskCourierStatusRegisterCompatTest.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai\src\test\java\com\kkhc\idc\crm\service\ai\impl\AiServiceImplLogisticsTagCompensationTest.java`

## 文档维护

- `spec.md` 描述需求、边界、成功标准和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现和验证任务。
- `checklists/requirements.md` 记录规格质量和实施就绪检查。
