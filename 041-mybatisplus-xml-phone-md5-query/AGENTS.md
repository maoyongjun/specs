# 规格执行说明

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\041-mybatisplus-xml-phone-md5-query`
- 目标工程：`C:\workspace\drh`
- 重点模块：`drh-kk-cms`
- 典型入口：
  - `C:\workspace\drh\drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\BookQuestionRecordServiceImpl.java`
  - `C:\workspace\drh\drh-kk-cms\src\main\resources\mapper\ExternalBookQuestionRecordMapper.xml`

## 当前目标

- 处理 MyBatis XML 中仍直接用 `phone` 字段查询的问题。
- 不只处理 `ExternalBookQuestionRecordMapper.xml`；实现前必须全量检查其他 Mapper XML 是否存在同类手机号明文字段依赖。
- 在 `phone` 明文字段后续清空后，目标查询仍可通过 `phone_md5` 命中记录。
- 查询接口保持 `phone` 属性名不变，兼容明文手机号、前端加密手机号和 MD5 手机号。
- 保存 / 更新接口保持 `phone` 属性名不变，但只接受明文手机号和前端加密手机号，不接受 MD5 手机号。
- 本轮已进入代码实现阶段，业务代码改动位于 `C:\workspace\drh`。

## XML 扫描范围

- 扫描 `C:\workspace\drh` 下所有 `*.xml`。
- 扫描 `C:\workspace\ju-chat\kkhc\kkhc-idc\ai` 下所有 `*.xml`。
- 搜索形态必须覆盖：
  - `phone = #{...}`、`phone in (...)`、`phone like ...`。
  - `phone is null`、`phone is not null`。
  - `xxx.phone = yyy.phone` 这类 join。
  - `select phone` 或返回字段中直接暴露 `phone`。
  - `#{...phone...}` 和 `${...phone...}` 参数引用。
- 命中点必须分类记录：可直接改 `phone_md5`、需业务确认、可排除。

## 入参规则

### 查询接口

- `phone` 为明文手机号：调用现有 `DataSecurityInvoke.computePhoneMd5(phone)` 得到 `phoneMd5`。
- `phone` 为前端加密手机号：沿用现有兼容逻辑解密 / 规范化后得到 `phoneMd5`。
- `phone` 为 32 位 MD5：直接作为 `phoneMd5` 使用，不再二次计算。
- XML Mapper 只读取 `input.phoneMd5` 与数据库 `phone_md5` 字段匹配。

### 保存 / 更新接口

- `phone` 只允许明文手机号或前端加密手机号。
- `phone` 不允许传 32 位 MD5。
- `phone` 为 32 位 MD5、无法解密且不是有效明文手机号、或加密格式不符合预期时，返回参数错误。
- 错误提示固定为：`手机号加密格式不符`。

## 执行原则

- 先确认入口和 XML 下游读取字段，再实现。
- 不允许只改 Java 层计算 `phoneMd5`，却遗漏 XML 中的 `phone = #{input.phone}`。
- 不允许只处理一个 XML 文件；全量扫描命中的其他 XML 必须有处理结论。
- 不允许只改一个 UNION 分支；同一查询中的所有手机号条件必须一致使用 `phone_md5`。
- 对 `phone like` 不得强行改为 MD5 模糊查询；MD5 只能做等值匹配，需要业务确认新口径。
- 对 `phone is null/not null` 和 `select phone` 不得默认忽略；如果所属表明文 `phone` 会清空，需要改为安全字段或确认排除。
- 不允许保存 / 更新接口把 MD5 当作普通手机号生成安全字段。
- 保持原接口字段名 `phone` 不变，不要求前端新增 `phoneMd5` 参数。
- 保持非手机号过滤条件不变，包括 `goodsId`、`expressNoList`、`empId`、`systemEmpId`、`source`、`AI-%`、`H5-用户提交` 等条件。
- 单元测试或 Mapper 验证不能只看最终返回值；必须验证下游 SQL 或 Mapper 参数使用的是 `phoneMd5`。
- 实现记录必须同步写入 `tasks.md` 和 `spec.md`，并保留全量 XML 扫描的分类结论。

## 强制门禁

实现前必须完成以下检查，并记录到 `tasks.md` 或 `checklists/requirements.md`：

- 参数来源：所有进入目标 XML 的 DTO 是否都有 `phoneMd5` 来源。
- 赋值时机：`phoneMd5` 是否在 Mapper 调用前完成赋值。
- 占位对象：是否存在 `new XxxDto()` 后只 set `phone`、`goodsId`、`expressNoList` 的临时对象。
- 下游读取：目标 XML 是否只读取 `input.phoneMd5` 查询手机号。
- 查询兼容：明文、前端加密、MD5 三种查询入参是否都有测试映射。
- XML 全量扫描：所有命中点是否已有分类处理结论。
- 保存 / 更新校验：MD5 入参是否会被拒绝，错误文案是否固定。
- 旧逻辑保持：非手机号过滤、异常处理、日志和原返回结构是否不变。

## 重点代码位置

- `drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\BookQuestionRecordServiceImpl.java`
- `drh-kk-cms\src\main\java\com\drh\kk\cms\service\impl\ExternalBookQuestionRecordServiceImpl.java`
- `drh-kk-cms\src\main\java\com\drh\kk\cms\dto\bookpath\CreateExternalBookQuestionRecordDto.java`
- `drh-kk-cms\src\main\java\com\drh\kk\cms\dto\bookpath\BookQuestionRecordHistoryInput.java`
- `drh-kk-cms\src\main\resources\mapper\ExternalBookQuestionRecordMapper.xml`
- `drh-common\src\main\java\com\drh\common\fc\datasec\DataSecurityInvoke.java`

## 初始扫描候选

- `drh-kk-cms`：`WorksShipMapper.xml`、`WorksAwardsRecordMapper.xml`、`UserQuestionMapper.xml`、`SpecailUserMapper.xml`、`RenewDataMapper.xml`、`OrderHandRecordMapper.xml`、`OrderHandRecordDelMapper.xml`、`LiveCampUserMapper.xml`、`HandoverPlusMapper.xml`、`DayUrgeClassMapper.xml`、`AppletUserPoolMapper.xml`、`AppletUserMapper.xml`、`AppletSalePoolMapper.xml`、`AppletPlayerMapper.xml`、`AdUserPicMapper.xml`、`HandoverMapper.xml`。
- `drh` 其他模块：`AppStudyInfoMapper.xml`、`RegisterWorksMapper.xml`、`AppletUserMapper.xml`。
- `ju-chat/kkhc/kkhc-idc/ai`：`OrderBookReissueMapper.xml`、`AppletUserMapper.xml`。
- 该清单只是当前文档阶段的初始静态搜索结果；实现前必须重新执行扫描并按最新结果处理。

## 文档维护

- `spec.md` 描述用户场景、需求、边界、成功标准、假设和纠正记录。
- `tasks.md` 记录事实确认、风险门禁、实现任务、测试任务和执行记录。
- `checklists/requirements.md` 用于验证规格质量、参数完整性和实施就绪度。
- 每次用户纠正、补充或推翻前一版口径，都必须追加 Dxxx 执行记录，并同步更新相关文档。
