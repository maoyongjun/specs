# 功能规格：MyBatis XML 手机号 MD5 查询兼容

**功能目录**：`041-mybatisplus-xml-phone-md5-query`  
**创建日期**：`2026-05-29`  
**状态**：Draft  
**输入**：用于处理 MyBatis-Plus / MyBatis XML 中按手机号查询的问题。手机号安全改造后，原 `phone` 字段后续会清空，历史 XML 中不能继续通过 `phone` 查询。例如 `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\BookQuestionRecordServiceImpl.java` 的 `queryHistoryExpressNoListCount` 调用链，必须通过 `phone_md5` 查询。除该 XML 外，也必须全量扫描其他 Mapper XML 是否存在同类问题，包括 `phone = #{...}`、`phone in (...)`、`phone like ...`、`phone is not null`、`phone` join 和直接 select / display `phone`。前端查询接口仍使用 `phone` 属性传入，可能传明文手机号、前端加密手机号或 MD5 手机号；保存和更新接口只能传明文手机号或前端加密手机号，不能传 MD5，传错时返回参数错误并提示 `手机号加密格式不符`。

## 背景

- 当前问题：手机号加密改造后，目标表原 `phone` 明文字段后续会清空，XML Mapper 中残留的 `phone = #{input.phone}`、`phone` join、`phone like` 或 `phone is not null` 等逻辑会导致查询不到数据、筛选条件失真或展示异常。
- 当前行为：部分 Java Service 已通过 `DataSecurityInvoke.computePhoneMd5(...)` 使用 `phone_md5` 查询，但 `ExternalBookQuestionRecordMapper.xml` 等 XML 仍直接读取 `input.phone` 与 `phone` 字段比较。
- 目标行为：所有 Mapper XML 中的手机号使用点都必须先全量扫描并分级处理；目标表按手机号等值查询改为 `phone_md5 = #{input.phoneMd5}`，Java 层在进入 Mapper 前根据接口类型准备 `phoneMd5`。
- 非目标：本阶段只编写规格文档，不修改 Java、XML、SQL、测试代码；不扩展到非手机号安全目标表的历史查询。

## 用户场景与测试 *(必填)*

### 用户故事 1 - XML 查询不再依赖明文 phone（优先级：P1）

当用户通过历史图书登记、历史快递单号等接口按手机号查询时，即使数据库 `phone` 字段已清空，系统也必须通过 `phone_md5` 命中记录。

**独立测试**：清空测试记录的 `phone`，保留 `phone_md5`，调用相关查询接口后仍返回正确结果。

**验收场景**：

1. **Given** `drh_book_question_record` 或 `drh_external_book_question_record` 的 `phone` 已清空且 `phone_md5` 有值，**When** 调用历史快递单号校验，**Then** 查询 SQL 使用 `phone_md5 = ?` 并能返回匹配计数。
2. **Given** XML Mapper 中存在 `queryHistoryExpressNoListCount`、`queryHistoryExpressNoList` 或 `queryHistoryPage*` 查询，**When** 传入手机号条件，**Then** XML 不再使用 `phone = #{input.phone}`。

### 用户故事 1.5 - 全量检查其他 Mapper XML（优先级：P1）

研发在实现前必须扫描 `drh` 和 `ju-chat` AI 相关工程的所有 Mapper XML，识别是否存在同类明文手机号依赖，并将每个命中点标记为需改造、需业务确认或可排除。

**独立测试**：执行 XML 扫描命令，输出所有包含 `phone` 条件、join、like、null 判断或 select 展示的 XML 命中点，并在任务记录中完成分类。

**验收场景**：

1. **Given** Mapper XML 中存在 `phone = #{...}` 或 `xxx.phone = yyy.phone`，**When** 所属表已具备 `phone_md5`，**Then** 该查询必须纳入改造，改为 `phone_md5` 等值或 join。
2. **Given** Mapper XML 中存在 `phone like concat(...)`，**When** 手机号明文会清空，**Then** 该功能必须标记为需业务确认，不能默认继续按明文模糊查询。
3. **Given** Mapper XML 中存在 `phone is not null`、`select phone` 或展示手机号，**When** 所属表手机号明文会清空，**Then** 必须评估是否改为 `phone_md5 is not null`、`phone_mask` 或 `phone_aes` 解密展示。

### 用户故事 2 - 查询接口兼容三种 phone 入参（优先级：P1）

前端查询接口保持 `phone` 属性名不变，允许传明文手机号、前端加密手机号或 MD5 手机号，后端统一转换或识别为 `phoneMd5` 查询。

**独立测试**：同一条记录分别用三种 `phone` 入参查询，返回结果一致。

**验收场景**：

1. **Given** 查询接口传入明文手机号，**When** Java 层处理参数，**Then** 使用现有 `computePhoneMd5(phone)` 计算 `phoneMd5` 并传入 XML。
2. **Given** 查询接口传入前端加密手机号，**When** Java 层处理参数，**Then** 沿用现有解密 / 规范化兼容逻辑计算 `phoneMd5` 并传入 XML。
3. **Given** 查询接口传入 32 位 MD5 手机号，**When** Java 层处理参数，**Then** 直接将该值作为 `phoneMd5`，不再二次计算 MD5。

### 用户故事 3 - 保存和更新接口拒绝 MD5 手机号（优先级：P1）

保存和更新接口仍使用 `phone` 属性，但只能接收明文手机号或前端加密手机号；如果误传 MD5 或无法识别为有效手机号，应明确提示参数错误。

**独立测试**：保存 / 更新接口传入 32 位 MD5 字符串，接口返回参数错误，提示 `手机号加密格式不符`。

**验收场景**：

1. **Given** 保存接口传入明文手机号，**When** 执行保存，**Then** 正常生成 `phone_mask`、`phone_md5`、`phone_aes`。
2. **Given** 保存接口传入前端加密手机号，**When** 执行保存，**Then** 正常解密并生成安全字段。
3. **Given** 保存或更新接口传入 32 位 MD5 字符串，**When** 校验手机号入参，**Then** 返回参数错误并提示 `手机号加密格式不符`，不得写入数据。
4. **Given** 保存或更新接口传入无法解密且不是有效明文手机号的字符串，**When** 校验手机号入参，**Then** 返回参数错误并提示 `手机号加密格式不符`。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phone`：来源于前端请求 DTO，字段名保持不变；查询接口允许明文、前端加密密文、MD5；保存 / 更新接口只允许明文或前端加密密文。
  - `phoneMd5`：来源于 Java 层根据 `phone` 计算或识别；必须在调用 XML Mapper 前赋值完成。
  - `expressNoList`、`goodsId`：来源于原请求 DTO，保持原过滤语义不变。
- 下游读取字段清单：
  - `ExternalBookQuestionRecordMapper.queryHistoryExpressNoListCount` 读取 `input.phoneMd5`、`input.goodsId`、`input.expressNoList`。
  - `ExternalBookQuestionRecordMapper.queryHistoryExpressNoList` 读取 `input.phoneMd5`、`input.goodsId`。
  - `ExternalBookQuestionRecordMapper.queryHistoryPage*` 读取 `input.phoneMd5` 及原有 `empId`、`systemEmpId`、`source`。
  - 其他 Mapper XML 命中点必须在实现前补充下游读取字段清单，不能只处理 `ExternalBookQuestionRecordMapper.xml`。
- 空对象 / 占位对象风险：
  - 存在 `new CreateExternalBookQuestionRecordDto()` 后只 set 部分字段再传入 XML 的场景，必须确保调用 Mapper 前已 set `phoneMd5`。
  - 对已有 DTO 增加 `phoneMd5` 字段时，不能只在部分入口赋值，所有调用目标 XML 的入口都要覆盖。
- 调用顺序风险：
  - 必须先校验 / 识别 `phone` 入参，再计算或赋值 `phoneMd5`，最后调用 Mapper。
  - 禁止在 Mapper 调用后才补 `phoneMd5`。
- 旧逻辑保持：
  - `goodsId`、`expressNoList`、`empId`、`systemEmpId`、`source`、`AI-%` 与 `H5-用户提交` 等原有过滤条件不变。
  - 原接口字段名 `phone` 不变，避免前端改造。
  - 保存 / 更新链路的安全字段生成逻辑不改变，只增加 MD5 入参拒绝规则。
- 全量 XML 扫描初始命中提示：
  - `drh-kk-cms` 中还需重点复查 `WorksShipMapper.xml`、`WorksAwardsRecordMapper.xml`、`UserQuestionMapper.xml`、`SpecailUserMapper.xml`、`RenewDataMapper.xml`、`OrderHandRecordMapper.xml`、`OrderHandRecordDelMapper.xml`、`LiveCampUserMapper.xml`、`HandoverPlusMapper.xml`、`DayUrgeClassMapper.xml`、`AppletUserPoolMapper.xml`、`AppletUserMapper.xml`、`AppletSalePoolMapper.xml`、`AppletPlayerMapper.xml`、`AdUserPicMapper.xml`、`HandoverMapper.xml`。
  - `drh` 其他模块还需复查 `drh-app/drh-provider/drh-platform` 的 `AppStudyInfoMapper.xml`、`drh-cms` 的 `RegisterWorksMapper.xml`、`drh-media-process` 的 `AppletUserMapper.xml`、`drh-my-sync` 的 `AppletUserMapper.xml`。
  - `ju-chat/kkhc/kkhc-idc/ai` 还需复查 `OrderBookReissueMapper.xml` 和 `AppletUserMapper.xml`。
  - 上述清单来自初始静态搜索，后续实现前必须重新执行扫描并以最新结果为准。
- 需要用户确认的设计选择：
  - 无。用户已明确：查询接口兼容 MD5；保存 / 更新接口不接受 MD5，错误提示为 `手机号加密格式不符`。

## 边界情况

- 查询接口 `phone` 为空：保持原查询条件跳过或原接口参数校验口径，不新增强制报错。
- 查询接口 `phone` 为 32 位 MD5：直接作为 `phoneMd5` 查询，大小写按数据库存储口径统一处理，必要时在 Java 层归一化。
- 查询接口 `phone` 为前端加密密文：沿用现有 `computePhoneMd5` 的兼容逻辑。
- 查询接口 `phone` 为非法字符串且无法计算 MD5：不进入 `phone_md5` 条件或返回空结果，具体按原接口异常口径处理。
- XML 中 `phone like`：MD5 不支持模糊匹配，必须业务确认改为精确查询、前端禁用模糊搜索或另设脱敏搜索方案。
- XML 中 `phone is not null` / `phone is null`：若所属表 `phone` 会清空，必须改为安全字段判断或重新确认业务含义。
- XML 中 `select phone` / 返回 `phone`：若用于展示，必须评估改为 `phone_mask`；若用于下游明文调用，必须评估从 `phone_aes` 解密。
- 保存 / 更新接口 `phone` 为 32 位 MD5：返回参数错误，提示 `手机号加密格式不符`。
- 保存 / 更新接口 `phone` 无法解密且不是有效明文手机号：返回参数错误，提示 `手机号加密格式不符`。
- 历史数据 `phone` 已清空：目标 XML 查询不得依赖 `phone` 字段。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 将目标 XML 中按手机号等值查询的条件从 `phone = #{input.phone}` 改为 `phone_md5 = #{input.phoneMd5}`。
- **FR-002**：系统 MUST 全量扫描 Mapper XML 中所有手机号使用点，包括等值、IN、LIKE、JOIN、NULL 判断和 SELECT 展示，并记录分类结果。
- **FR-003**：系统 MUST 在调用目标 XML Mapper 前为请求 DTO 准备 `phoneMd5` 字段。
- **FR-004**：查询接口 MUST 保持 `phone` 属性名不变，并兼容明文手机号、前端加密手机号和 32 位 MD5 手机号。
- **FR-005**：查询接口收到 32 位 MD5 手机号时 MUST 直接作为 `phoneMd5` 使用，不得二次计算 MD5。
- **FR-006**：保存和更新接口 MUST 只接受明文手机号或前端加密手机号。
- **FR-007**：保存和更新接口 MUST NOT 接受 MD5 手机号；传入 MD5 或无法识别 / 解密为有效手机号时，必须返回参数错误并提示 `手机号加密格式不符`。
- **FR-008**：系统 MUST 保持原有 `goodsId`、`expressNoList`、`empId`、`source` 等非手机号过滤条件不变。
- **FR-009**：本阶段 MUST 只创建规格文档，不修改业务代码。

## 成功标准 *(必填)*

- **SC-001**：规格文档明确区分查询接口与保存 / 更新接口的 `phone` 入参规则。
- **SC-002**：规格文档明确列出 XML 使用 `phone_md5` 查询的典型落点。
- **SC-003**：规格文档明确要求后续实现前全量扫描其他 Mapper XML，并对命中点分类处理。
- **SC-004**：规格文档明确要求 DTO 增加或补齐 `phoneMd5`，并在 Mapper 调用前赋值。
- **SC-005**：规格文档明确保存 / 更新接口传 MD5 时的错误提示：`手机号加密格式不符`。
- **SC-006**：规格文档包含明文、前端加密、MD5 查询三类测试场景，以及保存 / 更新拒绝 MD5 的测试场景。

## 假设

- 当前系统已兼容查询入参为明文手机号和前端加密手机号。
- `DataSecurityInvoke.computePhoneMd5(...)` 可继续作为明文 / 前端加密手机号转换 `phoneMd5` 的统一入口。
- MD5 手机号兼容只适用于查询接口，不适用于保存和更新接口。
- 目标表已经存在 `phone_md5` 字段并完成历史数据回填或具备可查询数据。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已确认典型问题落点：`ExternalBookQuestionRecordMapper.xml` 中仍存在 `phone = #{input.phone}`。
- 已同步记录用户补充口径：查询接口可传 MD5，保存 / 更新接口不可传 MD5。
- 已补充全量扫描其他 Mapper XML 的要求，并记录初始静态搜索命中的候选文件。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 待后续实现阶段补充实现内容、影响范围、测试命令、测试结果和自检结论。

### D003 - 纠正记录模板

- 后续如出现用户补充、测试失败、代码审查发现、参数遗漏或调用顺序问题，需要追加新的 Dxxx 纠正记录。
- 纠正记录必须写清旧口径和新口径，并同步 `spec.md`、`tasks.md`、`AGENTS.md` 和 checklist。
- 纠正记录必须补充测试或静态检查结果。
