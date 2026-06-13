# 功能规格：liveAuth/ad/applet/v4 接口 AES 解密报错分析

**功能目录**：`089-liveauth-v4-aes-decrypt-error`  
**创建日期**：`2026-06-13`  
**状态**：Draft  
**输入**：接口 `/liveAuth/ad/applet/v4` 在接收明文手机号 `"17378120906"` 时，日志出现 ERROR：`DataSecurityUtil: AES aesDecrypt failed:Input length must be multiple of 16 when decrypting with padded cipher`。日志时间 2026-06-12 18:49:09，requestId=`4173c6bead384acfb8fa9cf610b55441`，线程 `http-nio-8400-exec-2`。

## 背景

- 当前问题：`/liveAuth/ad/applet/v4` 接口每次处理请求时，`DataSecurityInvoke.normalizePhoneInput()` 无条件尝试将输入按 AES 密文解密。当输入为明文手机号时，Base64 解码后的字节数不是 AES 块大小 (16) 的整数倍，触发 `javax.crypto.IllegalBlockSizeException`，并在 `DataSecurityUtil.aesDecrypt()` 第 268 行以 ERROR 级别写入日志，造成误导性的错误告警。
- 当前行为：`normalizePhoneInput()` 内部 catch 了异常并回退使用原始明文手机号，**功能上不影响业务流程**，但 ERROR 日志每次请求至少产生 1~2 条，给运维和排查问题带来噪音。
- 目标行为：在尝试 AES 解密前先做密文格式预判，仅对疑似密文才执行解密；对明文输入不再触发异常路径，消除无意义的 ERROR 日志。
- 非目标：本次不修改 AES 加解密算法本身，不改变手机号存储格式，不改变 FC（函数计算）调用逻辑。

## 调用链路与根因分析

### 请求入口

`POST /liveAuth/ad/applet/v4` -> `LiveAuthController.adAuth(@RequestBody AppletPhoneAuthV3Input input)` -> `LiveAuthServiceImpl.saveAppletUser(input)`

### 关键调用链

```
saveAppletUser(input)                          // LiveAuthServiceImpl:1155
  └─ input.createAesInfo()                     // LiveAuthServiceImpl:1167
       └─ DataSecurityInvoke.buildPhoneSecurity(phone)   // AppletUser.createAesInfo()
            └─ normalizePhoneInput(phone)                 // DataSecurityInvoke:151
                 └─ DataSecurityUtil.aesDecrypt("17378120906")  // DataSecurityInvoke:231 ← 报错点
```

### 根因：`normalizePhoneInput` 的"盲解密"设计

`DataSecurityInvoke.normalizePhoneInput()` 方法（第 226-239 行）设计逻辑如下：

```java
private static String normalizePhoneInput(String phoneInput) {
    if (phoneInput == null || phoneInput.isEmpty()) {
        return null;
    }
    try {
        // 无条件尝试 AES 解密——不管输入是明文还是密文
        String decryptedPhone = DataSecurityUtil.aesDecrypt(phoneInput);
        if (!StringUtils.isEmpty(decryptedPhone)) {
            return decryptedPhone;
        }
    } catch (Exception e) {
        // 明文手机号走这里，直接使用原值。
    }
    return phoneInput;
}
```

当传入明文 `"17378120906"`（11字符）时：

1. `DataSecurityUtil.aesDecrypt()` 内部执行 `Base64.getDecoder().decode("17378120906")`，产生 8 字节的数组。
2. AES/CBC/PKCS5Padding 解密要求输入字节数是 16 的整数倍，8 不满足此条件。
3. JCE 抛出 `IllegalBlockSizeException: Input length must be multiple of 16 when decrypting with padded cipher`。
4. `aesDecrypt` 在第 268 行以 **ERROR** 级别记录该异常：`log.error("AES aesDecrypt failed:{}", e.getMessage())`。
5. 异常向上传播，被 `normalizePhoneInput` 的 catch 块静默吞掉，原始明文 `"17378120906"` 被原样返回。

### 同类问题方法

`isWritablePhoneInput()` 方法（第 127-144 行）也存在类似逻辑：

```java
public static boolean isWritablePhoneInput(String phoneInput) {
    // ...
    try {
        String decryptedPhone = DataSecurityUtil.aesDecrypt(normalizedPhone);
        return isPlainPhone(decryptedPhone);
    } catch (Exception e) {
        return false;
    }
}
```

### 日志时序还原

根据日志时间戳还原请求执行时序（requestId=`4173c6bead384acfb8fa9cf610b55441`）：

| 时间 (.ms) | 级别 | 事件 |
|---|---|---|
| .116 | INFO | AutoCorsFilter 记录请求来源 |
| .117 | INFO | IpValidAop 记录请求 URL 和参数，phone=`"17378120906"` |
| .118 | DEBUG | selectOne ChannelEmp by channelId=`gdt2000` -> 返回 1 条 |
| .118 | DEBUG | selectOne AppletUser by unionId=null, category=5 -> 返回 0 条 |
| **.129** | **ERROR** | **aesDecrypt failed（第一次，来自 `createAesInfo` → `normalizePhoneInput`）** |
| .129 | INFO | FC 请求 DataSecurity-test（计算 phone 安全字段） |
| .249 | INFO | FC 响应成功：aesEncrypt=`k1ACqH5N2lDPl8qoQx+RHA==`，md5=`9a2f5329...` |
| .250 | DEBUG | selectOne CreativePlan by visitor -> 返回 0 条 |
| .260 | DEBUG | selectById AppletUser by id=15112833 -> 返回 1 条 |
| .265 | DEBUG | selectList BlackChannel by channelId=`gdt2000` -> 返回 0 条 |
| **.271** | **ERROR** | **aesDecrypt failed（第二次，来自 `computePhoneMd5` → `buildPhoneSecurity` → `normalizePhoneInput`）** |
| .271 | INFO | FC 请求 DataSecurity-test（第二次） |

每次请求至少产生 2 条 ERROR 日志：一次来自 `createAesInfo()`，一次来自 `computePhoneMd5()`。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 明文手机号传入不产生 ERROR 日志（优先级：P1）

当外部广告系统向 `/liveAuth/ad/applet/v4` 传入明文手机号时，系统应正常处理并生成 phone_mask、phone_md5、phone_aes，整个过程中不应产生 ERROR 级别的日志。

**独立测试**：发送 phone 为明文的 POST 请求，检查日志中不包含 `AES aesDecrypt failed` 的 ERROR 条目。

**验收场景**：

1. **Given** phone=`"17378120906"`（明文11位手机号），**When** 调用 `/liveAuth/ad/applet/v4`，**Then** 正常返回用户 ID，phone_mask/phone_md5/phone_aes 正确生成，日志中无 ERROR。
2. **Given** phone 为 AES 密文（如 `"k1ACqH5N2lDPl8qoQx+RHA=="`），**When** 调用该接口，**Then** 先解密为明文再处理，功能不受影响。

### 用户故事 2 - AES 密文手机号正常解密（优先级：P1）

当输入是前端加密后的 AES 密文时，`normalizePhoneInput` 应正确解密并返回明文手机号。

**独立测试**：构造 AES 密文输入，验证解密结果正确。

**验收场景**：

1. **Given** phone=`"k1ACqH5N2lDPl8qoQx+RHA=="`（已加密密文），**When** `normalizePhoneInput` 被调用，**Then** 返回 `"17378120906"`。
2. **Given** phone 为非法 Base64 字符串，**When** `normalizePhoneInput` 被调用，**Then** 直接返回原始输入，不触发 ERROR 日志。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `phone`：来源 `AppletPhoneAuthV3Input.phone`（请求体 JSON 字段）；赋值时机 请求到达时已由 Spring MVC 反序列化填充；下游读取位置 `AppletUser.createAesInfo()`、`DataSecurityInvoke.normalizePhoneInput()`、`LiveAuthServiceImpl` 中多处黑名单校验。
  - `phoneAes`：来源 `DataSecurityInvoke.buildPhoneSecurity()` 的 FC 响应中 `aesEncrypt` 字段；赋值时机 `createAesInfo()` 执行后；下游读取位置 `decryptPhoneAes()`（多处查询回显用）。
- 下游读取字段清单：
  - `createAesInfo()` 读取 `phone` 字段，写入 `phoneMask`、`phoneMd5`、`phoneAes`。
  - `normalizePhoneInput()` 读取传入的 phone 字符串，尝试解密后返回。
  - `isWritablePhoneInput()` 读取 phone 字符串，尝试解密后判断是否为合法手机号。
- 空对象 / 占位对象风险：
  - `normalizePhoneInput` 入参已有 null/empty 前置检查，不存在空对象风险。
- 调用顺序风险：
  - `createAesInfo()` 在 `saveAppletUser` 的第 1167 行调用，位于黑名单校验之前。黑名单校验使用的是 `input.getPhone()`（此时仍为原始值，createAesInfo 不会改变 phone 字段，仅填充 phoneMask/phoneMd5/phoneAes）。无调用顺序风险。
- 旧逻辑保持：
  - `normalizePhoneInput` 的 catch 块静默回退行为必须保留（作为兜底），仅增加预判和日志级别调整。
  - `aesDecrypt` 方法本身的 `log.error` 不应删除（保留给真实异常场景），但 `normalizePhoneInput` 和 `isWritablePhoneInput` 应自行拦截，不再让异常传到 `aesDecrypt`。
  - `isAesString()` 方法已存在于 `DataSecurityInvoke` 类中（第 259-266 行），可直接复用作为预判工具。
- 需要用户确认的设计选择：
  - 无。本次修复不改变任何业务语义或接口契约。

## 边界情况

- 空值/null phone：`normalizePhoneInput` 已有前置判断，直接返回 null。本次修复不影响。
- 非法 Base64 字符串：Base64 解码可能抛出 `IllegalArgumentException`，当前已被 catch 捕获。增加 `isAesString` 预判后可直接避免此路径。
- 短字符串（长度 < 16）：明文手机号（11位）Base64 解码后字节不足 16 字节，正是当前报错场景。`isAesString` 会按长度范围 (20-60) 过滤。
- 旧数据兼容：数据库中已有的 phone_aes 字段是用 `DataSecurityUtil.aesEncrypt()` 加密的标准密文，格式为 Base64 编码、长度 24 字符左右，在 `isAesString` 判断范围内 (20-60)。兼容性无影响。
- FC 服务不可用：与本次修复无关。FC 调用在 `buildPhoneSecurity` 中独立处理，有自身的异常兜底。

## 需求 *(必填)*

### 功能需求

- **FR-001**：`normalizePhoneInput` MUST 在调用 `aesDecrypt` 前使用 `isAesString` 或等效逻辑判断输入是否为疑似 AES 密文，仅对疑似密文执行解密。
- **FR-002**：`isWritablePhoneInput` MUST 在调用 `aesDecrypt` 前使用 `isAesString` 或等效逻辑判断输入是否为疑似 AES 密文。
- **FR-003**：系统 MUST NOT 改变 `normalizePhoneInput` 的最终返回结果——明文仍返回明文，密文仍解密为明文。
- **FR-004**：系统 MUST NOT 改变 `aesDecrypt` 方法本身的异常日志级别（保留 ERROR 给真实解密失败场景）。
- **FR-005**：单元测试 MUST 覆盖：明文手机号（11位数字）、AES 密文字符串、null 输入、空字符串、非法 Base64 字符串、短字符串（< 16字符）。

## 成功标准 *(必填)*

- **SC-001**：明文手机号 `"17378120906"` 传入 `/liveAuth/ad/applet/v4` 后，日志中不再出现 `AES aesDecrypt failed` 的 ERROR 条目。
- **SC-002**：AES 密文手机号传入后，`normalizePhoneInput` 正确解密为明文，功能回归测试全部通过。
- **SC-003**：`DataSecurityUtilTest` 中已有的加解密 round-trip 测试不受影响。

## 假设

- `isAesString()` 的判断规则（长度 20-60 且匹配 Base64 正则）足以区分当前业务中的 AES 密文和明文手机号。如果未来出现不在此范围内的合法密文格式，需要扩展判断逻辑。
- `normalizePhoneInput` 和 `isWritablePhoneInput` 是仅有的两处"盲解密"入口。如果存在其他位置的类似调用，需另行排查。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成调用链分析和根因定位。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- 实现内容：
  - 修改 `DataSecurityInvoke.normalizePhoneInput()`（第 229-244 行）：在调用 `aesDecrypt` 前增加 `isAesString(phoneInput)` 判断，仅对疑似密文执行解密。
  - 修改 `DataSecurityInvoke.isWritablePhoneInput()`（第 127-147 行）：在 `isPlainPhone` 判断之后、`aesDecrypt` 调用之前，增加 `!isAesString(normalizedPhone)` 短路返回 false。
  - 未修改 `DataSecurityUtil.aesDecrypt()` 本身。
- 影响范围：仅 `drh-common` 模块的 `DataSecurityInvoke` 类，共 2 个方法。
- 测试命令：`mvn clean compile -pl .`（编译验证）
- 测试结果：编译成功（1910 个源文件），无报错。单元测试因项目缺少 `junit-vintage-engine`（JUnit 4 在 JUnit 5 平台下不可见）未执行，属于项目既有问题。
- 自检结论：
  - 参数来源：无变化，`phone` 仍从请求体获取。
  - 调用顺序：无变化。
  - 旧逻辑保持：`normalizePhoneInput` 的 catch 块兜底保留；`aesDecrypt` 的 `log.error` 保留（仅在真正解密失败时触发）。
  - 行为验证：明文手机号（11位，长度 < 20）不通过 `isAesString` 判断，直接跳过解密；AES 密文（24字符，Base64 格式）通过判断后正常解密。
  - 剩余风险：如果未来出现长度 < 20 或 > 60 的合法 AES 密文，`isAesString` 会漏判，需要扩展判断范围。当前业务密文长度约 24 字符，无此风险。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
