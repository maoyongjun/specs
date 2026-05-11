# 任务清单：图书物流手机号兜底与已填写标签识别

**输入**：来自 `specs/011-tushu-phone-fallback-filled-tag/spec.md` 的功能规格  
**前置条件**：`spec.md`、`checklists/requirements.md`、`AGENTS.md`  
**测试**：通过模块编译检查和关键逻辑走查验证。

## Phase 1：规格与范围

- [x] T001 创建 Spec Kit 目录与 `AGENTS.md`、`spec.md`、`tasks.md`、`checklists/requirements.md`
- [x] T002 明确目标文件为 `AppTask.java`、图书记录 controller/service、`AiServiceImpl.java`
- [x] T003 明确手机号来源为 `otsInfo.phone_number`，接口参数名为 `phone`

## Phase 2：实现

- [x] T004 修改 `AppTask#setTushu` 入参，传递 OTS 手机号
- [x] T005 在 `applet_user_id` 为空时打印指定日志并按手机号兜底查询
- [x] T006 修改图书记录接口，使 `appletUserId` 和 `phone` 均为非必填
- [x] T007 修改图书记录服务，支持按手机号查询两张物流记录表
- [x] T008 在 `AiServiceImpl` 增加同 `userid` 的“已填写”标签判断
- [x] T009 在标签营期匹配成功时缓存 `if_tushu` 值

## Phase 3：测试

- [x] T010 编译 `coze_plugin` 的 `external-info-select` 模块
- [x] T011 编译 `kkhc-idc` 的 `ai` 模块
- [x] T012 记录验证结果和剩余风险

## 执行记录

### D001 - 实现记录

- `AppTask` 从 `otsInfo.phone_number` 读取手机号，兼容 `otsInfo.phone`。
- `setTushu` 在 `applet_user_id` 为空但手机号有值时继续调用图书查询接口。
- 图书查询接口新增非必填 `phone` 参数，服务层先用 `appletUserId` 反查手机号，失败后回退传入手机号。
- `AiServiceImpl` 新增当前 `qwUserId` 下的“已填写”标签判断，营期匹配成功后缓存 `if_tushu=是/否`。

### D002 - 验证记录

- 执行命令：`mvn -pl external-info-select -am -DskipTests test`
- 执行目录：`C:\workspace\ju-chat\coze_plugin`
- 执行结果：BUILD SUCCESS。
- 执行命令：`mvn -pl ai -DskipTests test`
- 执行目录：`C:\workspace\ju-chat\kkhc\kkhc-idc`
- 执行结果：BUILD SUCCESS。
- 额外尝试：`mvn -pl ai -am -DskipTests test`
- 结果：在既有依赖模块 `base-common` 编译失败，错误为 `AESUtils.java` 引用 `com.sun.jndi.toolkit.url` 不存在；该失败发生在进入 `ai` 模块前，非本需求改动引入。
- 剩余风险：未接入真实 OTS、Redis、数据库和网关做端到端联调；当前验证覆盖编译和静态逻辑。
