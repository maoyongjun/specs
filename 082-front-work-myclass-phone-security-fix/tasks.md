# 任务清单：FrontWork/FrontMyClass 手机号安全补遗

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现阶段必须补充与关键行为一一对应的测试或静态验证记录。

## Phase 1：代码事实确认

- [x] T001 复查用户需求和本目录 `AGENTS.md`，确认目标为 `C:\workspace\drh`（drh-common、drh-kk-cms），大前端工作台与我的班级链路。
- [x] T002 确认真实入口与调用链：
  - `FrontWorkController#queryList`(L80)/`#queryListV2`(L90)/`#queryUserDetail`(L145) → `FrontWorkServiceImpl` L337/L649/L736 明文 `setPhone(appletUser.getPhone())`。
  - `FrontMyClassController#userList`(L167)/`#pageList`(L178) → 策略工厂（realtime/task 均委托）→ `FrontMyClassUserServiceImpl#getMyClassUserVos` L295 builder 明文；`FrontMyClassUserPageVo` 包同一 Vo。
  - `#liveSingleList`(L107) → `FrontMyClassLiveSingleServiceImpl#getLiveSingleListVos` L842 `BeanUtil.copyProperties(user, vo)` 拷明文。
  - `#orderPage`(L200)/`#exportOrder`(L211) → realtime 活实现 `FrontMyClassOrderBoardServiceImplV2#initOrderVo` L344 builder 明文；V1 `FrontMyClassOrderBoardServiceImpl` 的 `@Service` 已注释=死代码；task 实现 `FrontEmpClassOrderServiceImpl` L81 走宽表（本次排除）。
- [x] T003 确认关键参数来源：`AppletUser` 实体已有 `phone/phoneMask/phoneMd5/phoneAes`（drh-common entity，L44/L298-300）；`AppletUserDetailDto` 已有三件套字段（L19-27）未赋值；`QueryListDto`、`FrontMyClassUserVo`、`FrontMyClassLiveSingleListVo`、`FrontMyClassBoardOrderVo` 缺三件套。工具类 `DataSecurityInvoke.phoneMaskForDisplay`(L218)、`DataSecurityUtil.maskPhone` 可直接复用。
- [x] T004 确认无配置/Redis/MQ/Feign/FC 调用变化；不改 SQL（`FrontMyClassOrderBoardMapper.xml` 已查出三件套列，仅 PO→Vo 拷贝层漏）；不改数据库表；策略选择配置 `front.class.strategy` 默认 realtime。
- [x] T005 确认必须不变的旧逻辑：查询入参 `phoneMd5` 链路（`FrontWorkServiceImpl:107`、`FrontMyClassBaseServiceImpl:172`）；`sendShortMsg`(L1231-1244) 明文发短信；归属地明文前 7 位查询(L716-724)；`SmsTriggerSingleLiveUserServiceImpl:426/440`、`SmsTriggerFollowLiveUserServiceImpl:~456`、`OutboundFollowLiveUserServiceImpl:~474` 内部读 `liveList()` 明文；`getAllInfo`(L691) 只读 unionId/appletUserId。

**检查点**：T001-T005 已完成（2026-06-12，进入实现前）。

## Phase 2：风险门禁

- [x] T006 占位传参检查：无 `new XxxDto()`/空 Map/空 JSON 占位；空列表/空页直接返回。
- [x] T007 调用后赋值检查：所有掩码/三件套赋值在组装记录时同步完成；`liveSingleList` 边界掩码在 service 返回后、controller 响应前同步执行，无异步补齐。
- [x] T008 下游读取字段来源检查：三件套来源 `AppletUser` 同名字段（查询已 select 全列或 copyProperties 自动携带）；展示 `phone` 现算现用。
- [x] T009 影响范围检查：DTO/Vo 加字段为向后兼容扩展；不改调用顺序、接口路径、外部请求、MQ body、Redis、数据库写入。风险点：①`@Builder+@AllArgsConstructor` 的 Vo 加字段改变全参构造器签名——需 grep 确认无手写全参 `new XxxVo(...)`；②hutool copyProperties 同名拷贝行为——编译+静态确认。
- [x] T010 业务语义变化确认：`phone` 由明文改掩码属于既定安全口径回归（用户原始需求）；三项设计决策（范围 A+B、controller 边界掩码、task 路径排除）已于 2026-06-12 经用户确认。
- [x] T011 测试映射：
  - FR-001/003（DTO 字段）→ 静态检查字段存在 + 编译。
  - FR-002/004/005（赋值与边界掩码）→ 静态检查赋值语句 + 编译。
  - FR-006（兜底）→ 静态检查兜底分支逻辑。
  - FR-007（旧逻辑不回归）→ grep 确认四处内部明文链路与查询链路零改动。
  - FR-008（无残留）→ 全范围 grep 扫描。

**检查点**：T006-T011 已有明确结论；高风险点已写入 `spec.md` 历史问题防漏分析与边界情况。

## Phase 3：实现

- [ ] T012 按规格实现最小范围改动：
  - `drh-common QueryListDto` +三件套；
  - `FrontWorkServiceImpl` L337/L649/L736 掩码+三件套；
  - `FrontMyClassUserVo/LiveSingleListVo/BoardOrderVo` +三件套；
  - `FrontMyClassUserServiceImpl` L295、`FrontMyClassOrderBoardServiceImplV2` L344 掩码+三件套；
  - `FrontMyClassController#liveSingleList` 边界掩码。
- [ ] T013 保持未声明的旧行为不变（Phase 1 T005 清单）。
- [ ] T014 断言点：本次无外部调用/MQ/Redis/DB 写入变化；以静态扫描断言返回对象组装内容（替代下游参数断言，口径同 080）。
- [ ] T015 实现后同步更新 `spec.md` D002、本文件执行记录、checklist。

## Phase 4：测试与验证

- [ ] T016 编译验证：`mvn -pl drh-common,drh-kk-cms -am compile`（`C:\workspace\drh`，JDK8）；如本地依赖阻塞则记录原因并以 javac 级静态检查替代。
- [ ] T017 静态断言返回对象组装内容：逐文件确认掩码+三件套赋值语句存在且来源正确。
- [ ] T018 边界与不回归验证：确认 `getLiveSingleListVos` 仍输出明文；SmsTrigger×2/Outbound/sendShortMsg/归属地零改动；`phoneMd5` 查询链路不变。
- [ ] T019 运行编译命令并记录结果。
- [ ] T020 残留扫描：范围内无 `setPhone(xxx.getPhone())`/`.phone(xxx.getPhone())` 流向前台返回对象（task 宽表路径除外，已知缺口）；无遗漏的全参构造器调用。

## 执行记录

### D001 - 文档记录

- 执行内容：创建 082 规格文档（AGENTS/spec/tasks/checklist），完成 Phase 1 代码事实确认与 Phase 2 风险门禁。
- 验证方式：逐文件亲自读取核对行号（FrontWorkController、FrontWorkServiceImpl、QueryListDto、AppletUserDetailDto、FrontMyClassController、FrontMyClassUserServiceImpl、FrontMyClassLiveSingleServiceImpl、FrontMyClassOrderBoardServiceImplV2/V1、FrontEmpClassOrderServiceImpl、FrontEmpClassOrder、QueryOrderPo、FrontMyClassOrderBoardMapper.xml、DataSecurityInvoke、SmsTrigger×2/Outbound、策略工厂）；全工程 grep 排查 phone 流向。
- 自检结论：满足强制门禁；三项设计决策已经用户确认（范围 A+B、controller 边界掩码、task 路径排除）。

### D002 - 实现记录

- 实现内容：`<实现后填写>`。
- 测试命令：`<命令>`。
- 测试结果：`<Tests run / BUILD SUCCESS / 静态检查结果>`。
- 自检结论：`<参数来源、调用顺序、旧逻辑保持、剩余风险>`。

### D003 - 纠正记录模板

- 触发原因：`<说明为什么需要纠正>`。
- 修正内容：`<说明具体修正>`。
- 文档同步：`<说明同步了哪些文件>`。
- 验证结果：`<说明测试或静态验证>`。
