# 功能规格：手机号安全补充接口整改

**功能目录**：`073-phone-security-additional-interface-remediation`  
**创建日期**：`2026-06-11`  
**状态**：Draft（文档创建完成；未进入代码整改）  
**输入**：在此前手机号加密字段处理基础上，补充 `drh_leads_noqw_send_msg_task_detail`、`drh_applet_player` 涉及接口；用户后续补充要求包括 `drh_sms_deal` 表以及相关 XML。

## 背景

- 当前问题：历史规格已覆盖大量手机号安全字段、DDL、回填和接口差异，但仍有补充接口和 XML 写入点需要单独记录，避免后续实现只修查询、不修输出或只修字段、不修 XML。
- 当前行为：
  - `drh_leads_noqw_send_msg_task_detail`：`LeadsNoqwSendMsgTaskDetailServiceImpl` 仍按 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 过滤；`lms-common` / `ai-common` 的 DO 只有 `phone`，缺 `phoneMask/phoneMd5/phoneAes`。
  - `drh_applet_player`：`AppletPlayerServiceImpl` 已计算 `phoneMd5`，`AppletPlayerMapper.xml` 已按 `ap.phone_md5` 查询；但 Mapper 使用 `select ap.*`，`AppletPlayOutput` 仍有 `@CsvField("手机号") private String phone`，列表和导出存在明文输出风险。
  - `drh_sms_deal`：`HandoverPlusMapper.xml` 的 `saveSmsDtosBatch` 直接 `INSERT IGNORE into drh_sms_deal (..., phone, ...) VALUES (#{item.phone}...)`，4 个 SELECT 只读取 `lu.phone`。
- 目标行为：
  - 明文 `phone` 入参继续兼容，服务端内部转换为 `phoneMd5` 查询。
  - 列表、详情、上一条/下一条和导出中的 `phone` 字段保留字段名，但值必须为掩码。
  - 创建、更新、任务生成和 XML 批量插入链路保存前补齐 `phone_mask/phone_md5/phone_aes`。
- 非目标：本规格不修改业务代码，不新增 DDL，不执行历史回填，不调整接口路径、HTTP 方法、分页参数、导出文件结构、短信发送模板或任务调度方式。

## 用户场景与测试

### 用户故事 1 - 无企微任务明细按安全字段查询和展示（优先级：P1）

运营或系统按手机号筛选无企微任务明细时，后端应按 `phone_md5` 查询；页面、详情和导出不能暴露明文手机号。

**独立测试**：用完整明文手机号调用 `/leads-noqw-send-msg-task-detail/pageList`、`/listAll`、`/exportList`，确认命中 `phone_md5` 条件，响应和导出不含明文手机号。

**验收场景**：

1. **Given** 请求体包含合法手机号，**When** 查询任务明细，**Then** 查询条件落到 `phone_md5`，返回 `phone` 为掩码。
2. **Given** 请求体包含非法手机号，**When** 查询任务明细，**Then** 返回空结果或显式失败，不得忽略手机号条件扩大结果。
3. **Given** 创建或更新任务明细包含手机号，**When** 保存记录，**Then** `phone_mask/phone_md5/phone_aes` 同步写入。

### 用户故事 2 - 小程序选手接口不输出明文（优先级：P1）

后台查看、导出或切换小程序大赛选手详情时，按手机号筛选继续使用 `phone_md5`，所有展示面都输出掩码手机号。

**独立测试**：调用 `/applet/activity/detail/page`、`/applet/activity/detail/export`、`/applet/activity/preNext`、`/applet/activity/player/detail`，确认手机号输出为掩码。

**验收场景**：

1. **Given** 请求包含完整手机号，**When** 查询大赛详情分页，**Then** 使用 `ap.phone_md5` 查询且响应 `phone` 为掩码。
2. **Given** 执行大赛详情导出，**When** 生成 CSV，**Then** `手机号` 列不含明文手机号。
3. **Given** 通过上一条/下一条或作品详情查看选手，**When** 返回单条记录，**Then** `phone` 不为明文。

### 用户故事 3 - 短信处理日志 XML 写入安全字段（优先级：P2）

短信处理任务写入 `drh_sms_deal` 时，日志表保留原 `phone` 字段兼容旧逻辑，同时写入可查询和展示用的安全字段。

**独立测试**：执行 `DTask` / `DTaskV2` / `MTask` 的保存路径，断言 `HandoverPlusMapper.xml saveSmsDtosBatch` 的 INSERT 列和值包含 `phone_mask/phone_md5/phone_aes`。

**验收场景**：

1. **Given** `DealSmsDto` 从 `drh_live_user` 查询得到手机号信息，**When** 批量插入 `drh_sms_deal`，**Then** `phone_mask/phone_md5/phone_aes` 与 `phone` 同步落库。
2. **Given** `DealSmsDto.phone` 由后续 `processInBatches` 补齐，**When** 保存短信处理记录，**Then** 保存前必须现算或补齐安全字段。
3. **Given** 外部短信发送仍需要明文手机号，**When** 发送短信，**Then** 外部请求可使用受控明文，库内日志和后续查询优先使用安全字段。

## 补充接口与影响表矩阵

| 优先级 | 模块 | 接口 / 入口 | 影响表 | 当前证据 | 目标口径 | 验证要点 |
|---|---|---|---|---|---|---|
| P1 | `kkhc-idc app/lms/ai`、`kkhc-bizcenter lms` | `/leads-noqw-send-msg-task-detail/exportList`、`/listAll`、`/pageList`、`/{id}`、`/create`、`/update`，以及页面导出入口 | `drh_leads_noqw_send_msg_task_detail` | `LeadsNoqwSendMsgTaskDetailServiceImpl:121` 仍 `LeadsNoqwSendMsgTaskDetailDO::getPhone`；DO 缺安全字段 | 查询 `phone -> phone_md5`；返回和导出展示 `phone_mask`；保存写 `phone_*` | 明文手机号查询命中 `phone_md5`；非法手机号不扩大结果；响应和导出不含明文 |
| P1 | `drh-kk-cms` | `/applet/activity/detail/page`、`/detail/export`、`/preNext`、`/player/detail` | `drh_applet_player` | `AppletPlayerServiceImpl:104/187/237` 已算 `phoneMd5`；`AppletPlayerMapper.xml:30` `select ap.*`；`AppletPlayOutput:46` 导出手机号字段 | 保持 `ap.phone_md5` 查询；输出 `phone` 改掩码；必要时 DTO 兼容新增 `phoneMask/phoneMd5/phoneAes` | 分页、导出、上一条/下一条、详情均不输出明文手机号 |
| P2 | `drh-media-process` | `/smsDeal/DTask`、`/smsDeal/MTask`、XXL Job `DTaskV2`；`HandoverPlusMapper.xml saveSmsDtosBatch` | `drh_sms_deal` | `HandoverPlusMapper.xml:5` INSERT 只写 `phone`；`:17/:46/:73/:97` SELECT 只读 `lu.phone`；`DealSmsDto` 缺安全字段 | XML SELECT 读 `lu.phone_mask/phone_md5/phone_aes`；DTO 补字段；INSERT 写 `phone_mask/phone_md5/phone_aes` | `saveSmsDtosBatch` 绑定安全字段；后补手机号路径保存前同步生成安全字段 |

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `LeadsNoqwSendMsgTaskDetailCondition.phone`：来自 HTTP body / Feign DTO；构造 Wrapper 前计算 `phoneMd5`。
  - `LeadsNoqwSendMsgTaskDetailDO.phone`：来自任务生成、创建或更新链路；保存前同步生成 `phoneMask/phoneMd5/phoneAes`。
  - `AppletPlayerInput.phone`：来自页面查询或导出请求；`AppletPlayerServiceImpl` 已在 Mapper 前计算 `phoneMd5`。
  - `AppletPlayOutput.phone`：来自 `AppletPlayerMapper.xml select ap.*`；返回或导出前必须覆盖为掩码。
  - `DealSmsDto.phone`：来自 `HandoverPlusMapper.xml` 查询 `drh_live_user.phone` 或 `SendSmsTaskServiceImpl.processInBatches` 后补；进入 `saveSmsDtosBatch` 前必须携带或生成安全字段。
- 下游读取字段清单：
  - MyBatis-Plus Wrapper 读取 `LeadsNoqwSendMsgTaskDetailDO::getPhone`，目标改为 `getPhoneMd5`。
  - `AppletPlayerMapper.xml` 读取 `input.phoneMd5`、返回 `ap.*`。
  - `HandoverPlusMapper.xml` 读取 `item.phone` 并写入 `drh_sms_deal`，目标增加读取和写入 `phoneMask/phoneMd5/phoneAes`。
  - 导出 DTO 读取 `phone` 字段，目标值必须是掩码。
- 空对象 / 占位对象风险：
  - `DealSmsDto` 可能先只有 `unionId`、后续再通过 `processInBatches` 补 `phone`；不能只补明文 `phone` 后直接写库。
  - `LeadsNoqwSendMsgTaskDetailDO` 的创建/更新接口不能只接受并保存明文 `phone`。
- 调用顺序风险：
  - 不允许先按明文字段查询，再只在前端展示时脱敏。
  - 不允许 `drh_sms_deal` 先插入明文，后续依赖异步回填作为唯一保障。
- 旧逻辑保持：
  - 不改变接口路径、HTTP 方法、分页、权限、导出列名、短信模板、任务调度和外部短信发送的必要明文使用。
  - `drh_applet_player` 已有 `phone_md5` 查询口径保持，不回退到 `phone`。
  - `drh_sms_deal.unoin_id` 历史字段拼写保持，不在本规格重命名。
- 需要用户确认的设计选择：
  - 无。用户已补充要求将 `drh_sms_deal` 表及 XML 纳入本规格；DDL 已由 `051/069` 覆盖，本规格只定义接口/XML 实现整改。

## 边界情况

- 手机号为空：保留原非手机号过滤逻辑，不额外构造 `phoneMd5` 条件；保存链路若无手机号，则安全字段保持空。
- 手机号非法：查询返回空结果或显式失败，不得忽略手机号条件导致全量返回。
- 输入已是 32 位 MD5：沿用既有 `computePhoneMd5` 兼容口径，小写归一。
- 历史安全字段为空：展示优先 `phoneMask`，缺失时按模块既有工具从 `phoneAes` 生成掩码；均为空时返回空或记录风险。
- 外部短信发送：明文手机号只允许用于供应商请求和本次发送内存集合，不用于日志表查询或持久化匹配。
- 导出接口：导出列名保持原名称，手机号值必须是掩码。

## 需求

### 功能需求

- **FR-001**：系统 MUST 为 `LeadsNoqwSendMsgTaskDetailDO`、Condition、Output、Excel DTO 的相关副本补齐 `phoneMask/phoneMd5/phoneAes` 或等价安全字段口径。
- **FR-002**：系统 MUST 将 `/leads-noqw-send-msg-task-detail/*` 的手机号查询由 `phone` 改为 `phoneMd5` / `phone_md5`。
- **FR-003**：系统 MUST 保证任务明细列表、详情和导出不输出明文手机号。
- **FR-004**：系统 MUST 在任务明细创建、更新和任务生成链路保存前生成 `phone_mask/phone_md5/phone_aes`。
- **FR-005**：系统 MUST 保持 `drh_applet_player` 已有 `phone_md5` 查询，并补齐分页、导出、上一条/下一条和详情的掩码输出。
- **FR-006**：系统 MUST 为 `DealSmsDto` 补齐 `phoneMask/phoneMd5/phoneAes`，并在 `HandoverPlusMapper.xml` SELECT 与 INSERT 中同步安全字段。
- **FR-007**：系统 MUST 在 `DealSmsDto.phone` 后补路径中同步生成安全字段，不能只补明文后直接落 `drh_sms_deal`。
- **FR-008**：系统 MUST NOT 修改接口路径、HTTP 方法、分页参数、导出列名、短信模板、任务调度方式或 `drh_sms_deal.unoin_id` 字段拼写。
- **FR-009**：系统 MUST NOT 新增 DDL 或历史回填脚本；`phone_*` 字段和索引依赖 `051/069` 已定义内容。

## 成功标准

- **SC-001**：`rg` 确认 `LeadsNoqwSendMsgTaskDetailDO::getPhone` 不再作为手机号查询条件，已替换为 `phoneMd5` 查询。
- **SC-002**：任务明细列表、详情和导出样例均不含 11 位明文手机号。
- **SC-003**：`drh_applet_player` 四个入口响应/导出均不含明文手机号，且 `ap.phone_md5` 查询不回退。
- **SC-004**：`HandoverPlusMapper.xml saveSmsDtosBatch` 的 INSERT 列和值包含 `phone_mask/phone_md5/phone_aes`。
- **SC-005**：`HandoverPlusMapper.xml` 四个短信 SELECT 均取出 `lu.phone_mask/lu.phone_md5/lu.phone_aes` 或等价别名。
- **SC-006**：目标模块编译或针对性单测通过；无法运行时必须记录环境阻塞和静态验证结果。

## 假设

- `drh_leads_noqw_send_msg_task_detail`、`drh_applet_player`、`drh_sms_deal` 的 `phone_mask/phone_md5/phone_aes` 列和索引已由 `051/069` 规格覆盖。
- 历史数据回填由既有 `juzi-service` 回填治理规格负责，本规格不重复定义回填。
- `drh_applet_player` 的手机号搜索只支持完整手机号精确匹配，不恢复模糊搜索。
- 各模块使用本模块既有手机号安全工具，不跨项目强行引用其他工程工具类。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `073-phone-security-additional-interface-remediation` 规格目录，补充 `drh_leads_noqw_send_msg_task_detail`、`drh_applet_player`、`drh_sms_deal` 三个对象的接口和 XML 整改规格。
- 验证方式：用 `rg` / `Get-Content` 静态确认接口、Service、DTO、Mapper XML 和历史规格证据。
- 自检结论：本阶段仅新增文档；未修改业务代码、DDL、SQL、回填脚本或历史规格目录。

### D002 - 实现记录模板

- 实现内容：`逐项记录字段补齐、查询改造、掩码输出、XML SELECT/INSERT 改造。`
- 测试命令：`记录 Maven/JUnit/静态搜索命令。`
- 测试结果：`记录通过、失败和环境阻塞。`
- 自检结论：`确认 phoneMd5 查询、掩码返回、保存生成安全字段、XML 安全字段写入均满足规格。`

### D003 - 纠正记录模板

- 触发原因：`用户补充/测试失败/代码审查发现/当前代码状态变化。`
- 修正内容：`说明旧口径和新口径。`
- 文档同步：`说明同步了哪些文件。`
- 验证结果：`说明静态搜索、接口测试或编译结果。`
