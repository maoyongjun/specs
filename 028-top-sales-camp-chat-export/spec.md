# 功能规格：近三期封闭营 Top 销售聊天记录导出

**功能目录**：`028-top-sales-camp-chat-export`  
**创建日期**：`2026-05-22`  
**状态**：Implemented  
**输入**：用户要求在 `C:\workspace\ju-chat\specs\028-top-sales-camp-chat-export` 补全 Spec Kit 文档，并已在 `C:\workspace\ju-chat\top-sales-camp-chat-export` 落地独立项目，实现 9 位指定销售近 3 期已结束封闭营的完整私聊记录导出。  
**范围**：记录需求、实现口径和验收标准；对应独立项目已落地到 `top-sales-camp-chat-export`，本文档作为规格与实现回填的统一说明。

## 1. 背景

业务方需要分析 Top 销售在各个营期阶段的沟通策略和话术模式，因此需要将指定销售在近 3 期封闭营内与分配学员的完整私聊记录导出为结构化数据。

这份导出不是普通消息归档，而是带有营期天数、课程阶段、学员状态与付费状态的训练数据集。后续会用于：

- 训练 AI Agent 的回复话术
- 优化不同阶段的跟进策略
- 复盘销售在接量期、课前、课中、课后的沟通差异

## 2. 目标

1. 为 9 位指定销售分别识别近 3 期已结束的封闭营。
2. 按销售 + 营期维度导出对应学员的全部私聊消息。
3. 为每条消息补齐：
   - 营期第几天
   - 当天阶段
   - 学员当日是否到课
   - 学员当日是否完课
   - 学员当日是否交作业
   - 学员是否付费
   - 付费时间
4. 按销售昵称和营期名称输出两级文件夹，便于后续人工抽样和模型训练。

## 3. 范围

### 3.1 导出销售

以下销售纳入导出范围：

- 邓冬梅
- 冯麒麟
- 高轩天
- 胡兰
- 李青青
- 李燕
- 杨帆
- 徐兴鹏
- 杨微

### 3.2 导出营期

- 每位销售只取近 3 期封闭营。
- 以已结束营期为准，按营期结束时间倒序取最近 3 期。
- 营期的内部主键使用 `camp_date_id`，导出字段中的 `camp_id` 使用营期业务编码/名称。

### 3.3 导出消息

导出该销售在目标营期内、分配学员的全部私聊消息，包括：

- 学员发的消息
- 销售手动发送的消息
- SOP 自动/策略发送消息
- 智能发送消息
- 群发消息

只排除真正的群聊消息，不排除私聊里的群发行为。

## 4. 术语

| 术语 | 说明 |
|---|---|
| `qwUserId` | 销售企业微信用户 ID，对应消息查询中的 `user_id` |
| `camp_date_id` | 营期内部主键 |
| `camp_id` | 导出结果中的营期业务标识 |
| `union_id` | 学员统一业务标识，用于订单与标签关联 |
| `external_user_id` | 学员企微外部联系人 ID，用于私聊消息查询 |
| `D0` | 接量期 |
| `D1~Dn` | 营期课程天数 |
| `课前` | 当天上课前 2 小时到上课时间 |
| `课中` | 上课时间到下课时间 |
| `课后` | 下课时间到次日课前 2 小时 |

## 5. 数据源

| 数据源 | 用途 | 关键字段 |
|---|---|---|
| `drh_live_camp_emp` | 识别销售与营期关系，获取 `qwUserId` | `emp_name`, `chat_id`, `camp_date_id` |
| `drh_live_camp_date` | 获取营期开始/结束时间与营期名称 | `id`, `camp_id`, `start_time`, `end_time`, `class_time`, `last_time` |
| `drh_external_user_info` | 获取学员标签、`union_id` 与外部联系人信息 | `external_user_id`, `union_id`, `tag` / 标签相关字段 |
| `drh_emp_external_user` | 获取销售-学员好友关系 | `chatId`, `externalUserid`, `unionId`, `status`, `createTime` / `empCreatetime` |
| `juzi_private_message` | 获取全部私聊消息 | `user_id`, `external_user_id`, `timestamp`, `isSelf`, `message_source`, `type`, `is_group`, `payload` |
| `drh_collect_order` | 获取学员订单与付费状态 | `unionId`, `createTime` |
| `drh_live` | 获取每天课程时间，计算 `camp_day` 与 `day_phase` | `campId`, `class_time`, `end_time`, `mark` / 课程标记 |

## 6. 数据流

### 6.1 销售与营期识别

1. 以销售姓名列表作为入口。
2. 通过 `drh_live_camp_emp` 找到销售对应的 `chat_id`，即 `qwUserId`。
3. 结合 `drh_live_camp_date`，筛出该销售近 3 期已结束的封闭营。
4. 记录每个营期的：
   - `qwUserId`
   - `camp_date_id`
   - `camp_id`
   - `camp_name`
   - `start_time`
   - `end_time`
   - `class_time` / 营期开课时间

### 6.2 学员识别与标签解析

1. 通过 `drh_emp_external_user` 获取销售的好友关系，锁定该销售在该营期内的学员范围。
2. 通过 `drh_external_user_info` 按 `external_user_id` 获取学员标签与 `union_id`。
3. 标签解析时只取与营期相关的标签：
   - 标签分组名称模糊匹配 `营期`
   - 标签名称匹配营期业务编码/名称，例如 `钢琴911.2.LYLS.0519`
4. 用同一次标签查询结果同时完成：
   - 营期映射
   - 当日到课标签判断
   - 当日完课标签判断
   - 当日作业标签判断

### 6.3 订单解析

1. 对已经报名或可能已付费的学员，按 `union_id` 批量查询 `drh_collect_order`。
2. 批量查询建议每次 200 个 `union_id`，避免 N+1 查询。
3. 订单状态必须按消息时间截面计算：
   - 如果首个有效订单时间早于或等于当前消息时间，才认为该行 `user_paid = TRUE`
   - 如果首个有效订单时间晚于当前消息时间，则该行仍视为未付费
4. 对于未在消息时间之前完成付费的行：
   - `user_paid = FALSE`
   - `paid_time = NULL`

### 6.4 私聊消息导出

1. 从 `juzi_private_message` 拉取消息。
2. 过滤条件：
   - `user_id = qwUserId`
   - `external_user_id = 学员 external_user_id`
   - `is_group` 为空或 `false`
   - `timestamp` 落在目标营期时间窗内
3. 消息需保留原始顺序与原始内容。
4. `message_source` 直接保留并标准化到规定枚举。

### 6.5 时间与阶段计算

1. 以营期配置中的开始日期作为 `camp_day` 的日期锚点，优先使用 `camp_start_date`，若配置里只有时间字段，则使用 `drh_live_camp_date.start_time`。
2. 以 `drh_live` 中对应营期的课程安排计算每天课程窗口。
3. 排除先导课后，再计算每一天的：
   - 最早上课时间 `course_start_time`
   - 最晚下课时间 `course_end_time`
4. 结合消息时间计算：
   - `camp_day`
   - `day_phase`
5. 如果一个自然日有多节课，按当天最早开始、最晚结束合并为同一天的课程窗口。

### 6.6 输出

1. 按销售昵称创建一级文件夹。
2. 按营期名称创建二级文件夹。
3. 导出文件放在对应二级文件夹下。
4. 文件内容按 `camp_id + union_id + timestamp` 排序。

## 7. 字段定义

| # | 字段名 | 类型 | 说明 | 示例 |
|---|---|---|---|---|
| 1 | `union_id` | string | 用户唯一标识 | `oNGxt5wawMb36ZBCReoip4f7leVI` |
| 2 | `contact_name` | string | 销售姓名 | `李燕` |
| 3 | `camp_id` | string | 营期业务标识 | `钢琴906.2.LYLS.0509` |
| 4 | `camp_day` | string | 营期第几天 | `D0 / D1 / D2 / D3 / D4 / D5 / D6` |
| 5 | `day_phase` | string | 阶段标记 | `接量期 / 课前 / 课中 / 课后` |
| 6 | `timestamp` | datetime | 消息时间 | `2026-05-07 19:35:22` |
| 7 | `isSelf` | string | 发送方 | `老师发送 / 学员发送` |
| 8 | `message_source` | string | 消息来源 | `SOP / 智能发送 / 手机发送 / 群发` |
| 9 | `message_type` | string | 消息类型 | `文字 / 图片 / 语音 / 视频 / 名片 / 链接` |
| 10 | `message_content` | string | 消息原文 | `老师辛苦了谢谢！[玫瑰]` |
| 11 | `user_attend_today` | bool | 该用户当日是否到课 | `TRUE / FALSE` |
| 12 | `user_complete_today` | bool | 该用户当日是否完课 | `TRUE / FALSE` |
| 13 | `user_hw_today` | bool | 该用户当日是否交作业 | `TRUE / FALSE` |
| 14 | `user_total_attend` | int | 该用户累计到课天数 | `3` |
| 15 | `user_paid` | bool | 该用户最终是否付费 | `TRUE / FALSE` |
| 16 | `paid_time` | datetime | 付费时间，未付费为空 | `2026-05-10 21:30:00` |

## 8. 规则定义

### 8.1 `camp_day` 计算规则

| camp_day | 定义 | 时间范围 |
|---|---|---|
| `D0` | 接量期 | 营期开始到 `D1` 上课前 |
| `D1~Dn` | 第 N 个课程日 | 按营期课程配置顺序计算 |

说明：

- `camp_day` 以营期课程日序号为准，不使用单纯的自然日递增。
- 日期锚点必须来自营期配置，不允许手工写死。
- 如果导出时缺少用户入群时间，则以营期开始时间作为 `D0` 起点。
- 如果营期实际只有 3 天课程，则只会出现 `D0~D3`，不会强行补齐不存在的天数。

### 8.2 `day_phase` 计算规则

| day_phase | 定义 | 时间范围 |
|---|---|---|
| `接量期` | 仅 `D0` | `D0` 全天 |
| `课前` | 当天上课前 2 小时 | `course_start - 2h ~ course_start` |
| `课中` | 课程进行中 | `course_start ~ course_end` |
| `课后` | 当天下课后 | `course_end ~ 次日课前 2h` |

边界优先级：

`课中 > 课前 > 课后 > 接量期`

说明：

- 同一时刻若落在多个边界上，按优先级判定。
- 如果当天没有课程，则该天只按接量期或前后相邻课程窗口判断，不生成虚假的课中时间段。

### 8.3 到课、完课、作业规则

1. 通过学员标签判断当天状态。
2. 标签命名建议统一为：
   - `D{n}到课`
   - `D{n}完课`
   - `D{n}作业`
3. 规则：
   - 命中 `D{n}到课`，则 `user_attend_today = TRUE`
   - 命中 `D{n}完课`，则 `user_complete_today = TRUE`
   - 命中 `D{n}作业`，则 `user_hw_today = TRUE`
4. `user_total_attend` 为截至当前消息所属 `camp_day` 的累计到课天数。
5. 当天没有对应标签时，布尔字段置为 `FALSE`，累计值按已命中的历史标签计算。

### 8.4 付费规则

1. `user_paid` 依据 `union_id` 在 `drh_collect_order` 中是否存在“发生在当前消息时间之前或当时”的有效订单判断。
2. `paid_time` 只在消息时间已经晚于或等于首个有效订单时间时填值，否则为空。
3. 若后续可以从更权威的订单表拿到真实支付时间，则可替换字段来源，但字段语义不变。

### 8.5 消息类型与来源规则

1. `isSelf`
   - 销售发出：`老师发送`
   - 学员发出：`学员发送`
2. `message_source`
   - 原值优先
   - 若原值为空，按发送方式和消息形态归一化
3. `message_type`
   - 文本类内容输出为 `文字`
   - 图片、语音、视频、名片、链接分别归类
   - 未识别类型保留原始值并映射到兜底类别，不丢数据
4. `message_content`
   - 保留原始消息内容
   - 对媒体消息保留可读摘要或原始文本，不做丢失性清洗

### 8.6 排序与去重

1. 排序主键：`camp_id + union_id + timestamp`
2. 同一时间戳下，按消息源记录 ID 升序作为稳定排序补充。
3. 不跨销售、不跨营期合并消息。

## 9. 输出结构

建议的输出结构如下：

```text
{export_root}/
  {contact_name}/
    {camp_name}/
      chat_records.csv
```

说明：

- `export_root` 由调用方或任务配置决定。
- 默认导出为 CSV，后续如需 Excel，只替换承载格式，不改字段口径。
- 目录名使用销售昵称和营期名称，便于人工复核。

## 10. 验收标准

### SC-001

能够识别 9 位指定销售，并为每位销售取近 3 期已结束的封闭营。

### SC-002

每个销售-营期组合都能输出完整私聊消息，不漏掉私聊中的群发/SOP/智能发送消息。

### SC-003

每条消息都能正确补齐 `camp_day`、`day_phase`、`user_attend_today`、`user_complete_today`、`user_hw_today`、`user_paid` 和 `paid_time`。

### SC-004

输出文件严格遵守 `销售昵称/营期名称/文件` 的两级目录结构，且文件内按 `camp_id + union_id + timestamp` 排序。

### SC-005

字段顺序与字段语义和本规格一致，不因实现细节变化而漂移。

### SC-006

先导课不参与 `day_phase` 计算，群聊消息不进入导出结果。

## 11. 残余风险

1. `paid_time` 当前按 ClickHouse `drh_collect_order.create_time` 的首个有效订单时间落地，若订单表后续权威字段变化，需要同步修订解析逻辑。
2. 封闭营识别当前按 `campDateStatus=4` 为主、`end_time < now()` 为兜底，若营期配置口径变化，需要同步修订筛选条件。
3. 先导课排除当前按 `isBeforeClass=1` 实现，若源表字段语义变化，需要同步修订课程窗口计算。

## 12. 记录

- D001 - 2026-05-22 - 完成本需求的规格化整理，覆盖销售范围、营期范围、字段定义、时间规则、标签规则、订单规则与输出结构
- D002 - 2026-05-22 - 独立项目 `top-sales-camp-chat-export` 已落地并完成验证，`mvn test` 与 `mvn package` 通过
- D003 - 2026-05-22 - ClickHouse 连接改为读取 `application.properties`，并保留环境变量/系统属性覆盖能力
- D004 - 2026-05-22 - 补充运行进度日志，输出销售、营期、学员、消息、行数和剩余数量
- D005 - 2026-05-22 - 项目改造为 Spring Boot CLI，使用 `logback-spring.xml` 输出控制台和滚动文件日志，并修复 OTS Search limit 上限
- D006 - 2026-05-22 - 移除 OTS 订单查询的 `createTime` 索引排序，改为查询后内存排序，修复 `field_name[createTime] is not existed`
- D007 - 2026-05-22 - 日志声明改为 Lombok `@Slf4j`，打包时排除 Lombok 运行库
- D008 - 2026-05-22 - 订单来源切换为 ClickHouse `drh_collect_order`，`paid_time` 对齐 `create_time`，并过滤 1997/1970 等异常 epoch 时间
