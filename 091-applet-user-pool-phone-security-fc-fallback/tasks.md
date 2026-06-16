# 任务清单：AppletUserPool 分页 phone 掩码补算（phone_mask 为空走函数计算）

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段以目标模块编译 + 静态验证为主（函数计算为真实远程调用，不在单测中联调）。

## Phase 1：代码事实确认

- [x] T001 复查需求与 `AGENTS.md`：目标项目 `drh-kk-cms`，模块 `service.impl.AppletUserPoolServiceImpl`，链路为客服公海广告用户分页返回。
- [x] T002 确认入口/调用链/落点：入口 `AppletUserPoolServiceImpl.getPageList`；数据来源 `AppletUserPoolMapper.xml#selectPoolPage`；输出 `PoolAdListOutput`；函数计算工具 `com.drh.common.fc.datasec.DataSecurityInvoke#buildPhoneSecurity`；同类既有写法 `OrderRefundRecordServiceImpl`（`buildPhoneSecurity`→set mask/md5/aes）、`AdUserPicServiceImpl`（phone 统一返回掩码）。
- [x] T003 确认关键参数来源与字段类型：`PoolAdListOutput.phone/phoneMask/phoneMd5/phoneAes` 均为 `String`，来自 `selectPoolPage`（`au.phone/au.phone_mask/au.phone_md5/au.phone_aes`）。`buildPhoneSecurity` 返回 `PhoneSecurityInfo{rawPhone,phoneMask,phoneMd5,phoneAes}`。
- [x] T004 确认外部依赖：新增一次函数计算（FC，服务 `DataSecurity`/函数 `DataSecurity-pro`）调用；不涉及 MQ、Redis、Feign、DB 写入、SQL 变更。
- [x] T005 确认必须不变的旧逻辑：`phone_mask` 非空主路径；`getPermissionList` 权限过滤；分页；`phoneChannelSet` 渠道价格 key 用原始 `phone`（第 182、208 行）；其他字段装配与异常处理。

**检查点**：T001-T005 已完成。

## Phase 2：风险门禁

- [x] T006 占位对象检查：补算分支不构造占位手机号；`buildPhoneSecurity` 返回 `null`/掩码为空时按 `null` 兜底，沿用既有 `defaultMap`/`defaultInfo`。
- [x] T007 调用后赋值检查：phone 覆盖仍位于 `records.forEach` 末尾（原 `e.setPhone(e.getPhoneMask())` 位置），晚于渠道价格 key 读取，不前移、无“先明文后覆盖”窗口。
- [x] T008 下游读取来源检查：`phone`（掩码）、`phoneAes`、`phoneMd5` 在补算分支一次性赋值，均有确定来源（DB 或函数计算现算）。
- [x] T009 影响范围检查：仅新增函数计算调用（兜底分支）；不改路径、入参、分页、SQL、MQ、Redis、DB。函数计算调用方式（逐条 vs 批量、失败兜底）已与用户确认。
- [x] T010 业务语义确认：失败返回 `null`（不回退明文）、逐条内联调用，两点已由用户确认（见 spec D003）。
- [x] T011 测试映射：
  - 正常路径：`phoneMask` 非空 → `phone=掩码`，不调用函数计算。
  - 兜底路径：`phoneMask` 空 + `phone` 非空 → 入参为原始 `phone`，成功 `phone=掩码` 且回填三字段。
  - 非标准号：`+61432563303`、`15781266352-1781` 原样入参不被校验拦截。
  - 失败/不回归：函数计算返回 `null`/掩码空 → `phone=null`，不泄露明文。

**检查点**：T006-T011 已有明确结论，无未决高风险。

## Phase 3：实现

- [x] T012 替换 `getPageList` 中 `e.setPhone(e.getPhoneMask());` 为“掩码优先 / 空掩码走 `buildPhoneSecurity` 补算 / 失败兜底 null”分支。
- [x] T013 保持其他装配、权限、分页、渠道价格 key、异常处理不变。
- [x] T014 在补算分支以原始 `e.getPhone()` 作为函数计算入参（可静态断言入参内容与无格式校验）。
- [x] T015 新增 `import com.drh.common.fc.datasec.DataSecurityInvoke;`；同步 `spec.md`/`AGENTS.md`/`checklists`。

## Phase 4：测试与验证

- [x] T016 目标模块编译验证（JDK 8）。
- [x] T017 静态断言下游函数计算入参为原始 `phone`、补算后 `phone=掩码`、失败 `phone=null`、主路径不调用函数计算。
- [x] T018 边界确认：`phone_mask` 空 + `phone` 空 → `phone=null` 不调用函数计算；非标准号不被拦截。
- [x] T019 运行编译命令并记录结果（见 D002）。
- [x] T020 搜索确认无残留旧的无条件 `e.setPhone(e.getPhoneMask());`、无新增手机号格式校验。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `091-applet-user-pool-phone-security-fc-fallback` 全套规格文档；完成 Phase 1/2 代码事实确认与风险门禁。
- 验证方式：阅读 `AppletUserPoolServiceImpl`、`AppletUserPoolMapper.xml`、`PoolAdListOutput`、`DataSecurityInvoke`，对照 `OrderRefundRecordServiceImpl`/`AdUserPicServiceImpl` 既有写法。
- 自检结论：满足强制门禁；函数计算调用方式与失败兜底已向用户确认。

### D002 - 实现记录

- 实现内容：
  - `AppletUserPoolServiceImpl.getPageList`（`records.forEach` 末尾）：
    - `phoneMask` 非空 → `e.setPhone(e.getPhoneMask())`；
    - `phoneMask` 空 + `phone` 非空 → `DataSecurityInvoke.buildPhoneSecurity(e.getPhone())`，成功则 `setPhoneMask/setPhoneMd5/setPhoneAes` 并 `setPhone(掩码)`，失败（`null` 或掩码空）则 `setPhone(null)`；
    - 其余 → `setPhone(null)`。
  - 新增 `import com.drh.common.fc.datasec.DataSecurityInvoke;`。
- 测试命令（JDK 8，`JAVA_HOME=C:\Program Files\Java\jdk1.8.0_481`）：
  - `mvn -o -pl drh-common install -DskipTests -q`（先刷新本地仓库中过期的 drh-common）
  - `mvn -o -pl drh-kk-cms compile -DskipTests -q`
- 测试结果：
  - `drh-common install`：BUILD SUCCESS（EXIT=0）。
  - `drh-kk-cms compile`：BUILD SUCCESS（EXIT=0）。
  - 说明：首次编译报错来自 `FrontWorkServiceImpl` 引用 `QueryListDto.setPhoneMask/Md5/Aes`，是本地仓库中 drh-common（2026-06-12 快照）过期所致，与本次改动无关；按源码重装 drh-common 后该报错消失，drh-kk-cms 编译通过。
  - 静态验证：`AppletUserPoolServiceImpl` 中仅在 `phoneMask` 非空分支调用 `e.setPhone(e.getPhoneMask())`；兜底分支以原始 `e.getPhone()` 调用 `buildPhoneSecurity`；无 `isPlainPhone`/`isWritablePhoneInput` 等格式校验；失败路径 `e.setPhone(null)`。
- 自检结论：编译通过；入参为原始 phone 且无格式校验；明文不泄露不变量保持；主路径与其他装配无回归。
- 剩余风险：
  - 函数计算在 `phone_mask` 为空的兜底分支逐条调用，单页最多触发与空掩码行数相等次数的远程调用（用户已确认接受；假设绝大多数行已回填 `phone_mask`）。
  - 未做 `getPageList` 端到端单元测试（方法依赖众多 service + 真实函数计算），以编译 + 静态验证替代，符合“单测不联调函数计算”的清单要求。
  - 全量 reactor 构建未跑（外部依赖与本机 JDK/Lombok 环境限制），需在项目常规 CI 环境补跑。

### D003 - 设计确认记录

- 触发原因：实现前确认两处设计点。
- 修正内容：函数计算失败 → `phone=null` 不回退明文；`phone_mask` 为空逐条内联调用函数计算、保持最小改动。
- 文档同步：已同步 `spec.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：实现按确认口径落地（见 D002）。
