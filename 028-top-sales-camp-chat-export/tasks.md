# 任务清单：近三期封闭营 Top 销售聊天记录导出

**输入**：来自 `spec.md` 的功能规格  
**前置条件**：`spec.md`、`AGENTS.md`、`checklists/requirements.md`  
**测试**：实现已完成并通过 `mvn test`、`mvn package`；后续变更必须保留关键单测、CSV 结构和目录结构回归通过。  

**组织方式**：任务按阶段组织。当前状态为“规格、实现和验证均已回填”，以下条目记录真实工作拆分与验收闭环。

## Phase 1：代码事实确认

- [x] T001 复查本次需求与 `AGENTS.md`，确认范围为独立项目 `top-sales-camp-chat-export`，而不是继续改原有导出项目。
- [x] T002 搜索并确认 9 位目标销售名单，以及“近 3 期已结束封闭营”的筛选口径。
- [x] T003 确认 `drh_live_camp_emp` 与 `drh_live_camp_date` 的关联关系，锁定 `camp_date_id`、`qwUserId`、`camp_name`、`camp_id` 的来源。
- [x] T004 确认 `drh_live` 里课程窗口、`mark`、`isBeforeClass`、`classTime`、`endTime` 的用途，以及先导课排除规则。
- [x] T005 确认 `drh_emp_external_user` 与 `drh_external_user_info` 的关联字段、标签 JSON 结构和 `union_id` 的回填来源。
- [x] T006 确认 `juzi_private_message` 的消息过滤条件、排序字段、`is_group` 判定和 `message_source` / `type` 的标准化口径。
- [x] T007 确认 `drh_collect_order` / `drh_collect_order_ot` 的有效订单规则、订单状态、支付状态和支付时间字段。
- [x] T008 确认导出字段顺序、布尔值输出格式、时间格式 `yyyy-MM-dd HH:mm:ss` 和输出目录结构。

**检查点**：必须先完成事实确认，再进入风险门禁和实现拆分。

## Phase 2：风险门禁

- [x] T009 检查关键参数是否存在调用后赋值、空 DTO、空 Map、空 JSON 或占位对象继续下传的风险。
- [x] T010 检查标签解析是否存在跨营期串营风险，确认同一学员命中多个营期标签时以当前导出营期为准。
- [x] T011 检查 `camp_day` 是否按课程日窗口而不是自然日递增计算，确认 D0 / D1 / Dn 的边界。
- [x] T012 检查 `day_phase` 的优先级和跨日窗口，确认 `课中 > 课前 > 课后 > 接量期`。
- [x] T013 检查 `user_paid` 和 `paid_time` 的截面口径，确认按消息时间判断是否已存在有效订单。
- [x] T014 检查群聊与私聊群发的过滤边界，确认只排除真正群聊，不误删私聊中的群发、SOP 和智能发送。
- [x] T015 为 `CampDayCalculator`、`DayPhaseCalculator`、`TagResolver`、`PaymentResolver`、`CsvWriter` 建立测试映射。

**检查点**：风险门禁通过后，才允许拆分实现工作。

## Phase 3：实现拆分

- [x] T016 初始化独立 Maven Java 8 CLI 项目 `top-sales-camp-chat-export`，作为单独导出程序。
- [x] T017 建立 ClickHouse + MyBatis-Plus 访问层，承接 `drh_live_camp_emp`、`drh_live_camp_date`、`drh_live`、`drh_emp_external_user` 等 ClickHouse 侧查询。
- [x] T018 建立 OTS 访问层，承接 `drh_external_user_info`、`juzi_private_message` 等投影/索引查询；订单改由 ClickHouse `drh_collect_order` 承接。
- [x] T019 实现营期排期与课程窗口服务，输出 `CampSchedule`、`CourseDayWindow`、`CampDayValue` 等计算结果。
- [x] T020 实现学员标签解析、付费判定、消息标准化和 CSV 写出，保证单条消息都能补齐完整字段。
- [x] T021 实现导出编排服务，完成按销售/营期遍历、目录创建、排序输出、失败记录和 summary 回填。
- [x] T022 定义并对齐所有模型对象与导出字段顺序，避免 `contact_name`、`camp_name`、`message_id`、`timestampMillis` 等中间字段丢失。

**检查点**：实现拆分完成后，所有核心数据路径都应能单独验证。

## Phase 4：测试与验证

- [x] T023 为 `CampDayCalculator` 补充边界测试，覆盖 D0、课程日前后、最后一天、无课程日和跨日课后窗口。
- [x] T024 为 `DayPhaseCalculator` 补充边界测试，覆盖课前、课中、课后、接量期及边界优先级。
- [x] T025 为 `TagResolver` 补充测试，覆盖同营期多标签、缺标签和跨营期标签干扰。
- [x] T026 为 `PaymentResolver` 补充测试，覆盖未付费、部分付费、已全款和多个订单取最早有效时间。
- [x] T027 为 `CsvWriter` 补充测试，覆盖表头、字段顺序、布尔值输出、中文内容和引号转义。
- [x] T028 运行 `mvn test`，确认 12 个单元测试通过。
- [x] T029 运行 `mvn package`，确认可执行 jar 正常产出，且不会破坏测试结果。
- [x] T030 通过搜索命令复查 `MySqlConnectionProvider`、`mysql-connector-java` 和 `MYSQL_*` 残留，确认数据库驱动已切换为 ClickHouse。

**检查点**：测试和打包都通过后，才算实现验收闭环完成。

## Phase 5：文档收尾与执行记录

- [x] T031 回填 `spec.md`、`AGENTS.md`、`tasks.md`、`checklists/requirements.md` 的实施状态，去掉“仅做文档、不创建项目”的过期描述。
- [x] T032 在 `spec.md` 中记录独立项目已落地、当前实现假设和残余风险。
- [x] T033 在 `AGENTS.md` 中补充当前目录的维护方式、阅读顺序和后续变更约束。
- [x] T034 在 `checklists/requirements.md` 中补充实现完成和验证完成的状态说明。
- [x] T035 保留 Dxxx 执行记录模式，便于后续补充纠正或二次增量。
- [x] T036 记录后续如出现需求纠正时必须同步更新的文件清单。

## 执行记录

### D001 - 文档记录

- 执行内容：将 `tasks.md` 从 2 段式占位任务扩展为 5 个阶段的真实任务清单，覆盖事实确认、风险门禁、实现拆分、测试验证和文档收尾。
- 执行内容：同步修正 `spec.md`、`AGENTS.md`、`checklists/requirements.md` 中仍停留在“只写文档、不创建项目”的过期表述。
- 验证方式：静态复查文档结构、术语、任务编号与状态一致性。
- 自检结论：文档已从“仅规格草稿”切换为“规格 + 实现回填 + 验证记录”模式。

### D002 - 实现记录

- 实现内容：独立项目 `top-sales-camp-chat-export` 已完成，包含 ClickHouse + MyBatis-Plus 访问层、OTS 访问层、营期与阶段计算、标签解析、付费判定、消息导出和 CSV 写出。
- 实现内容：关键逻辑已覆盖 `CampDayCalculator`、`DayPhaseCalculator`、`TagResolver`、`PaymentResolver` 和 `CsvWriter` 的单测。
- 测试命令：`mvn test`
- 测试结果：`Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`
- 测试命令：`mvn package`
- 测试结果：BUILD SUCCESS，已产出 `top-sales-camp-chat-export-1.0.0.jar`
- 自检结论：已完成实现闭环；当前残余风险仅包括业务口径后续变化时对 `paid_time`、先导课排除字段和营期识别条件的同步维护。

### D003 - 纠正记录模板

- 触发原因：`<用户补充 / 测试失败 / 代码审查发现 / 参数遗漏 / 调用顺序问题>`
- 修正内容：`<写清楚旧口径和新口径>`
- 文档同步：`<spec / tasks / AGENTS / checklist 是否已同步>`
- 验证结果：`<测试或静态验证结果>`

### D004 - ClickHouse 配置纠正记录

- 触发原因：用户要求确认 ClickHouse 账号密码是否已放入配置文件；复查发现代码仍读取 `CLICKHOUSE_*` 环境变量。
- 修正内容：新增 `src/main/resources/application.properties`，将 ClickHouse 的 `user`、`password`、`server_host`、`port`、`db` 写入配置；`ClickHouseMybatisSessionProvider` 改为从配置读取并组装 JDBC URL，同时保留环境变量/系统属性覆盖能力。
- 文档同步：已同步 `README.md`、`tasks.md`、`spec.md`、`checklists/requirements.md`。
- 验证结果：新增 `EnvironmentTest` 验证资源配置可读取；`mvn test` 与 `mvn package` 重新通过。

### D005 - 运行进度日志补充记录

- 触发原因：用户反馈运行时缺少必要日志，无法判断已跑多少数据、还剩多少。
- 修正内容：新增 `ProgressLogger`，运行时同时输出控制台日志和 `{export_root}/progress.log`；日志覆盖导出开始、目标营期加载、销售进度、营期进度、学员进度、消息数、行数、剩余销售/营期/学员数、失败数和输出文件路径。
- 文档同步：已同步 `README.md` 与 `tasks.md`。
- 验证结果：`mvn test` 与 `mvn package` 通过。

### D006 - Spring Boot 改造记录

- 触发原因：用户要求将独立导出程序改造成 Spring Boot 项目。
- 修正内容：项目切换到 Spring Boot 2.7.18，启动类改为 `@SpringBootApplication` + `CommandLineRunner`，打包插件改为 `spring-boot-maven-plugin`；`logback.xml` 改为 `logback-spring.xml`，保留控制台日志和滚动文件日志。
- 兼容处理：命令行参数仍使用 `--output`，ClickHouse 配置和 OTS 环境变量读取方式不变；OTS Search 分页上限改为 `99`，修复 `[search.limit] must be less than 100`。
- 文档同步：已同步 `README.md`、`tasks.md`、`spec.md`、`checklists/requirements.md`。
- 验证结果：`mvn test` 与 `mvn package` 通过。

### D007 - OTS 订单排序字段纠正记录

- 触发原因：运行时报错 `TableStoreException: field_name[createTime] is not existed`，说明 `drh_collect_order_ots_index` 不支持按 `createTime` 排序。
- 修正内容：移除订单查询中的 OTS `createTime` 排序，继续分页取全量结果；取回后在内存中按 `PaymentOrder.earliestOrderTime()` 排序。
- 影响范围：只影响订单列表读取顺序，不改变有效订单、`user_paid` 或 `paid_time` 判断口径。
- 验证结果：`mvn test` 与 `mvn package` 通过。

### D008 - Lombok 日志注解改造记录

- 触发原因：用户要求日志使用 `@Slf4j`。
- 修正内容：新增 Lombok 编译期依赖，将 `TopSalesCampChatExportApp` 与 `ProgressLogger` 的手写 `LoggerFactory` 改为 `@Slf4j`，并在 Spring Boot 打包中排除 Lombok 运行库。
- 验证结果：`mvn test`、`mvn package` 与 `java -jar ... --help` 通过。

### D009 - 付费时间口径纠正记录

- 触发原因：用户用 `select * from drh_collect_order where union_id='oNGxt59SZEAPi4UR25tr4PGeBNPM'` 校验，期望 `paid_time=2026-05-01 20:13:44`；当前实现从 OTS 订单投影读取，可能被 `timeLong` 或异常 epoch 时间干扰。
- 修正内容：订单来源切换为 ClickHouse `drh_collect_order`，按 `union_id` 批量查询，使用 `create_time` 作为有效订单时间；`PaymentOrder` 增加业务时间下限，过滤 1997/1970 这类异常时间。
- 影响范围：`user_paid` 仍按消息时间截面判断；`paid_time` 与 `drh_collect_order.create_time` 对齐。
- 验证结果：`mvn test` 与 `mvn package` 通过，`PaymentResolverTest` 增加支付时间优先级和异常 epoch 过滤用例。
