# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\048-phone-security-query-return-save-mask-validate`
- 目标工程：`C:\workspace\drh`（主业务微服务）和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块）
- 相关模块：
  - drh：`drh-common`（实体、工具类）、`drh-kk-cms`（CMS 后台）、`drh-pay`（支付）、`drh-endpoint`（入口）、`drh-callback`（回调）、`drh-media-process`（媒体处理）
  - ju-chat：`ai-common`（实体、Output）、`ai`（Controller、Service）
- 前置需求：
  - `032-phone-security-columns`：数据库字段添加（`phone_mask`、`phone_md5`、`phone_aes`）
  - `036-phone-security-save-query`：保存/查询/展示链路改造
  - `041-mybatisplus-xml-phone-md5-query`：XML Mapper phone_md5 查询兼容

## 当前目标

- 查询接口返回结果中增加 `phone_mask`、`phone_md5`、`phone_aes` 三个安全字段。
- 查询接口返回结果中的 `phone` 字段统一改为 `phone_mask` 的值（掩码格式），不再返回明文。
- 保存/更新接口增加掩码格式手机号检测，传入掩码格式时返回明确错误提示。
- 本阶段只编写规格文档，不修改业务代码。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、Output/DTO 映射方式和测试落点。
- 不允许只改一个 Output/DTO 类；必须全量搜索所有返回给前端的含 `phone` 字段的 Output/DTO。
- 不允许只改一个保存入口；必须全量搜索所有保存/更新含 `phone` 字段的 Service 方法。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- 对 `phone` 字段返回掩码值的改造不得影响后端间接口（ERP 回调、物流推送、支付回调）获取明文手机号。
- 掩码格式校验必须在 `isWritablePhoneInput()` 之前执行，不得改变原有 MD5 拒绝逻辑的错误提示。
- 单元测试不能只验证最终结果；涉及安全字段映射和掩码校验时，必须断言中间值。
- 实现记录必须同步写入 `tasks.md` 和 `spec.md`。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：Output/DTO 中 `phoneMask`、`phoneMd5`、`phoneAes` 从哪个实体的哪个字段获取。
- 赋值时机：安全字段是否在查询结果映射时同步赋值，而非后续补齐。
- `phone` 字段覆盖：Output/DTO 中的 `phone` 字段是否已覆盖为掩码值，不再透传实体明文。
- 自动映射风险：使用 BeanUtils.copyProperties 或 ConvertUtil 的场景，`phone` 字段是否被后续覆盖。
- 保存入口校验：所有保存/更新入口是否在 `createAesInfo()` 之前增加掩码格式校验。
- 校验顺序：掩码格式校验是否在 `isWritablePhoneInput()` 之前执行。
- 旧逻辑保持：原有查询逻辑、保存逻辑、MD5 拒绝逻辑是否不变。
- 后端间接口：ERP 回调、物流推送、支付回调等获取明文手机号的路径是否不受影响。
- 测试映射：每个关键行为至少对应一条单元测试或静态验证记录。

## 重点代码位置

- `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java` — 新增 `isMaskedPhone()` 方法
- `drh-common\src\main\java\com\drh\common\entity\*.java` — 已有安全字段的实体类
- `drh-kk-cms\src\main\java\com\drh\kk\cms\dto\*.java` — 需增加安全字段的 Output/DTO
- `drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\*.java` — 查询映射和保存入口
- `drh-common\src\test\java\com\drh\common\fc\datasec\DataSecurityUtilTest.java` — 单元测试
- `ai-common\src\main\java\com\kkhc\idc\lms\common\module\dao\output\*.java` — ju-chat 侧 Output 类

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设、涉及文件清单和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
