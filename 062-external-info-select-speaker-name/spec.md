# 功能规格：external-info-select 返回 speaker_name

**功能目录**：`062-external-info-select-speaker-name`  
**创建日期**：`2026-06-09`  
**状态**：Implemented  
**输入**：在 `C:\workspace\ju-chat\coze_plugin\external-info-select\src\main\java\com\drh\select\service\AppTask.java` 中获取 `speakerId` 并转化为 name 返回，返回属性使用 `speaker_name`；参考 `fc\audio-tts\AppTask.java` 的 `CenterUtil.getCampInfoByCampDateId(campDateId)`、`campInfo.getCategory()`、`campInfo.getSpeakerId()`；通过 `drh_speaker` 获取 `name`；数据不多，查到后缓存 6 小时；需要增加接口时在 `idc-ai` 增加获取 `drh_speaker` 的接口。

## 背景

- 当前问题：`external-info-select` 返回给 Coze 的用户信息缺少主讲老师昵称，无法按营期主讲老师做话术变量。
- 当前行为：legacy `external_key` 流程解析 `camp_date_id`，但没有继续查询营期 `speakerId`，最终 `chat_name` 不包含 `speaker_name`。
- 目标行为：legacy `external_key` 流程根据 `camp_date_id -> speakerId -> drh_speaker.name` 解析并返回 `speaker_name`。
- 非目标：不修改 `private-domain` 流程；不新增数据库结构；不修改 MQ、Redis key、OTS 表、Coze 既有字段白名单和图书物流逻辑。

## 用户场景与测试

### 用户故事 1 - 返回主讲老师昵称（优先级：P1）

Coze 插件调用 `external-info-select` 时，希望在最终 JSON 中拿到当前营期主讲老师昵称。

**独立测试**：构造 legacy `external_key`，替换营期查询和 speaker 查询为测试实现，验证最终结果包含 `speaker_name`。

**验收场景**：

1. **Given** `external_key` 包含有效 `camp_date_id`，**When** 营期返回 `speakerId=106` 且 speaker 返回 `name=赵曼`，**Then** 最终 JSON 包含 `"speaker_name":"赵曼"`。
2. **Given** `camp_date_id` 非数字或营期无 `speakerId`，**When** 执行查询，**Then** 最终 JSON 不包含 `speaker_name` 且原字段不受影响。

### 用户故事 2 - 降低重复查询（优先级：P2）

同一个 `speakerId` 被多次使用时，插件应减少对 `idc-ai` 的重复请求。

**独立测试**：使用可控时间源和计数查询函数，验证 6 小时内命中缓存，超过 6 小时后重新查询。

**验收场景**：

1. **Given** `speakerId=106` 已成功查到 `name=赵曼`，**When** 6 小时内再次查询，**Then** 不再触发远程 speaker 查询。
2. **Given** 缓存写入已超过 6 小时，**When** 再次查询同一 `speakerId`，**Then** 重新触发查询并刷新缓存。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `camp_date_id`：来源 `AppTask.handleRequest` 中 `external_key.split(":")[2]`；赋值时机为 legacy 流程早期解析；下游用于 `CenterUtil.getCampInfoByCampDateId`。
  - `speakerId`：来源 `idc-ai /ai/getCampInfoByCampDateId` 的 `data.speakerId`；赋值时机为当前层现查现用；下游用于 `CenterUtil.getSpeakerNameBySpeakerId`。
  - `speaker_name`：来源 `idc-ai /ai/getSpeakerInfoBySpeakerId` 的 `data.name`；赋值时机为 `DayEnum.createCozeJson` 返回后追加到最终 JSON。
- 下游读取字段清单：
  - Coze 返回 JSON 读取 `speaker_name`。
  - `CenterUtil.parseCampInfo` 读取 `category`、`speakerId`。
  - `CenterUtil.parseSpeakerName` 读取 `data.name`。
- 空对象 / 占位对象风险：
  - `CenterUtil.selectUserJson` 原有失败返回空 `AiMsgUserInfo` 保持不变；本需求不新增空 DTO 下传。
  - speaker 查询失败返回 `null`，调用方跳过字段。
- 调用顺序风险：
  - `DayEnum.createCozeJson` 不保留未知字段，必须在其返回后对 `chat_name` 追加 `speaker_name`。
- 旧逻辑保持：
  - `private-domain` 分支提前返回，不增加 speaker 查询。
  - 图书物流、设备信息、敏感词、转账金额、`day` 转字符串、`sku` 解析、课程规则匹配逻辑不改。
- 需要用户确认的设计选择：
  - 已按计划默认采用：查不到 `speaker_name` 时省略字段，不返回空字符串或默认值。

## 边界情况

- `external_key` 缺失或段数不足：沿用原逻辑返回空对象。
- `camp_date_id` 非数字：记录日志并跳过 `speaker_name`。
- `sys_domain` 未配置、HTTP 失败、响应体为空、响应 JSON 非法：记录日志并跳过字段。
- campInfo 为空或 `speakerId` 为空：跳过字段。
- speaker 不存在、`name` 为空：跳过字段且不缓存。
- 并发请求同一 `speakerId`：允许少量并发穿透，成功后写入本地缓存；不引入分布式锁。

## 需求

### 功能需求

- **FR-001**：系统 MUST 在 legacy `external_key` 流程中根据 `camp_date_id` 查询营期 `speakerId`。
- **FR-002**：系统 MUST 根据 `speakerId` 查询 `drh_speaker.name`，最终返回字段名 MUST 为 `speaker_name`。
- **FR-003**：系统 MUST 对成功查到的非空 `speakerId -> name` 在 `external-info-select` 侧缓存 6 小时。
- **FR-004**：系统 MUST 在 `idc-ai` 增加获取 `drh_speaker` 的内部接口，返回 `BaseResponse<SpeakerDO>`。
- **FR-005**：系统 MUST NOT 影响 `private-domain` 返回、旧字段、MQ、Redis key、OTS 查询或数据库写入。
- **FR-006**：单元测试 MUST 覆盖正常返回、缺失跳过、缓存命中和缓存过期。

## 成功标准

- **SC-001**：有效 `camp_date_id` 且 speaker 存在时，最终 JSON 返回 `speaker_name`。
- **SC-002**：无效或缺失数据时原有返回流程成功完成，且不返回错误默认值。
- **SC-003**：同一 speaker 6 小时内重复查询命中本地缓存。
- **SC-004**：`external-info-select` 测试通过，`idc-ai` 编译通过。

## 假设

- `drh_speaker.name` 是对外昵称，应作为 `speaker_name` 返回。
- `idc-ai` 可直接复用现有 `SpeakerService`/`SpeakerDO` 访问 `drh_speaker`。
- 新接口只服务内部调用，不单独增加鉴权逻辑，沿用网关和现有内部 token 访问方式。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 已在 `idc-ai` 增加 `GET /ai/getSpeakerInfoBySpeakerId?speakerId={speakerId}`，返回 `BaseResponse<SpeakerDO>`。
- 已在 `external-info-select` 增加营期查询、speaker 查询、6 小时 JVM 本地缓存，并在 legacy 返回 JSON 中追加 `speaker_name`。
- 已新增插件侧单元测试覆盖最终字段追加、空值跳过、缓存命中、缓存过期和响应解析。
- 已新增 idc-ai service 单元测试覆盖 `speakerId` 参数传递和空 id 跳过。
- 验证命令：
  - `mvn -f C:\workspace\ju-chat\coze_plugin\external-info-select\pom.xml "-Dmaven.test.skip=false" test`
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am "-DskipTests" compile`
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl ai -am "-Dtest=AiServiceImplSpeakerInfoTest" "-DfailIfNoTests=false" test`
- 验证结果：
  - `external-info-select`：Tests run: 20, Failures: 0, Errors: 0, Skipped: 0。
  - `kkhc-idc -pl ai -am compile`：BUILD SUCCESS。
  - `AiServiceImplSpeakerInfoTest`：Tests run: 2, Failures: 0, Errors: 0, Skipped: 0。
- 说明：直接执行 `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\ai\pom.xml "-DskipTests" compile` 会解析远端旧版 `ai-common`，因已有 `QwExternalTag*` 类型缺失失败；已用父工程 `-pl ai -am` 验证本地模块组合通过。

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题`
- 修正内容：`写清楚旧口径和新口径`
- 文档同步：`spec/tasks/AGENTS/checklist 是否已同步`
- 验证结果：`测试或静态检查结果`
