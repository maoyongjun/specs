# 任务清单：手机号安全字段后台解密接口

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：新增单元测试覆盖关键行为；编译验证目标模块。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标项目为 `C:\workspace\drh\drh-kk-cms`。
- [x] T002 用代码搜索确认现有入口、调用链和核心工具类。
- [x] T003 确认 `DataSecurityInvoke.decryptPhoneAes(String)` 方法存在。
- [x] T004 通过 `javap -c` 确认 `decryptPhoneAes` 使用 `businessType=2`、`dataType=1` 调用函数计算，并保留本地 AES 兜底。
- [x] T005 确认现有 `TokenInterceptor` 会拦截所有接口，新接口不需新增白名单。

**检查点**：T001-T005 已完成，可进入实现。

## Phase 2：风险门禁

- [x] T006 检查是否存在空 DTO / 空 JSON / 空 Map 下传风险：请求体可能为空，Service 增加入参校验。
- [x] T007 检查调用后赋值风险：无；`phoneAes` 在调用 FC client 前已读取并校验。
- [x] T008 检查下游读取字段：仅 `phoneAes`，测试断言传入值不被改写。
- [x] T009 检查外部行为影响：新增 API 和一次同步 FC 调用，不修改旧接口、MQ、Redis、数据库。
- [x] T010 业务语义变化记录：接口返回明文手机号，按用户明确要求实现；未新增按钮权限和审计表。
- [x] T011 建立测试映射：正常路径、空入参、解密失败、编译验证。

**检查点**：T006-T011 已完成，可进入实现。

## Phase 3：实现

- [x] T012 新增接口 `POST /phone/security/decrypt`。
- [x] T013 新增 DTO：`PhoneDecryptInput`、`PhoneDecryptOutput`。
- [x] T014 新增 Service 与 FC client 封装，保持 FC 调用可测试。
- [x] T015 确保不记录明文手机号、不修改旧逻辑。

## Phase 4：测试与验证

- [x] T016 新增 `PhoneSecurityServiceImplTest`。
- [x] T017 测试断言 FC client 收到的 `phoneAes` 原值。
- [x] T018 测试空入参和解密失败异常。
- [x] T019 运行单元测试和编译命令：新增类局部编译通过，`PhoneSecurityServiceImplTest` 通过；全量 Maven 受本机环境限制未完成。
- [x] T020 搜索确认没有残留旧调用或旧口径变更。

## 执行记录

### D001 - 文档记录

- 执行内容：创建规格文档、任务清单、执行说明和质量检查清单。
- 验证方式：代码搜索、`javap` 方法签名和字节码确认。
- 自检结论：参数来源、调用顺序、旧逻辑保持和测试映射已明确。

### D002 - 实现记录

- 实现内容：新增后端解密接口、服务层、FC client 和单元测试。
- 测试命令：
  - `mvn "-Dsurefire.skip=false" "-DskipTests=false" "-Dtest=PhoneSecurityServiceImplTest" test`
  - `mvn -DskipTests compile`
  - JDK 8 `javac` 局部编译新增主类，并用 `org.junit.runner.JUnitCore` 运行 `PhoneSecurityServiceImplTest`
- 测试结果：
  - Maven + JDK 17：`LombokProcessor` 访问 `JavacProcessingEnvironment` 失败，属于旧 Lombok 与 JDK 17 模块兼容问题。
  - Maven + JDK 8：全量编译/测试命令超过 5 分钟未返回，已停止残留 Maven 进程。
  - 局部验证：新增主类 `javac` 编译通过；`PhoneSecurityServiceImplTest` 运行 3 个测试，结果 `OK (3 tests)`。
- 自检结论：新增接口和服务层参数来源清晰，FC client 收到的 `phoneAes` 已由单测断言；未修改旧 Mapper、旧保存链路和旧掩码展示逻辑。剩余风险为全量 Maven 需在项目常规 Java 8 / Lombok 编译环境补跑。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
