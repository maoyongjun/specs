# 功能规格：手机号安全字段保存与查询改造

**功能目录**：`036-phone-security-save-query`  
**创建日期**：`2026-05-28`  
**状态**：Draft  
**输入**：在 032-phone-security-columns 数据库字段已添加的基础上，补全 7 张目标表的手机号安全字段保存、查询、展示和明文读取链路代码改造，并追加历史数据回填接口。涉及两个工程：`C:\workspace\drh`（主业务微服务）和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`（AI 模块），历史回填接口落在 `C:\workspace\ju-chat\data-RC\juzi-service`。目标表为 `drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`、`drh_real_address_record`。在线保存 / 查询 / 展示代码仍不改造 `app_phone`；历史回填补数据需要包含 `drh_live_user.app_phone` 的 `app_phone_mask`、`app_phone_md5`、`app_phone_aes`。后续 `phone` 字段会清空，业务不得依赖数据库实体 `getPhone()` 作为明文来源。

## 背景

- 当前问题：032 需求已完成部分数据库字段添加（测试库已执行 DDL），但目标表业务代码仍有明文手机号保存、查询和展示链路未改全，安全字段未被完整使用。
- 当前行为：各 Service 直接 `setPhone()` 保存明文，查询时 `eq(phone, xxx)`，列表展示直接返回 `phone` 字段。两个工程中至少 10+ 处 Service 方法涉及手机号读写。
- 目标行为：保存时同步写入 `phone_mask`、`phone_md5`、`phone_aes`；查询时使用 `phone_md5` 等值匹配；展示时返回 `phone_mask`。查询接口需兼容明文手机号、前端加密手机号、手机号 MD5 三种输入；保存 / 更新接口需兼容明文手机号和前端加密手机号两种输入。
- 非目标：本次不批量清空原 `phone` / `app_phone` 明文字段；在线保存、查询、展示链路仍不改造 `app_phone`；非目标表中的 `phone` 使用点只做静态提示，不改业务逻辑。

## 输入格式兼容口径

- 查询接口：同一手机号查询参数支持三种格式：明文手机号、前端 AES 加密手机号、手机号 MD5。后端统一调用 `DataSecurityInvoke.computePhoneMd5()` 归一到 `phone_md5`；32 位十六进制 MD5 输入直接使用，前端密文先解密再计算 MD5，明文直接计算 MD5。
- 保存 / 更新接口：手机号字段支持两种格式：明文手机号、前端 AES 加密手机号。后端统一通过 `createAesInfo()` / `buildPhoneSecurity()` 生成 `phone_mask`、`phone_md5`、`phone_aes`；手机号 MD5 不作为保存 / 更新输入，因为仅凭 MD5 无法生成掩码展示值和 AES 密文。
- `app_phone` 在线保存 / 查询 / 展示链路仍按排除项处理，不纳入上述兼容口径；历史回填接口仅补已有 `app_phone_*` 安全字段。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 新增 / 修改记录时同步写入安全字段（优先级：P1）

当业务代码保存或更新目标表中含手机号的记录时，系统必须自动计算并写入 `phone_mask`、`phone_md5`、`phone_aes` 三个字段。

**独立测试**：对每张目标表执行新增操作后，检查数据库中 `phone_mask`、`phone_md5`、`phone_aes` 均有值且与 `phone` 一致。

**验收场景**：

1. **Given** 前端传入经前端 key 加密的手机号密文，**When** 后端接收并调用 `createAesInfo()`，**Then** `phone` 存解密后明文，`phone_mask` 存 `138****0000`，`phone_md5` 存 32 位 MD5，`phone_aes` 存后端 AES 密文。
2. **Given** 前端尚未整改，传入未加密的明文手机号 `13800000000`，**When** 后端接收并调用 `createAesInfo()`，**Then** 系统识别为明文，跳过前端解密步骤，直接以明文计算安全字段，结果正确。
3. **Given** 手机号为空，**When** 调用 `createAesInfo()`，**Then** `phone_mask`、`phone_md5`、`phone_aes` 均为 `NULL`，不抛异常。

### 用户故事 2 - 按手机号查询使用 MD5 等值匹配（优先级：P1）

当业务代码按手机号查询目标表记录时，应先将查询条件中的手机号归一为 MD5，再用 `phone_md5` 字段做等值匹配。查询参数支持明文手机号、前端加密手机号和手机号 MD5 三种格式。

**独立测试**：执行查询后，确认 SQL 日志或 MyBatis 参数中使用 `phone_md5 = ?` 而非 `phone = ?`。

**验收场景**：

1. **Given** 后台按手机号搜索图书订单，**When** 传入明文手机号 `13800000000`，**Then** 查询条件为 `phone_md5 = MD5('13800000000')`，返回匹配记录。
2. **Given** 后台按手机号搜索图书登记信息，**When** 传入前端 AES 加密手机号，**Then** 后端先解密再计算 MD5，并使用 `phone_md5` 等值匹配。
3. **Given** 后台按手机号搜索学员 / 线索 / 订单，**When** 传入 32 位手机号 MD5，**Then** 后端直接使用该 MD5 匹配 `phone_md5`，不再二次摘要。
4. **Given** 查询手机号为空或格式异常，**When** 执行查询，**Then** 返回空结果，不抛异常。

### 用户故事 3 - 列表展示使用掩码手机号（优先级：P2）

当前端列表需要展示手机号时，后端返回 `phone_mask` 字段而非明文 `phone`。

**独立测试**：调用列表接口后，检查返回 JSON 中手机号字段为掩码格式（如 `138****0000`）。

**验收场景**：

1. **Given** 运营后台请求图书订单列表或图书登记信息列表，**When** 接口返回数据，**Then** 手机号字段为 `phone_mask` 值，非明文。
2. **Given** 某条记录 `phone_mask` 为 NULL（历史数据未回填），**When** 列表展示，**Then** 显示为空或做 fallback 掩码处理，不直接暴露明文。

### 用户故事 4 - 前端加密 / 未加密手机号兼容（优先级：P1）

前端页面整改过渡期内，保存 / 更新链路后端会同时收到明文手机号和加密密文两种输入。系统必须自动识别并正确处理。

**独立测试**：分别传入明文手机号和加密密文，验证 `createAesInfo()` 均能正确产出安全字段；传入手机号 MD5 时不作为保存 / 更新支持格式。

**验收场景**：

1. **Given** 前端传入 AES 加密手机号密文（整改后），**When** 后端调用 `createAesInfo()`，**Then** 先解密再计算安全字段，结果正确。
2. **Given** 前端传入明文手机号（整改前），**When** 后端调用 `createAesInfo()`，**Then** 识别为明文，跳过解密，直接计算安全字段，结果正确。
3. **Given** 保存 / 更新接口只传入手机号 MD5，**When** 后端需要生成安全字段，**Then** 不按正常手机号保存处理，因为无法生成 `phone_mask` 和 `phone_aes`。
4. **Given** 传入值为空或无法识别格式，**When** 调用 `createAesInfo()`，**Then** 安全字段保持 `NULL`，不抛异常。

### 用户故事 5 - 单元测试覆盖（优先级：P1）

对 `createAesInfo()` 方法及前端兼容逻辑编写单元测试，确保核心逻辑正确。

**独立测试**：运行单元测试，全部通过。

**验收场景**：

1. **Given** 明文手机号输入，**When** 执行 `createAesInfo()` 单测，**Then** `phoneMask` 格式正确（如 `138****0000`），`phoneMd5` 为 32 位十六进制，`phoneAes` 非空。
2. **Given** 前端加密密文输入，**When** 执行 `createAesInfo()` 单测，**Then** 解密后安全字段与明文输入结果一致。
3. **Given** 空手机号输入，**When** 执行 `createAesInfo()` 单测，**Then** 三个安全字段均为 `NULL`。
4. **Given** 非法密文输入（解密失败），**When** 执行 `createAesInfo()` 单测，**Then** 不抛异常，安全字段为 `NULL`。
5. **Given** MD5 查询工具方法，**When** 传入明文、前端密文、32 位 MD5，**Then** 明文 / 密文会归一为同一个 `phone_md5`，MD5 输入直接返回且不会二次摘要。

### 用户故事 6 - 历史数据回填接口（优先级：P1）

运维或研发调用 `juzi-service` 的后台接口后，接口立即返回受理成功，服务在后台逐表补齐历史记录的安全字段。

**独立测试**：调用 `POST /admin/phone-security-backfill/start` 后立即收到 `OK`，后台日志持续打印各表进度。

**验收场景**：

1. **Given** 目标表存在 `phone` 非空且 `phone_mask/phone_md5/phone_aes` 任一为空的历史记录，**When** 后台回填运行，**Then** 通过 `DataSecurity-test` 计算并更新三个安全字段。
2. **Given** `drh_live_user.app_phone` 非空且 `app_phone_mask/app_phone_md5/app_phone_aes` 任一为空，**When** 后台回填运行，**Then** 同样计算并更新 `app_phone_*` 三字段。
3. **Given** 回填任务正在执行，**When** 再次调用启动接口，**Then** 返回正在运行提示，不启动第二个并发补数任务。
4. **Given** 后台任务处理历史数据，**When** 调用数据安全 FC 函数，**Then** 最多 4 个并发调用；数据库更新按 300 条一批执行。

## 数据模型与字段

### 涉及表和实体

| 数据库表 | drh 工程实体 | ju-chat 工程实体 | 手机号字段 | 模块 |
|---------|-------------|-----------------|-----------|------|
| `drh_h5_order` | `H5Order`（drh-common） | `H5OrderDO`（ai-common） | `phone` | drh: pay / endpoint / kk-cms / callback / media-process; ju-chat: ai |
| `drh_live_user` | `LiveUser`（drh-common） | `LiveUserDO`（ai-common） | `phone` | drh: endpoint / pay; ju-chat: ai |
| `drh_live_user` | `LiveUser`（drh-common） | `LiveUserDO`（ai-common） | `app_phone` | 仅历史回填补齐 `app_phone_*`，在线代码改造仍排除 |
| `drh_applet_user` | `AppletUser`（drh-common） | `AppletUserDo`（ai-common） | `phone` | drh: endpoint / callback / kk-cms / media-process; ju-chat: ai |
| `drh_book_question_record` | `BookQuestionRecord`（drh-common） | `BookQuestionRecordDO`（ai-common） | `phone` | drh: endpoint / kk-cms / media-process; ju-chat: ai |
| `drh_external_book_question_record` | `ExternalBookQuestionRecord`（drh-common） | `ExternalBookQuestionRecordDO`（ai-common） | `phone` | drh: kk-cms / media-process; ju-chat: ai |
| `drh_book_edit_address_compensation` | - | `BookEditAddressCompensationDO`（ai-common） | `phone` | ju-chat: ai |
| `drh_real_address_record` | `RealGoodsAddressRecord`（drh-common） | `RealGoodsAddressRecordDO`（ai-common） | `phone` | drh: endpoint / kk-cms / media-process; ju-chat: ai / lms |

### 不涉及（本次排除）

| 数据库表或字段 | 排除原因 |
|---------------|---------|
| `drh_live_user.app_phone` 在线保存 / 查询 / 展示链路 | 代码改造仍不处理 `app_phone`；仅历史回填接口补齐已有 `app_phone_*` 字段 |
| 非上述 7 张目标表中的 `phone` | 只整理静态提示，暂不修改业务逻辑 |

### 数据库 SQL 变更

SQL 文件已同步放在本规格目录：[`phone-security-d006.sql`](./phone-security-d006.sql)。

执行口径：

- 032 已执行过 6 张表 DDL 的环境，本次通常只需要确认 6 张表字段/索引存在，并追加 `drh_real_address_record` 三字段和 `phone_md5` 索引。
- 新环境按下方完整 7 张目标表口径执行；执行前先用 `information_schema` 检查字段和索引，已存在则跳过，避免重复 `ADD COLUMN` / `ADD INDEX`。
- `app_phone_*` 字段来自 032 的 `drh_live_user` DDL，本次 D006 SQL 不重复添加；历史回填接口会读取 `drh_live_user.app_phone` 并写入已有 `app_phone_mask/app_phone_md5/app_phone_aes`。

```sql
-- 检查目标字段是否已存在
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_h5_order',
    'drh_live_user',
    'drh_applet_user',
    'drh_book_question_record',
    'drh_external_book_question_record',
    'drh_book_edit_address_compensation',
    'drh_real_address_record'
  )
  AND COLUMN_NAME IN ('phone_mask', 'phone_md5', 'phone_aes')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 检查 phone_md5 索引是否已存在
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'drh_h5_order',
    'drh_live_user',
    'drh_applet_user',
    'drh_book_question_record',
    'drh_external_book_question_record',
    'drh_book_edit_address_compensation',
    'drh_real_address_record'
  )
  AND COLUMN_NAME = 'phone_md5'
ORDER BY TABLE_NAME, INDEX_NAME;

-- 完整目标表 DDL；已存在的字段/索引需跳过
ALTER TABLE drh_h5_order
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_h5_order_phone_md5 (phone_md5);

ALTER TABLE drh_live_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_live_user_phone_md5 (phone_md5);

ALTER TABLE drh_applet_user
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_applet_user_phone_md5 (phone_md5);

ALTER TABLE drh_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_q_record_phone_md5 (phone_md5);

ALTER TABLE drh_external_book_question_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_ext_book_q_record_phone_md5 (phone_md5);

ALTER TABLE drh_book_edit_address_compensation
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_book_addr_comp_phone_md5 (phone_md5);

ALTER TABLE drh_real_address_record
  ADD COLUMN phone_mask VARCHAR(32) DEFAULT NULL COMMENT '手机号掩码展示值',
  ADD COLUMN phone_md5 CHAR(32) DEFAULT NULL COMMENT '手机号MD5摘要，用于等值查询',
  ADD COLUMN phone_aes VARCHAR(255) DEFAULT NULL COMMENT '手机号AES密文，用于单条结果解密',
  ADD INDEX idx_real_addr_phone_md5 (phone_md5);
```

业务 SQL 改造口径：

```sql
-- 原手机号等值查询
WHERE phone = ?

-- 改为：Java 侧先计算 MD5，再用 phone_md5 匹配
WHERE phone_md5 = ?

-- 原批量手机号查询
WHERE phone IN (?, ?, ...)

-- 改为：Java 侧批量计算 MD5
WHERE phone_md5 IN (?, ?, ...)

-- 原仅更新明文手机号
SET phone = ?

-- 改为同步写三类安全字段
SET phone = ?, phone_mask = ?, phone_md5 = ?, phone_aes = ?

-- 展示/列表不再直接返回明文 phone
SELECT phone_mask, phone_aes
```

### 新增实体字段

两个工程的实体类均需增加以下持久化字段：

```java
private String phoneMask;   // 掩码展示值，如 138****0000
private String phoneMd5;    // MD5 摘要，32 位十六进制
private String phoneAes;    // AES 密文
```

### DataSecurity 工具类（已存在于 drh-common）

`DataSecurity*` 四个类位于 `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\`：

| 类 | 用途 |
|---|------|
| `DataSecurityInput` | 输入 DTO：`businessType`（1=加密, 2=解密, 3=登录加密）、`dataType`（1=手机号, 2=银行卡, 3=身份证）、`data` |
| `DataSecurityOutput` | 输出 DTO：`data`、`mask`（掩码值）、`md5`（MD5 摘要）、`aesEncrypt`（AES 密文）、`aesDecrypt`（AES 解密值） |
| `DataSecurityInvoke` | 远程 FC 函数调用（函数名 `DataSecurity-test`），通过 `FcInvokeUtils.doSyncTaskReturnJSONObj()` 执行 |
| `DataSecurityUtil` | 本地工具：AES/CBC/PKCS5Padding 加解密（key `drh_aes_key_77b!`，IV `drh_aes_iv_77bit`），手机号/银行卡/身份证掩码 |

### 核心方法模式（createAesInfo）— 含前端兼容

参考 `AppletUser.createAesInfo()`（drh-common），每个实体需增加类似方法。核心变化是增加前端密文 / 明文兼容判断：

```java
public void createAesInfo() {
    String rawPhone = this.getPhone();
    if (rawPhone == null || rawPhone.isEmpty()) {
        return;
    }

    // 尝试前端解密：密文则解密，明文则回退使用原值
    String decryptedPhone;
    try {
        decryptedPhone = DataSecurityUtil.aesDecrypt(rawPhone);
    } catch (Exception e) {
        decryptedPhone = rawPhone;
    }
    if (decryptedPhone == null || decryptedPhone.isEmpty()) {
        decryptedPhone = rawPhone;
    }

    // 用解密后（或明文）手机号计算安全字段
    DataSecurityInput input = new DataSecurityInput();
    input.setBusinessType(1);
    input.setDataType(1);
    input.setData(decryptedPhone);
    DataSecurityOutput output = DataSecurityInvoke.doDsTask(input);
    if (output != null) {
        this.setPhoneMask(output.getMask());
        this.setPhoneMd5(output.getMd5());
        this.setPhoneAes(output.getAesEncrypt());
    }

    // 将 phone 字段更新为解密后的明文
    this.setPhone(decryptedPhone);
}
```

注意：`AppletUser` 中的 `phoneMask`、`phoneMd5`、`phoneAes` 当前标记为 `@TableField(exist = false)`（非持久化），本次改造的 `H5Order` 和 `BookQuestionRecord` 需要将这三个字段设为持久化字段（不加 `@TableField(exist = false)`）。

## 保存链路改造

### 改造原则

- 所有写入（`insert`、`save`、`update`）含手机号的场景，在入库前必须调用 `createAesInfo()` 同步计算安全字段。
- `createAesInfo()` 内部兼容前端密文和明文输入，统一产出安全字段。
- 原 `phone` 字段保留存储解密后的明文（后续可评估是否改为不存明文）。

### drh 工程改造落点

| 模块 | Service 入口 | 改造内容 |
|------|-------------|---------|
| drh-pay | `H5OrderServiceImpl.create()` / `insertH5Order()` / `insertOpenH5Order()` | 从 `H5PayDto.getPhone()` 获取手机号后，在 `save()` 前调用 `createAesInfo()` |
| drh-endpoint | `H5OrderServiceImpl.editAddress()` / `editAddressV2()` | 从 `BookEditAddressDto` 复制 phone 到 `BookQuestionRecord` 后，在 `save()` 前调用 `createAesInfo()` |
| drh-kk-cms | `BookQuestionRecordServiceImpl.editAddress()` / `editAddressV2()` | 同上 |
| drh-kk-cms | `BookQuestionRecordServiceImpl.getCallbackH5Order()` | 如涉及 H5Order 保存，需调用 `createAesInfo()` |
| drh-callback | `H5OrderServiceImpl` | 如涉及 H5Order 更新手机号，需调用 `createAesInfo()` |
| drh-media-process | `H5OrderServiceImpl` / `BookQuestionRecordServiceImpl` | 如涉及手机号写入，需调用 `createAesInfo()` |

### ju-chat 工程改造落点

| 模块 | Service 入口 | 改造内容 |
|------|-------------|---------|
| ai | `BookQuestionRecordServiceImpl` | 如涉及 `BookQuestionRecordDO` 保存，在 `save()` 前调用 `createAesInfo()` |

注意：ju-chat 工程（`ai` 模块）的 `DataSecurity*` 类不在其代码中，需确认 `ai-common` 或 `ai` 模块的 Maven 依赖是否已引入 drh-common 的 FC 包，或需要通过其他方式调用。

### 静态工厂方法同步改造

drh 工程的 `H5Order.create(phone, price, channelId)` 静态方法需同步调用 `createAesInfo()` 或在调用方保存前调用。

## 查询链路改造

### 改造原则

- 所有按手机号等值查询的场景，改为先将查询手机号归一为 MD5，再用 `phone_md5` 字段匹配；归一化输入支持明文手机号、前端 AES 加密手机号、手机号 MD5。
- 查询条件构建使用 `LambdaQueryWrapper.eq(Xxx::getPhoneMd5, md5Value)`。
- 目标表手机号等值和批量 `in` 查询统一改为 `phone_md5`；模糊查询或非目标表手机号查询另行评估，不在本次业务改造范围内。

### drh 工程改造落点

| 模块 | 查询入口 | 改造内容 |
|------|---------|---------|
| drh-pay | `H5OrderServiceImpl.selectIsPay()` | `.eq(H5Order::getPhone, phone)` → `.eq(H5Order::getPhoneMd5, md5Value)` |
| drh-pay | `H5OrderController.queryPhone()` | 接收 phone 参数后计算 MD5 再查询 |
| drh-endpoint | `H5OrderServiceImpl.queryLeads()` | `.eq(H5Order::getPhone, phone)` → `.eq(H5Order::getPhoneMd5, md5Value)` |
| drh-endpoint | `H5OrderServiceImpl.editAddress()` / `editAddressV2()` | 查询 `BookQuestionRecord` 和 `H5Order` 时使用 `phoneMd5` |
| drh-kk-cms | `H5OrderServiceImpl.getPhoneResult()` | `.in(H5Order::getPhone, phones)` → 批量计算 MD5 后 `.in(H5Order::getPhoneMd5, phoneMd5List)` |
| drh-kk-cms | `H5OrderServiceImpl.getPhoneChannelSet()` | `.in(H5Order::getPhone, phones)` → 批量计算 MD5 后 `.in(H5Order::getPhoneMd5, phoneMd5List)` |
| drh-kk-cms | `BookQuestionRecordServiceImpl.editAddressV2()` | `.eq(BookQuestionRecord::getPhone, ...)` → `.eq(BookQuestionRecord::getPhoneMd5, md5Value)` |
| drh-kk-cms | `BookQuestionRecordServiceImpl.selectCanEdit()` | 涉及 AppletUser 和 H5Order 的 phone 查询，H5Order 部分改为 `phoneMd5` |

### ju-chat 工程改造落点

| 模块 | 查询入口 | 改造内容 |
|------|---------|---------|
| ai | `BookQuestionRecordServiceImpl.getBookQuestionRecordByAppletUserId()` | `.eq(BookQuestionRecordDO::getPhone, queryPhone)` → `.eq(BookQuestionRecordDO::getPhoneMd5, md5Value)` |

### MD5 计算工具

查询时统一使用 `DataSecurityInvoke.computePhoneMd5(phoneInput)` 将输入归一为 `phone_md5`。该方法支持三种输入格式：

- 32 位十六进制 MD5：直接返回并做小写归一，不调用远程 FC，避免二次摘要。
- 前端 AES 加密手机号：先解密为明文，再调用数据安全服务计算 MD5。
- 明文手机号：直接调用数据安全服务计算 MD5。

```java
String phoneMd5 = DataSecurityInvoke.computePhoneMd5(phoneInput);
wrapper.eq(XxxEntity::getPhoneMd5, phoneMd5);
```

保存 / 更新链路不得用 MD5 输入调用 `createAesInfo()` 作为正常手机号保存，因为 MD5 无法生成 `phone_mask` 和 `phone_aes`；保存 / 更新必须传明文手机号或可解密的前端密文。

## 展示链路改造

### 改造原则

- 列表 / 导出接口返回手机号时，优先使用 `phone_mask` 字段。
- 单条详情需要完整手机号时，读取 `phone_aes` 并调用 AES 解密还原。
- 历史数据 `phone_mask` 为 NULL 时，可做 fallback：从 `phone` 字段现算掩码，或直接返回空。

### 改造落点

- drh 工程：`H5Order` 和 `BookQuestionRecord` 相关的 VO / DTO 中返回给前端的手机号字段，赋值来源从 `phone` 改为 `phoneMask`。重点关注 drh-kk-cms 的列表接口和导出功能。
- ju-chat 工程：`BookQuestionRecordDO` 相关返回改为 `phoneMask`。

## 本地构建 / JDK 口径

- DRH 工程本地编译和单元测试优先使用 JDK8：`C:\Program Files\Java\jdk1.8.0_481`，版本 `java version "1.8.0_481"`。
- 验证前建议显式设置：

```powershell
$env:JAVA_HOME='C:\Program Files\Java\jdk1.8.0_481'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
mvn -pl drh-common "-Dtest=DataSecurityUtilTest" test
```

- 本机 Maven 曾默认使用 JDK17：`C:\workspace\tools\jdk17\jdk-17.0.18+8`，版本 `17.0.18`。该 JDK 会触发老 Lombok 与 `jdk.compiler` 模块访问冲突，不建议用于本需求的 DRH 工程验证。

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `phone`：来源于前端请求（可能是 AES 密文或明文），经 `createAesInfo()` 兼容处理后为明文；赋值时机为 `createAesInfo()` 内部。
  - `phone_mask`、`phone_md5`、`phone_aes`：来源于 `DataSecurityInvoke.doDsTask()` 的返回值（远程 FC 函数 `DataSecurity-test`）；赋值时机为 `createAesInfo()` 调用后、`save()` / `insert()` 调用前。
  - 历史回填时 `phone` 和 `app_phone` 均来自数据库已有明文字段；回填接口只写安全字段，不改写原始手机号字段。
- 下游读取字段清单：
  - 列表展示读取 `phoneMask`。
  - 等值查询读取 `phoneMd5`。
  - 单条解密读取 `phoneAes`。
  - `app_phone_*` 仅作为历史补齐数据落库，本次不接入线上查询 / 展示链路。
- 空对象 / 占位对象风险：
  - `DataSecurityInput` 必须 `setData()` 后再调用 `doDsTask()`，不允许传空 `data` 进入加密流程。
  - `DataSecurityOutput` 返回值需检查 `getMask()`、`getMd5()`、`getAesEncrypt()` 是否为空（远程 FC 调用可能超时或返回异常）。
- 调用顺序风险：
  - 必须先兼容处理前端输入 → 再调用 `doDsTask`（远程 FC） → 再 `set` 安全字段 → 最后 `save()`。
  - 不允许先 `save()` 后补安全字段（存在事务不一致风险）。
  - `DataSecurityInvoke.doDsTask()` 是远程 FC 调用，需考虑超时和失败场景。
  - 历史回填接口是一次性运维入口，必须防止同一服务实例内重复启动，并限制 FC 调用并发数。
- 旧逻辑保持：
  - 原 `phone` 字段仍然保留并存明文，旧查询在本阶段可并存（渐进式改造）。
  - 不改变原有事务边界、异常处理、日志输出和 fallback 行为。
  - 不新增 MQ、Redis、Feign 或外部 HTTP 调用（`DataSecurityInvoke` 的 FC 调用已有）。
- 需要用户确认的设计选择：
  - `DataSecurityUtil.aesDecrypt()` 对明文输入的具体行为（抛异常 / 返回 null / 返回乱码），决定兼容判断策略。
  - 批量 `in` 查询（如 `getPhoneResult()`、`getPhoneChannelSet()`）已在 D006 中改为批量计算 MD5 后查询 `phone_md5`。
  - ju-chat 工程 `ai` 模块如何调用 `DataSecurity*` 类——是否需要将 drh-common 的 datasec 包抽出为独立依赖，还是在 ai 模块中复制。
  - `DataSecurityInvoke.doDsTask()` 远程 FC 调用的超时时间和失败降级策略。
  - 历史回填默认按当前数据库连接执行，不额外切换数据源；执行前需确认目标环境和表字段已准备好。

## 边界情况

- 手机号为空时：`createAesInfo()` 跳过计算，三个安全字段保持 `NULL`，不抛异常。
- 前端传明文手机号（整改前）：`DataSecurityUtil.aesDecrypt()` 解密失败或返回异常值，`createAesInfo()` 捕获后回退使用原明文，正常计算安全字段。
- 前端传加密密文（整改后）：`DataSecurityUtil.aesDecrypt()` 正常解密，`createAesInfo()` 使用解密后明文计算安全字段。
- 查询传 32 位手机号 MD5：`DataSecurityInvoke.computePhoneMd5()` 直接返回该 MD5（小写归一），查询 `phone_md5`，不调用 FC 二次计算。
- 保存 / 更新传 32 位手机号 MD5：不作为正常保存 / 更新输入处理，因为缺少明文无法生成 `phone_mask` 和 `phone_aes`。
- `DataSecurityInvoke.doDsTask()` 远程 FC 调用超时或返回 `null` 时：需做空值保护，安全字段保持 `NULL`，记录 ERROR 日志，不影响主流程保存。
- 历史数据 `phone_mask` 为 NULL 时：列表展示做 fallback 处理（从 `phone` 现算掩码或显示为空），不直接暴露明文。
- 历史回填只处理原始手机号非空且三个安全字段任一为空的记录；FC 调用失败的记录本次跳过并打印日志，后续可再次启动接口重试。
- 更新手机号场景：更新 `phone` 时必须同步重新计算三个安全字段。
- 批量导入 / MQ 消费写入场景：同样需要调用 `createAesInfo()`，不能绕过。
- drh-kk-cms `editAddressV2()` 中有 Redis 锁基于 phone+goodsId，改造后需确认锁 key 不受影响（锁 key 应仍使用明文 phone）。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `H5Order`（drh-common）和 `H5OrderDO`（ai-common）实体中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段。
- **FR-002**：系统 MUST 在 `BookQuestionRecord`（drh-common）和 `BookQuestionRecordDO`（ai-common）实体中增加 `phoneMask`、`phoneMd5`、`phoneAes` 持久化字段。
- **FR-003**：系统 MUST 在每个实体中增加 `createAesInfo()` 方法，在保存前同步计算掩码、MD5、AES。
- **FR-004**：系统 MUST 在 `createAesInfo()` 中兼容保存 / 更新链路前端传入的明文手机号和 AES 加密密文，密文先解密再处理，明文直接使用。
- **FR-005**：系统 MUST 在所有新增 / 修改手机号的保存链路中，在 `save()` / `insert()` 前调用 `createAesInfo()`，同步生成 `phone_mask`、`phone_md5`、`phone_aes`。
- **FR-006**：系统 MUST 将所有按手机号等值查询（单条 `.eq`）的条件从 `phone = ?` 改为 `phone_md5 = ?`，查询输入支持明文手机号、前端 AES 加密手机号、手机号 MD5 三种格式。
- **FR-007**：系统 MUST 在列表 / 导出接口中将手机号展示来源从 `phone` 改为 `phoneMask`。
- **FR-008**：系统 MUST 在手机号为空、解密失败或远程 FC 调用失败时做安全降级，不抛异常，安全字段保持 `NULL`。
- **FR-009**：系统 MUST NOT 在本次改造中删除原 `phone` 字段或清空其值。
- **FR-010**：系统 MUST NOT 在在线保存、查询、展示链路中改造 `drh_live_user.app_phone`。
- **FR-011**：系统 MUST 在 `juzi-service` 提供历史回填启动接口，调用后立即返回受理成功并由后台执行补数。
- **FR-012**：系统 MUST 为 `createAesInfo()` 方法和前端兼容逻辑编写单元测试，覆盖明文输入、密文输入、空值输入、非法密文输入四种场景。
- **FR-013**：历史回填 MUST 覆盖 7 张目标表的 `phone_*` 三字段，并额外覆盖 `drh_live_user.app_phone_*` 三字段。
- **FR-014**：历史回填 MUST 限制数据安全 FC 调用最多 4 并发，并按 300 条一批执行数据库批量更新。
- **FR-015**：系统 MUST NOT 将手机号 MD5 作为保存 / 更新链路的正常手机号输入；仅有 MD5 时无法生成 `phone_mask` 和 `phone_aes`。

## 成功标准 *(必填)*

- **SC-001**：2 张目标表在两个工程中的实体类均包含安全持久化字段和 `createAesInfo()` 方法。
- **SC-002**：所有保存链路（drh: pay / endpoint / kk-cms / callback / media-process; ju-chat: ai）在入库前同步写入安全字段。
- **SC-003**：所有按手机号单条等值查询的 Service 使用 `phone_md5` 匹配，且同一接口分别传明文、前端密文、手机号 MD5 均能命中同一条记录。
- **SC-004**：列表和导出接口返回掩码手机号，不返回明文。
- **SC-005**：手机号为空、解密失败或 FC 调用失败时系统不抛异常，安全字段为 `NULL`。
- **SC-006**：原有业务流程不回归（事务、异常、日志、幂等性不变）。
- **SC-007**：保存 / 更新链路前端传明文手机号和传加密密文时，安全字段计算结果一致；手机号 MD5 输入不作为保存 / 更新支持格式。
- **SC-008**：单元测试覆盖明文输入、密文输入、空值、非法密文四种场景，全部通过。
- **SC-009**：调用 `POST /admin/phone-security-backfill/start` 后立即返回 `OK` 和 `runId`，后台日志能看到各表 / 字段的选中、加密失败、批量更新进度。

## 假设

- `DataSecurityInput`、`DataSecurityOutput`、`DataSecurityInvoke`、`DataSecurityUtil` 已存在于 drh-common 的 `com.drh.common.fc.datasec` 包中，drh 工程各模块可通过依赖 drh-common 使用。
- ju-chat 工程 ai 模块需确认是否已依赖 drh-common 或需要额外配置才能调用 `DataSecurity*` 类。
- 前端加密手机号需与 `DataSecurityUtil.aesDecrypt()` 使用的 AES 口径一致，否则保存 / 更新和查询链路无法从密文还原明文。
- `DataSecurityInvoke.doDsTask()` 远程 FC 调用（函数 `DataSecurity-test`）在正常网络下延迟可接受。
- MD5 输出为 32 位十六进制；`computePhoneMd5()` 对外部传入的 MD5 做小写归一，明文 / 密文输入仍以 `DataSecurityInvoke.doDsTask()` 返回口径为准。
- MyBatis-Plus 的 `@TableField` 或 `LambdaQueryWrapper` 可正确映射新增字段到下划线列名。
- 测试库已执行 032 的 DDL，新增字段已可用。
- `DataSecurityUtil.aesDecrypt()` 对明文输入会抛异常或返回 `null` / 无意义值，可通过 try-catch + 回退实现兼容。
- `juzi-service` 运行时数据库连接指向需要回填的目标库，且 `drh_live_user` 已存在 `app_phone_mask/app_phone_md5/app_phone_aes`。
- 历史回填接口只保证单实例内不重复启动；多实例部署时调用方需只打到一个实例或在执行窗口内保证只调用一次。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成代码搜索，确认目标实体、Service、Mapper 和现有加密工具。
- 本阶段未修改业务代码。

### D002 - 需求补充纠正

- 触发原因：用户补充——`app_phone` 不由本次处理，本次只处理 `H5OrderDO` 和 `BookQuestionRecordDO`；前端整改前会传明文手机号，需兼容；需编写单元测试。
- 修正内容：范围缩小为 2 张表；移除 LiveUserDO 和 ExternalBookQuestionRecordDO；新增前端兼容需求和单测要求。
- 文档同步：已同步更新四个文件。

### D003 - 项目路径补充纠正

- 触发原因：用户补充——修改代码涉及两个工程：`C:\workspace\drh` 和 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai`。
- 修正内容：
  - 确认 `DataSecurity*` 四个类存在于 drh-common 的 `com.drh.common.fc.datasec` 包中（非外部依赖）。
  - 确认 `DataSecurityInvoke.doDsTask()` 通过 `FcInvokeUtils` 调用远程 FC 函数 `DataSecurity-test`。
  - 确认 `DataSecurityUtil` 使用 AES/CBC/PKCS5Padding，key `drh_aes_key_77b!`，IV `drh_aes_iv_77bit`。
  - 确认 drh 工程涉及模块：drh-pay、drh-endpoint、drh-kk-cms、drh-callback、drh-media-process。
  - drh 工程实体名为 `H5Order`（非 H5OrderDO）、`BookQuestionRecord`（非 BookQuestionRecordDO）。
  - 补全 drh 工程中所有涉及手机号保存和查询的 Service 方法落点（10+ 处）。
  - 新增 ju-chat 工程 ai 模块对 `DataSecurity*` 的依赖可用性为待确认项。
  - 批量 `in` 查询（`getPhoneResult()`、`getPhoneChannelSet()`）早期曾列为后续项，后续 D006 已覆盖改为 `phone_md5`。
- 文档同步：`spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md` 已同步更新。
- 验证结果：文档静态检查通过。

### D004 - 实现记录

- 已被 D006 替代：用户将范围扩展到 7 张表，并要求 `phone` 后续按可清空处理。

### D006 - 手机号安全字段补全实现记录

- 触发原因：用户补充目标表扩展为 7 张，并明确 `app_phone` 不处理、后续 `phone` 字段会清空，业务不得依赖 DB 实体 `getPhone()` 作为明文来源。
- 目标表：`drh_h5_order`、`drh_live_user`、`drh_applet_user`、`drh_book_question_record`、`drh_external_book_question_record`、`drh_book_edit_address_compensation`、`drh_real_address_record`。
- 实体/工具：补齐 DRH 与 IDC AI 侧目标实体的 `phoneMask`、`phoneMd5`、`phoneAes`；`AppletUser` 去掉安全字段非持久化标记；新增统一工具 `buildPhoneSecurity`、`computePhoneMd5`、`decryptPhoneAes`、`phoneMaskForDisplay`。
- 保存/更新：H5Order 创建、图书登记、非留资登记、真实地址记录、学员/线索手机号更新、AI 补偿保存均同步写 `phone_mask/phone_md5/phone_aes`；`RealGoodsAddressRecord` 保存前调用 `createAesInfo()`。
- 查询/读取：目标表按手机号等值查询改用 `phone_md5`；支付回调、ERP/物流/补偿等需要明文的链路优先用方法入参，其次从 `phone_aes` 解密；展示与订单查询返回 `phone_mask` 或由 `phone_aes` 本地掩码。
- 接口影响（DRH 项目，按模块）：

| 模块 | 接口 / 入口 | 影响点 |
|------|-------------|--------|
| `drh-pay` | `POST /h5/order/pay`、`POST /h5/order/open/pay` | H5 图书订单创建时同步写 `phone_mask/phone_md5/phone_aes` |
| `drh-pay` | `GET /h5/order/query/phone` | 按手机号查询支付状态改为 `phone_md5` 匹配 |
| `drh-pay` | `POST/GET /h5/order/wx/notify` | 微信支付回调读取 `phone_aes` 解密手机号后推送线索回调 |
| `drh-pay` | `POST /applet/order/page/pay`、`POST/GET /applet/order/wx/notify` | 小程序页面支付生成 H5Order 安全字段，回调不再依赖 DB `phone` 明文 |
| `drh-pay` | `POST /ali/pay/order`、`POST /ali/pay/notify`、`GET /ali/pay/orderNo/select`、`GET /ali/pay/phone/select` | 支付宝 H5 订单创建/回调/查询：线索更新按 `phone_md5`，展示返回掩码 |
| `drh-pay` | `POST /activity/groupbuying/order/create`、`POST /common/order/pay`、`POST /salePay/createPay*`、`POST /live/order/pay`、`POST /live/order/applet/pay` | 涉及 `LiveUserService` 的学员手机号保存/更新链路同步写安全字段 |
| `drh-endpoint` | `POST /bookPath/editAddress`、`POST /bookPath/editAddressV2` | 图书登记保存 `BookQuestionRecord`，并在正价课地址链路保存 `RealGoodsAddressRecord` 安全字段 |
| `drh-endpoint` | `GET /bookPath/queryTrackNumOrder` | 真实地址/物流查询返回掩码手机号 |
| `drh-endpoint` | `GET /liveAuth/ad/applet/query` | `queryLeads` 按手机号查询订单/线索改为 `phone_md5` 匹配 |
| `drh-endpoint` | `GET /ad/pic`、`POST /ad/v2/pic`、`POST /ad/base/pic` | 加 V / 二维码链路按手机号找线索改为 `phone_md5` |
| `drh-endpoint` | `POST /liveAuth/auth/phone/v3`、`POST /liveAuth/auth/phone/v6`、`POST /liveAuth/works/auth/phone*`、`POST /liveAuth/*/pic` | 手机号授权、留资、获客助手查询链路写入或读取线索/学员安全字段 |
| `drh-kk-cms` | `GET /user/phone/user`、`POST /user/checkCounts`、`POST /user/selectPhone` | CMS 按手机号查线索/统计改为 `phone_md5`；展示避免明文 |
| `drh-kk-cms` | `GET /bookPath/queryAdDetail`、`GET /bookPath/queryOrderDetail`、`GET /bookPath/queryCollectDetail` | 图书登记/订单收货详情手机号展示返回掩码 |
| `drh-kk-cms` | `POST /bookPath/editAddress`、`POST /bookPath/editAddressV2`、`POST /bookPath/selectCanEditV1` | CMS 图书登记保存/可填写用户查询改用安全字段 |
| `drh-kk-cms` | `POST /external/bookQuestionRecord/create`、`POST /external/bookQuestionRecord/count`、`POST /external/bookQuestionRecord/queryHistoryPage`、`POST /external/bookQuestionRecord/queryHistoryExpressNo` | 非留资登记保存、次数判断、历史查询按 `phone_md5` / 掩码字段处理 |
| `drh-kk-cms` | `POST /collect/order/editAddress`、`GET /collect/order/import/address/sure`、`GET /collect/order/import/address` | 统一填地址、批量导入地址链路保存 `RealGoodsAddressRecord` 安全字段 |
| `drh-kk-cms` | `GET /collect/order/detail`、`POST /collect/order/list`、`GET /liveCampGroup/stu/logistics` | 订单详情、订单列表、学员物流展示涉及真实地址手机号掩码展示 |
| `drh-kk-cms` | `GET /liveCampGroup/stu/search` | 学员手机号搜索改为 `phone_md5`，返回手机号为掩码 |
| `drh-callback` | `POST /ad/order`、`POST /appletUser/addAppletUserPhone` | 支付服务间回调/内部线索新增入口同步写线索安全字段 |
| `drh-callback` | `POST /baiduCallback/receive` | 百度小店订单回调创建 `AppletUser` / `H5Order` 时写安全字段 |
| `drh-callback` | `POST /dd/callback`、`POST /dd/sendOrder`、`POST /dd/goose/callback`、`POST /dd/order/changeStatus` | 抖店/小鹅通回调创建订单与线索安全字段，取消消息按 `phone_md5` 查线索 |
| `drh-callback` | `POST /third/external/importLeads`、`POST /third/external/importLeadsV2` | 第三方导入线索去重和保存改为 `phone_md5` / 安全字段 |
| `drh-callback` | `POST /sph/addOrder`、`GET/POST /sph/msgCallback` | 视频号订单回调保存 H5Order/线索时写安全字段 |
| `drh-media-process` | `POST /erp/callback`、`POST /fBook/callback`、`POST /xe/callback` | ERP / 飞书审批 / 小鹅通回传后续处理图书登记、非留资、真实地址安全字段 |
| `drh-media-process` | `GET /Test/execAdOrder`、`GET /Test/getPhone`、`GET /Test/queryOrder` | 测试/运维入口涉及非留资订单处理和手机号读取，按安全字段口径验证 |
| `drh-media-process` | `GET /smsDeal/*`、相关 XXL-JOB：`fillAiAddressOrderTask` | 批处理/短信/AI 地址填充任务从 `phone_aes` 解密或写安全字段 |

- 接口影响（IDC AI 项目）：`/book/getBookQuestionRecordByAppletUserId`、`/external/bookQuestionRecord/create`、`/external/bookQuestionRecord/count`、`/external/bookQuestionRecord/queryHistoryPage`、`/external/bookQuestionRecord/queryHistoryExpressNo`、`/book-edit-address-compensation/saveOne`、`/book-edit-address-compensation/compensationRun`、真实地址/物流相关 AI 查询接口。
- 排除项（在线代码改造口径）：`app_phone` 未处理；非目标表 phone 查询只列入静态提示，未改业务逻辑。
- 待测试重点：7 张表新增/更新后三个安全字段均有值；手动清空 `phone` 后核心查询、展示、支付回调、物流/ERP 推送和补偿链路可用；SQL 日志确认目标表手机号查询走 `phone_md5`。

### D007 - 历史数据回填接口补充

- 触发原因：用户补充本次需要补历史数据，且补数据范围包含 `drh_live_user.app_phone`；前面在线代码改造仍不用处理 `app_phone`。
- 修正内容：
  - 新增 `juzi-service` 接口 `POST /admin/phone-security-backfill/start`，接口立即返回受理成功，后台异步补数。
  - 新增 `GET /admin/phone-security-backfill/status` 查询单实例当前回填状态。
  - 回填目标包含 7 张目标表的 `phone_mask/phone_md5/phone_aes`，以及 `drh_live_user.app_phone_mask/app_phone_md5/app_phone_aes`。
  - 后台任务最多 4 个并发调用数据安全 FC 函数，数据库每 300 条执行一次批量更新，日志打印每批进度。
- 文档同步：已更新输入、非目标、涉及字段、用户故事、需求、成功标准和边界情况，区分“在线代码不处理 app_phone”和“历史回填包含 app_phone”。
- 验证建议：执行前确认 `juzi-service` 数据源指向目标库，且 032 / D006 字段均已存在；执行时通过日志观察 `runId`、target、lastId、batchUpdated 和失败数。

### D008 - DRH 接口影响模块标注补充

- 触发原因：用户要求 DRH 项目影响接口补充模块标注，例如 `cms`、`endpoint`。
- 修正内容：将 D006 接口影响拆分为 `drh-pay`、`drh-endpoint`、`drh-kk-cms`、`drh-callback`、`drh-media-process` 五个模块表，并为每个接口 / 入口补充验证点。
- 文档同步：已同步更新 `spec.md` 与 `tasks.md`。
- 验证建议：测试按模块执行接口验证，重点确认目标表手机号查询走 `phone_md5`，展示值走 `phone_mask` 或本地掩码。

### D009 - 查询 / 保存输入格式兼容补充

- 触发原因：用户补充查询接口需支持明文手机号、前端加密手机号、手机号 MD5 三种格式；保存 / 更新需支持明文手机号、前端加密手机号两种格式。
- 当前确认：原 `computePhoneMd5()` 已支持明文和前端 AES 密文，但 32 位 MD5 会被当作普通字符串再次摘要，查询直接传手机号 MD5 不满足。
- 本次修正：`DataSecurityInvoke.computePhoneMd5()` 增加 32 位十六进制 MD5 直通识别，并做小写归一；`buildPhoneSecurity()` 不增加 MD5 保存支持，保存 / 更新仍必须通过明文或可解密密文生成三类安全字段。
- 文档同步：已补充“输入格式兼容口径”、用户故事、FR / SC、边界情况、测试建议，并同步 `tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 当前结论：改造后查询三种输入已满足；保存 / 更新两种输入已满足；手机号 MD5 不作为保存 / 更新支持格式。
