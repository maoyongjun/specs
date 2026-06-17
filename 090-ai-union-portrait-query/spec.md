# 功能规格：AI 用户画像聚合查询接口

**功能目录**：`090-ai-union-portrait-query`  
**创建日期**：`2026-06-15`  
**状态**：Draft  
**输入**：在 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai` 新增接口，按 `union_id` 查询用户画像，返回 4 个子对象：
- `userProfile.payStatus`：是/否（金额 > 880 元、已支付订单认为已支付；金额单位为分，SQL：`drh_collect_order` 中 `union_id=? and collect_pay_status in (2,3) and price > 88000`）。
- `teacherInfo`（体验课，**通过线索表 `drh_applet_user` 查询**）：`speakerName` 主讲（`camp_date_id→drh_live_camp_date.speaker_id→drh_speaker.name`）、`headTeacherName` 班主任（`emp_id→drh_kk_emp.name`）。
- `courseData`（正价课，**通过交接表 `drh_handover_plus` 取最近一个营期**）：`campName` 营期名（`drh_live_camp.name`）、`speakerName` 主讲（该营期 `drh_live.speaker_id→drh_speaker.name`，多个用顿号隔开）、`classTime` 营期开课时间（`drh_live_camp_group.start_class_time`，格式 `YYYY-MM-DD`，不是直播课开课时间）、`courseLink` 正价课小程序汇总路径（kapi `endpoint/qr/code/v2?appType=28&page=pages/subcontracting/schedule/index`，body `{"type":1,"id":campId}`，campId=`class_camp_id`，返回 base64 → 上传 OSS → 返回 URL）。
- `logisticsData`（list）：`hasDeliveredOrder` 是/否、`goodName` 商品名、`logisticsStatus`（未发货/运输中/已签收）、`trackingNumber` 物流单号、`logisticsLink` 物流链接（参考 `AppTask#setTushu`，`link_domain=https://mp.likeduoduiyi.cn`，查最近一个月；签收判定参考 `AiServiceImpl#processBookLogisticsSignReminder`）。
- 私域：`coze_plugin/external-info-select` 在 `external_key` 前缀为 `private-domain` 时取第 3 段 `externalUserId` 调本接口；后端经 `drh_emp_external_user` 把 `externalUserId` 转 `unionId`。

## 背景

- 当前问题：AI/SCRM（含私域）场景需要一次性拿到用户的支付状态、体验课师资、正价课信息和图书物流，目前分散在多张表/多个接口，没有聚合入口。
- 当前行为：`AiServiceImpl` 已有图书物流签收定时处理与实时物流查询；coze `AppTask` 已有 `private-domain` 分支返回基础画像，但不含上述 4 个子对象。
- 目标行为：新增 `POST /ai/userPortrait`，入参 `unionId` 或 `externalUserId`，返回 4 个子对象；私域分支调用该接口并合并结果。
- 非目标：不改非私域分支逻辑；不改 `RateLimitUtil`、定时任务触发；不改既有物流签收定时处理的语义；不新增数据库表。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 按 unionId 查询完整画像（优先级：P1）

当传入有效 `unionId` 时，系统返回该用户的支付状态、体验课师资、正价课信息和图书物流列表。

**独立测试**：mock 各底层 service，断言 4 个子对象按规则组装且各自查询参数正确。

**验收场景**：

1. **Given** 存在 `collect_pay_status in (2,3)` 且 `price>88000` 的订单，**When** 查询，**Then** `userProfile.payStatus="是"`，否则 `"否"`。
2. **Given** 用户有体验课营期（`is_class=0`），**When** 查询，**Then** `teacherInfo.speakerName` 取最近一节直播主讲，`headTeacherName` 取该营期 `emp_id` 对应班主任。
3. **Given** 用户有正价课营期（`is_class=1`），**When** 查询，**Then** `courseData` 取最近一个营期：`campName`、`speakerName`（营期组主讲去重后顿号拼接）、`classTime` 取自 `drh_live_camp_date` 且格式 `yyyy-MM-dd`、`courseLink` 为该 `campId` 的小程序码 OSS URL。
4. **Given** 用户近一个月有图书物流记录，**When** 查询，**Then** `logisticsData` 每条含 `hasDeliveredOrder/goodName/logisticsStatus/trackingNumber/logisticsLink`。

### 用户故事 2 - 私域 externalUserId 查询（优先级：P1）

当 coze 收到 `external_key` 前缀为 `private-domain` 时，取第 3 段 `externalUserId` 调用本接口，把 4 个子对象合并进私域返回。

**独立测试**：构造 `private-domain:agentId:externalUserId:userId:env`，断言取出 `externalUserId` 并调用 `/sae-gateway/kkhc-idc-ai/ai/userPortrait`；后端断言 `externalUserId` 经 `drh_emp_external_user` 解析为 `unionId`。

**验收场景**：

1. **Given** `external_key=private-domain:7644449532675866662:wmQcc1XAAASTjdIQEXwSlqxa3k3bMIFA:15311073569:default`，**When** 私域分支处理，**Then** 用 `externalUserId=wmQcc1XAAASTjdIQEXwSlqxa3k3bMIFA` 调后端接口并合并 4 个子对象。
2. **Given** 后端接口超时或异常，**When** 私域分支处理，**Then** 保持私域原有返回，记录日志，不阻断。
3. **Given** `externalUserId` 在 `drh_emp_external_user` 解析不到非空 `union_id`，**When** 查询，**Then** 返回空画像（各子对象默认值/空 list）。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `unionId`：来源入参；为空时由 `externalUserId` 经 `EmpExternalUserService`（`getOne(eq(externalUserid).isNotNull(unionId).ne(unionId,"").orderByDesc(id).last("limit 1"))`）解析；解析在所有子查询前完成。
  - `externalUserId`：来源入参（私域为 `external_key` 第 3 段）。
  - `phone`：来源 `LiveUserService.getLiveUserByUnionId(unionId).getPhone()`，兜底 `drh_applet_user` by union_id，再兜底 book 记录自带 phone；物流查询与 ShowAPI 调用前赋值。
  - `campId/campName/campClassTime`（正价课）：来源交接表"最近一个营期"查询（`drh_handover_plus → drh_live_camp → drh_live_camp_group`），查营期主讲/courseLink 前已确定。
  - `classTime`（正价课）：来源 `drh_live_camp_group.start_class_time`，格式化为 `yyyy-MM-dd`。
  - `goodsId`：来源物流记录；`goodName` 由 `GoodsService.getMapByIds` 现查。
  - kapi `type=1`、`id=campId`：当前层现算现用。
- 下游读取字段清单：
  - CollectOrder 查询读取 `union_id`、`collect_pay_status`、`price`。
  - 体验课查询读取 `applet_user.union_id/emp_id/camp_date_id`、`kk_emp.name`、`live_camp_date.speaker_id`、`speaker.name`。
  - 正价课查询读取 `handover_plus.union_id/class_camp_id/id`、`live_camp.name/group_id`、`live_camp_group.start_class_time`、`live(live_camp_id).speaker_id/is_del`、`speaker.name`。
  - 物流读取 `book_question_record`/`external_book_question_record` 的 `phone/union_id/l_ids/l_id/aes_id/type/goods_id/sign_status/create_time`。
  - kapi 读取响应 base64 字段；OSS 读取上传字节、path、content-type。
- 空对象 / 占位对象风险：
  - 不新增空 DTO 继续下传；某子对象查不到时给默认值（payStatus="否"、teacherInfo/courseData 字段空串、logisticsData 空 list），不传半成品 DTO。
- 调用顺序风险：
  - `unionId` 必须在 4 个子查询前解析完成；`campId` 必须在营期日期/主讲/courseLink 前确定；`phone` 必须在物流查询与实时 ShowAPI 前确定。无调用后赋值。
- 旧逻辑保持：
  - `AiServiceImpl` 物流签收定时处理、ShowAPI 调用（appKey、2650-6/2650-3、trace 104/112、超时、日志）抽取后行为不变。
  - coze 非私域分支、`setTushu`、`buildPrivateDomainUserInfo` 原有字段与异常处理保持。
- 需要用户确认的设计选择（均已确认）：
  - 物流状态先持久化 `sign_status`、非已签收再实时查（已确认）。
  - 体验课取最近一个营期（已确认）。
  - courseLink 按 campId 缓存复用（已确认）。
  - 私域接入与 externalUserId 入参（已确认）。

## 边界情况

- `unionId` 与 `externalUserId` 都为空或解析不到 unionId：返回空画像并记录日志。
- 无支付订单：`payStatus="否"`。
- 无体验课营期：`teacherInfo` 字段空串。
- 无正价课营期：`courseData` 字段空串，不调用 kapi/OSS。
- `drh_live_camp_date` 无记录：`classTime` 空串。
- 营期组无主讲：`speakerName` 空串。
- 无物流记录：`logisticsData` 空 list。
- 物流记录无 `l_ids/l_id`：`logisticsStatus="未发货"`、`hasDeliveredOrder="否"`、`trackingNumber` 空。
- `sign_status=2`：直接 `已签收`，不调 ShowAPI。
- ShowAPI 失败/超时：记录日志，状态降级为 `运输中`，不抛断整体。
- kapi 失败或返回非法 base64、OSS 上传失败：`courseLink` 空串并记录日志，不影响其它子对象。
- `phone` 解析失败：物流 list 为空或仅返回内部表（by union_id）结果。
- 私域后端调用异常：保持私域原返回。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 新增 `POST /ai/userPortrait`，入参支持 `unionId` 与 `externalUserId`，返回 `BaseResponse<AiUserPortraitOutput>`（4 个子对象）。
- **FR-002**：系统 MUST 在 `unionId` 为空时用 `externalUserId` 经 `drh_emp_external_user` 解析为最新非空 `union_id`。
- **FR-003**：`payStatus` MUST 由 `drh_collect_order`（`collect_pay_status in (2,3) and price>88000`）判定。
- **FR-004**：`teacherInfo` MUST 通过**线索表 `drh_applet_user`**（按 `union_id`，按线索 id 倒序取最近一条）查询：`headTeacherName` 取 `emp_id → drh_kk_emp.name`，`speakerName` 取 `camp_date_id → drh_live_camp_date.speaker_id → drh_speaker.name`。
- **FR-005**：`courseData` MUST 通过**交接表 `drh_handover_plus`**（按 `union_id`，按交接 id 倒序取最近一条）查询：`campId=class_camp_id`，`campName=drh_live_camp.name`，`classTime` MUST 取自 `drh_live_camp_group.start_class_time`（`drh_live_camp.group_id → drh_live_camp_group`）并格式化为 `yyyy-MM-dd`；`speakerName` 取该营期 `drh_live(live_camp_id=class_camp_id).speaker_id → drh_speaker.name` 去重后用顿号（、）拼接。
- **FR-006**：`courseLink` MUST 调 kapi 生成小程序码 base64 → 上传 OSS → 返回 URL，并 MUST 按 `campId` 缓存复用。
- **FR-007**：`logisticsData` MUST 取近一个月图书物流记录（内部 + 外部表），状态先读 `sign_status`，非已签收 MUST 实时查物流 API（`104→已签收`，否则 `运输中`，无单号 `未发货`）。
- **FR-008**：`logisticsLink` MUST 使用可配置域名（默认 `https://mp.likeduoduiyi.cn`）拼接 `/logisticsDetailV2.html?aesId=&type=`。
- **FR-009**：coze `AppTask` 私域分支 MUST 取 `external_key` 第 3 段 `externalUserId` 调用本接口并把 4 个子对象合并进私域返回。
- **FR-010**：系统 MUST NOT 改变非私域分支逻辑、物流签收定时处理语义和 `RateLimitUtil`。
- **FR-011**：单元测试 MUST 断言下游参数（CollectOrder 条件、kapi 请求体、OSS 上传入参、物流状态映射、externalUserId→unionId 解析、缓存命中不重复调用）。

## 成功标准 *(必填)*

- **SC-001**：传入真实 `union_id` 时 4 个子对象按规则正确返回；`classTime` 来自 `drh_live_camp_date` 且为 `yyyy-MM-dd`。
- **SC-002**：私域 `external_key` 能解析出 `externalUserId` 并合并 4 个子对象；后端异常时私域原返回不受影响。
- **SC-003**：`courseLink` 同一 `campId` 第二次查询命中缓存，不再调用 kapi/OSS。
- **SC-004**：`AiServiceImpl` 实时物流查询抽取后行为不变；非私域逻辑无回归。

## 假设

- kapi `endpoint/qr/code/v2` 返回体含 base64 图片字段（具体字段名与是否带 `data:` 前缀在 Phase 1 实测确认）。
- 体验课线索挂在 `drh_applet_user`（含 `union_id/emp_id/camp_date_id`）；正价课学员挂在交接表 `drh_handover_plus`（含 `union_id/class_camp_id`）。
- 一个 union_id 在线索表/交接表可能多行，按 `id` 倒序取最近一条。
- `live_user.phone` 可用于物流查询（明文或可得后 4 位）；不可得时物流降级。
- 新接口响应统一为 AiController 的 `BaseResponse{code,message,data}`，coze 取 `data`。
- 私域 `external_key` 为 5 段冒号分隔，第 3 段为 `externalUserId`（已由现有 `parsePrivateDomainExternalKey` 确认）。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档（AGENTS/spec/tasks/checklist）。
- 已完成历史问题防漏分析和强制门禁检查；4 项设计选择已与用户确认。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
  - ai-common 新增 `AiUserPortraitInput` 与 `AiUserPortraitOutput`（含 `UserProfile/TeacherInfo/CourseData/LogisticsData`）。
  - ai 新增 `AiUserPortraitMapper`(+XML)：体验课最近营期主讲/班主任、正价课最近营期、营期组主讲去重、营期开课时间（`drh_live_camp_date`）。
  - ai 新增 `AiUserPortraitService`/`AiUserPortraitServiceImpl`（放 `crm.service.ai.impl` 包内，复用 `AiServiceImpl.queryBookLogisticsDetail`/`getEmpExternalUserDO`）。
  - `AiController` 新增 `POST /ai/userPortrait`。
  - coze `external-info-select` 的 `AppTask.buildPrivateDomainUserInfo` 调用 `/sae-gateway/kkhc-idc-ai/ai/userPortrait`（传 externalUserId），合并 4 个子对象。
- 影响范围：新增端点 + 新增 Redis 缓存 key（`ai:user-portrait:course-link:{campId}`，7 天）+ coze 私域分支新增一处 HTTP 调用；未改 `AiServiceImpl` 既有逻辑、未改 coze 非私域分支。
- 测试命令：`mvn -s settings.xml -o -pl ai -am test -Dtest=AiUserPortraitServiceImplTest`；`mvn -o -pl external-info-select -am compile`（coze）。
- 测试结果：ai-common compile 通过；ai test-compile 通过；`AiUserPortraitServiceImplTest` 16 用例全部通过（Failures:0 Errors:0）；coze 模块 compile 通过。
- 自检结论：payStatus/体验课/正价课/物流四子对象按规则组装；`classTime` 取自 `drh_live_camp_date`；物流状态混合策略（sign_status=2 走持久化、否则实时 104）；courseLink 按 campId 缓存命中不再调 kapi/OSS（已测）；externalUserId 经 `drh_emp_external_user` 解析（已测）。

### D003 - 实现取舍：实时物流复用而非抽取

- 触发原因：原计划抽取 `AiServiceImpl.queryBookLogisticsDetail` 为独立 `BookLogisticsApiClient`，但该方法位于 2900+ 行的 `AiServiceImpl` 且与签收定时流程耦合，抽取风险高。
- 修正内容：旧口径=抽取并让 `AiServiceImpl` 委托新组件；新口径=`AiUserPortraitServiceImpl` 置于同包 `com.kkhc.idc.crm.service.ai.impl`，直接复用 `AiServiceImpl` 的包级可见方法 `queryBookLogisticsDetail`（及 `getEmpExternalUserDO`），`AiServiceImpl` 零改动，行为完全不变。
- 文档同步：已更新 `spec.md`（本记录）、`tasks.md`、`AGENTS.md`（重点代码位置去掉 BookLogisticsApiClient）。
- 验证结果：`AiUserPortraitServiceImplTest` 通过；`ai` test-compile 通过；`AiServiceImpl` 未改动。

### D006 - 修复 courseLink base64 解码报错（Illegal base64 character 22）

- 触发原因：线上 `campId=17147` 报 `java.lang.IllegalArgumentException: Illegal base64 character 22`（0x22=`"`）。根因：kapi `qr/code/v2` 响应体疑似为 **JSON 引号包裹的字符串**（如 `"<base64>"`），旧 `extractBase64` 兜底分支返回了带引号原文，`Base64.getDecoder().decode` 遇到首个 `"` 抛异常。
- 修正内容：
  - `extractBase64` 改用 `JSON.parse`，识别 (a) JSON 字符串体→直接返回去引号值、(b) `{data:"..."}`/`{data:{...}}`、(c) `qr_code/qrCode/base64/...` 字段、(d) 非 JSON 原文。
  - 新增 `sanitizeBase64`（去首尾引号、去 `data:` 前缀、去空白）+ `decodeBase64Image`（用 `Base64.getMimeDecoder()` 容错解码，失败返回 null 不抛异常）。
  - `resolveCourseLink` 改用 `decodeBase64Image`，解码失败仅 `warn` 记录 `candidatePrefix` 并返回空串，不再抛异常。
- 文档同步：本记录（spec.md）。
- 验证结果：新增 `extractBase64_jsonQuotedStringBody`/`sanitizeBase64_*`/`decodeBase64Image_*` 用例（含复现引号场景）；`AiUserPortraitServiceImplTest` Tests run: 19, Failures: 0, Errors: 0。
- 仍需确认：kapi 响应真实结构（请提供 `user_portrait_course_link_qr` info 日志的 raw resp），以确认提取到的是正确字段、生成图片可用。

### D005 - 数据来源调整：体验课走线索表、正价课走交接表

- 触发原因：用户要求体验课通过线索表查询、正价课通过交接表查询。
- 修正内容：
  - 体验课旧口径=`drh_live_user → drh_live_camp_user → drh_live_camp(is_class=0) → drh_live → drh_speaker/drh_kk_emp`；新口径=`drh_applet_user`（按 `union_id`，`id` 倒序取一条）→ `emp_id→drh_kk_emp.name`(班主任) + `camp_date_id→drh_live_camp_date.speaker_id→drh_speaker.name`(主讲)。
  - 正价课旧口径=`drh_class_user → drh_class_user_permission → drh_live_camp(is_class=1)`，主讲取 `drh_group_live`，classTime 取 `drh_live_camp_date.class_time`；新口径=`drh_handover_plus`（按 `union_id`，`id` 倒序取一条）→ `class_camp_id` → `drh_live_camp`(campName) → `drh_live_camp_group.start_class_time`(classTime)；主讲取该营期 `drh_live(live_camp_id).speaker_id→drh_speaker.name` 去重顿号拼接。
  - mapper：`selectLatestTrialTeacher` 改线索表；`selectLatestClassCamp` 改交接表并返回 `ClassCampInfo{campId,campName,campClassTime}`；删除 `selectGroupSpeakerNames`/`selectCampClassTime`，新增 `selectCampSpeakerNames(campId)`。courseLink 仍按 `campId(=class_camp_id)` 生成与缓存。
- 文档同步：已更新 `spec.md`(FR-004/005、防漏分析、假设、本记录)、`tasks.md`、`AGENTS.md`。
- 验证结果：`ai` 重新编译通过；`AiUserPortraitServiceImplTest` 16 用例回归通过（纯函数与缓存逻辑不受数据源调整影响）。

### D004 - 待确认项

- 触发原因：编码期存在两处需后续确认的口径。
- 修正内容：
  1. kapi `endpoint/qr/code/v2` 响应 base64 字段名/前缀无法在工作区核实（无服务端实现与调用方），`extractBase64` 采用兼容多字段（data/qr_code/qrCode/base64/url）+ 去 `data:` 前缀 + 兜底原文的防御式解析，`requestCourseLinkBase64` 可覆写，待真实联调确认。
  2. 返回字段已按用户确认由 `hasDeliveredOrde` 更正为 `hasDeliveredOrder`（`LogisticsData` 字段 + `AiUserPortraitServiceImpl` setter 同步更新）。
- 文档同步：已记录于 `spec.md`/`tasks.md`。
- 验证结果：kapi 字段联调时核实；`hasDeliveredOrder` 已重新编译 + 16 用例回归通过。
