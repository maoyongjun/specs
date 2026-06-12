# 规格执行说明

本目录记录 `082-front-work-myclass-phone-security-fix`，作用范围包含：

- 规格文档：`C:\workspace\ju-chat\specs\082-front-work-myclass-phone-security-fix`
- 目标项目：`C:\workspace\drh`
- 相关模块：`drh-common`、`drh-kk-cms`
- 前置需求：`032/036/048/066/067/073/080`（手机号安全系列，统一口径与工具类来源）

## 当前目标

- 修复 `com.drh.kk.cms.controller.FrontWorkController#queryList` 手机号安全改造遗漏：返回记录补安全三字段（`phoneMask/phoneMd5/phoneAes`），`phone` 改回掩码展示值。
- 修复同文件同模式遗漏：`FrontWorkController#queryListV2`、`#queryUserDetail`。
- 修复同类遗漏：`FrontMyClassController` 的 `/user/list`、`/user/pageList`、`/live/single/list`、`/dataBoard/orderPage`、`/dataBoard/exportOrder`。
- `/live/single/list` 采用 controller 边界掩码：service 返回保持明文，短信触达（SmsTrigger×2）和外呼（Outbound）内部复用链路零改动（用户已确认）。
- task 策略宽表路径（`FrontEmpClassOrderServiceImpl` / `drh_front_emp_class_order` 无安全字段）排除出本次范围，记录为已知缺口（用户已确认）。

## 执行原则

- 先读代码，再定方案，后实现。
- 不允许只根据需求文本猜测真实落点；实现前必须确认入口、调用链、字段来源、配置来源和测试落点。
- 不允许把空对象、占位 DTO 或未赋值字段当成有效输入继续传递。
- `phone` 展示值统一用 `DataSecurityInvoke.phoneMaskForDisplay(phoneMask, phoneAes)`；mask/aes 均空且实体 `phone` 为 11 位明文时本地 `DataSecurityUtil.maskPhone` 兜底，绝不透出明文。
- 服务端内部需要明文的旧行为不得改变：`FrontWorkServiceImpl#sendShortMsg` 发短信、`#queryUserDetail` 明文前 7 位查归属地、SmsTrigger/Outbound 读 `liveList()` 明文。
- 不修改查询 SQL、接口路径、HTTP 方法、分页语义、DDL、宽表生成链路。

## 强制门禁

- 参数来源：所有新增 `phone*` 字段来源 `AppletUser.phoneMask/phoneMd5/phoneAes`（实体已有，`drh_applet_user` 在历史回填 7 表之列）。
- 赋值时机：service 组装记录时同步赋值；`/live/single/list` 在 controller 返回前边界赋值。
- 占位对象：空列表/空页直接返回，不构造占位记录。
- 下游读取：短信/外呼服务从 service 层 `liveList()` 读 `vo.getPhone()` 明文——边界掩码方案下不变；`getAllInfo` 只读 `unionId/appletUserId` 不受影响；CSV 导出从 `FrontMyClassBoardOrderVo` 拷贝，掩码后 CSV 自动得掩码。
- 旧逻辑保持：查询入参 phoneMd5 链路（`FrontWorkServiceImpl:107`、`FrontMyClassBaseServiceImpl:172`）、等级筛选、分页、标签、群发次数等组装逻辑不变。
- 影响范围：仅 DTO/Vo 加字段（向后兼容）与展示赋值变化；不改调用顺序、远程调用、MQ、Redis、数据库写入。
- 测试映射：编译 + 静态扫描（范围内无残留明文 `setPhone(xxx.getPhone())` / `.phone(xxx.getPhone())` 流向前台返回对象；四处明文旧行为未被误改）。

## 重点代码位置

- 入口：
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\FrontWorkController.java`（queryList L80 / queryListV2 L90 / queryUserDetail L145）
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\controller\workServe\front\FrontMyClassController.java`（liveSingleList L107 / userList L167 / pageList L178 / orderPage L200 / exportOrder L211）
- 核心实现：
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\FrontWorkServiceImpl.java`（L337 / L649 / L736）
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\workServe\front\realtime\impl\FrontMyClassUserServiceImpl.java`（L295）
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\workServe\front\realtime\impl\FrontMyClassOrderBoardServiceImplV2.java`（L344 initOrderVo）
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\workServe\front\realtime\impl\FrontMyClassLiveSingleServiceImpl.java`（L842，本次不改 service，仅 Vo 加字段后由 copyProperties 自动携带）
- DTO/Vo：
  - `C:\workspace\drh\drh-common\src\main\java\com\drh\common\dto\frontwork\QueryListDto.java`
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\AppletUserDetailDto.java`（已有三件套，只补赋值）
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\workServe\front\vo\FrontMyClassUserVo.java`
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\workServe\front\vo\FrontMyClassLiveSingleListVo.java`
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\dto\workServe\front\vo\FrontMyClassBoardOrderVo.java`
- 工具类（沿用不改）：
  - `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`（`phoneMaskForDisplay` L218）
  - `C:\workspace\drh\drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityUtil.java`（`maskPhone`）
- 已整改参照：`AppletActivityController:268-270`、`AdBlackPhoneController#list`、`AppletUserDetailDto:19-27`
- 测试位置：`C:\workspace\drh\drh-kk-cms\src\test\java\`（pom 默认 skipTests，本次按 080 口径用编译+静态验证）

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
