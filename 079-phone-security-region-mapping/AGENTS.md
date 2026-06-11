# 规格执行说明

本目录记录手机号安全字段与省市归属地映射的规格文档。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\079-phone-security-region-mapping`
- 目标项目：
  - `C:\workspace\drh`
  - `C:\workspace\ju-chat\kkhc`
- 目标模块：
  - DRH：`drh-common` 统一入口，`drh-endpoint`、`drh-callback`、`drh-kk-cms`、`drh-media-process`、`drh-pay` 注册 recorder。
  - KKHC：`base-common`、`ai-common` 统一入口，`broadcast`、`ai`、`lms`、`app` 注册 recorder。
- 核心现有入口：
  - DRH：`com.drh.common.fc.datasec.DataSecurityInvoke`
  - KKHC：`com.kkhc.common.utils.fc.datasec.DataSecurityInvoke`
  - KKHC：`com.kkhc.idc.lms.common.module.datasec.DataSecurityInvoke`

## 当前目标

- 新增 `drh_phone_security_region` 表，保存 `phone_mask`、`phone_md5`、`phone_aes` 与 `province`、`city` 的映射。
- 新表不得保存明文手机号，也不得保存 `segment` 字段。
- 使用手机号前 7 位只作为运行时查询 `phone_segment.segment` 和本地缓存 key。
- 对 `segment -> province/city` 做服务内缓存，避免每次查 `phone_segment`。
- 按 `phone_md5` 做幂等判断：手机号已存在不处理，不存在才写入映射表。

## 执行原则

- 在现有 `DataSecurityInvoke.buildPhoneSecurity()` 或同等工具生成三类安全字段后，通过 recorder 旁路写入映射。
- `computePhoneMd5()` 是查询/归一化路径，不触发映射写入。
- `phone_md5` 是唯一幂等键；不得用明文手机号、`phone_aes` 或 `segment` 作为存在性判断。
- `segment` 只能存在于方法局部变量、查询条件或缓存 key 中，不得落入 `drh_phone_security_region` 实体、DDL、Mapper XML 或 insert 参数。
- 新增映射失败不得阻断原线索保存、授权、回调等主流程，只记录日志。
- 不新增对外 HTTP API，不修改 Controller 入参/返回，不改变 `AppletUser.city` 和 `AppletUser.province` 语义。
- 不新增 Redis key 契约；缓存默认使用服务内内存缓存。

## 强制门禁

- 参数来源：`phone_mask/phone_md5/phone_aes` 来自统一手机号安全工具；`province/city` 来自 `phone_segment` 查询结果。
- 赋值时机：必须先在统一加密入口得到 `phone_mask/phone_md5/phone_aes`，再由 recorder 解析 `phone_segment` 得到省市，最后按 `phone_md5` 判断映射表是否已存在，不存在才插入。
- 下游读取：现有调用方继续读取 `PhoneSegment.getCity()` 和 `PhoneSegment.getProvince()`。
- 旧逻辑保持：空手机号、长度不足 7 位、号段未命中时仍返回空 `PhoneSegment`，不抛异常。
- 测试映射：实现后必须验证新表插入参数不含 `segment`，并验证缓存命中时不再查询 `phone_segment`。

## 重点代码位置

- `C:\workspace\drh\drh-endpoint\src\main\java\com\drh\endpoint\service\impl\PhoneSegmentServiceImpl.java`
- `C:\workspace\drh\drh-callback\src\main\java\com\drh\callback\service\impl\PhoneSegmentServiceImpl.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\broadcast\src\main\java\com\kkhc\idc\broadcast\service\impl\PhoneSegmentServiceImpl.java`
- `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\base-common\src\main\java\com\kkhc\common\utils\fc\datasec\DataSecurityInvoke.java`
- `C:\workspace\ju-chat\kkhc\kkhc-idc\ai-common\src\main\java\com\kkhc\idc\lms\common\module\datasec\DataSecurityInvoke.java`
- 各运行模块 `PhoneSecurityRegionRecorder`。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和执行记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 验证规格质量、参数完整性和实施就绪度。
- `phone-security-region-mapping-ddl.sql` 记录可审核 DDL。
- 后续如用户要求保存 `segment`、改用 Redis 缓存或新增查询接口，必须追加 Dxxx 纠正记录并同步全部文档。
