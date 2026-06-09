# 任务清单：AppCollectOrderController 手机号安全返回补充

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 确认 `kkhc-idc/app` 与 `kkhc-idc/lms` 均存在 `AppCollectOrderController`。
- [x] T002 确认两个 Controller 均调用 `AppCollectOrderFacade.pageQuery`。
- [x] T003 确认两个 Facade 均在 `assembleAddressRecordOutputs` 中读取 `RealGoodsAddressRecordDO` 并返回手机号。
- [x] T004 确认 `RealGoodsAddressRecordDO` 已具备 `phoneMask/phoneMd5/phoneAes`。
- [x] T005 确认 `ai-common AppCollectOrderOutput` 已有安全字段，`lms-common AppCollectOrderOutput` 缺少安全字段。

## Phase 2：风险门禁

- [x] T006 检查接口契约：不新增路径、不改入参、不改分页条件。
- [x] T007 检查字段来源：安全字段来自 `RealGoodsAddressRecordDO`，不是当前层重新计算。
- [x] T008 检查调用顺序：地址记录查询后、返回前同步覆盖 `phone` 并设置安全字段。
- [x] T009 检查空值风险：地址记录不存在或安全字段为空时不抛异常。
- [x] T010 检查旧逻辑保持：商品组装、物流单号、异常容错和 Map key 规则不变。

## Phase 3：实现

- [x] T011 在 `lms-common AppCollectOrderOutput` 增加 `phoneMask/phoneMd5/phoneAes`。
- [x] T012 修改 `kkhc-idc/app AppCollectOrderFacade`，`phone` 改为返回 `phoneAes`，并设置三类安全字段。
- [x] T013 修改 `kkhc-idc/lms AppCollectOrderFacade`，`phone` 改为返回掩码值，并设置三类安全字段。
- [x] T014 为 app/lms 增加轻量单元测试，覆盖 app `phone=phoneAes`、lms `phone=phoneMask` 和安全字段透传。
- [x] T015 同步更新执行记录。

## Phase 4：测试与验证

- [x] T016 静态搜索确认两份 Facade 不再直接 `setPhone(addressRecord.getPhone())`。
- [x] T017 静态搜索确认 `lms-common AppCollectOrderOutput` 已有三类安全字段。
- [x] T018 静态搜索确认 app Facade 不调用 `phoneMaskForDisplay`，lms Facade 仍调用 `phoneMaskForDisplay`。
- [x] T019 运行目标模块编译：`base-common,lms-common,app,lms`。JDK 17 失败于既有 Nashorn `Property` 引用，JDK 8 超时，需 CI 补跑。
- [x] T020 运行新增单元测试。app/lms 轻量 JDK 8 JUnit 均通过。
- [x] T021 记录测试结果和剩余风险。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 `065-app-collect-order-phone-security-return` 规格目录。
- 验证方式：代码搜索、目标文件读取、历史规格比对。
- 自检结论：目标入口、字段来源、旧逻辑边界和测试映射已明确。

### D002 - 实现记录

- 实现内容：`lms-common AppCollectOrderOutput` 增加 `phoneMask/phoneMd5/phoneAes`；app Facade 返回 `phoneAes` 并透传三类安全字段；lms Facade 返回掩码并透传三类安全字段；新增 app/lms 轻量单测。
- 测试命令：
  - `mvn -f C:\workspace\ju-chat\kkhc\kkhc-idc\pom.xml -pl base-common,lms-common,app,lms -am "-DskipTests" compile`
  - 手动 JDK 8 `javac` 编译 app/lms 两份 Facade 和测试到 `target\codex-*-test-classes`
  - 手动 JDK 8 `JUnitCore com.kkhc.idc.lms.facade.order.app.AppCollectOrderFacadeTest`
- 测试结果：静态检查通过；app 轻量 JUnit 2 tests OK；lms 轻量 JUnit 2 tests OK；Maven JDK 17 失败于既有 `jdk.nashorn.internal.objects.annotations.Property` 引用；Maven JDK 8 超时。
- 自检结论：目标代码逻辑已验证；全量 Maven 需在常规 CI/JDK 环境补跑。

### D003 - idc-app phone 返回 phoneAes 纠正

- 触发原因：用户补充要求 `idc-app` 的 `AppCollectOrderController` 单独让 `phone` 返回 `phoneAes`。
- 修正内容：app Facade 的 `phone` 从掩码改为 `phoneAes`；lms Facade 保持掩码；app 单测断言同步改为 `phone-aes`。
- 文档同步：已同步 `spec.md`、`tasks.md`、`AGENTS.md`、`checklists/requirements.md`。
- 验证结果：静态搜索和 app/lms 轻量 JUnit 均通过。

### D004 - 纠正记录模板

- 触发原因：`说明为什么需要纠正`
- 修正内容：`说明具体修正`
- 文档同步：`说明同步了哪些文件`
- 验证结果：`说明测试或静态验证`
