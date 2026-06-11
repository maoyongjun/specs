# 功能规格：LivingStudyInfoRecordServiceImpl 完课标签缺失原因分析

**功能目录**：`070-living-finish-tag-missing-analysis`  
**创建日期**：`2026-06-10`  
**状态**：Analysis  
**输入**：在 `C:\workspace\ju-chat\specs` 创建 Spec Kit 文档，分析 `LivingStudyInfoRecordServiceImpl#doSave` 没有打完课标签的原因。用户提供日志时间 `2026-06-09 21:39:08`，关键请求为 `userId=189338`、`liveId=1143726`、`campId=16905`、`seconds=25`、`degree=5674`、`sliceId=248308`、`studySource=app`。

## 背景

- 当前问题：用户观看记录累计到 `8212` 秒后，没有看到完课标签触发。
- 当前行为：`doSave` 每次上报观看秒数后累计 `drh_living_study_info.seconds`，在特定分支计算 `status=2` 后才发送完课标签 MQ。
- 直接结论：这次请求没有进入发送完课标签的分支。日志中的 SQL 是 `UPDATE drh_living_study_info SET seconds=?,degree=?,slice_id=? WHERE (id = ?)`，没有更新 `status`，对应代码中的“已完课或直播时长为空/0”兼容分支；该分支内完课标签发送代码已被注释。
- 非目标：本阶段不修改 Java 代码、不补偿标签、不连接线上数据库、不部署服务。

## 结论

### 已由日志证明

- 请求进入了 `LivingStudyInfoRecordServiceImpl#doSave`：日志打印 `用户观课:liveId:1143726,userId:189338, seconds:25`。
- 本次上报通过基础校验：`seconds=25` 在 `3..180` 范围内，且后续实际执行了数据库更新。
- 本次只发送了 `SLS_ASYNC` MQ，用于记录 `livingStudyInfoRecordDto`，不是企微打标签 MQ。
- `drh_living_study_info` 更新参数为 `8212, 5674, 248308, 39994622`，说明记录 `id=39994622` 的累计观看时长被更新为 `8212` 秒。
- 更新 SQL 没有 `status=?`，因此没有执行“设置 `status=2` 并发送 `MqDayEnum.finish`”的普通更新分支。
- 日志中出现的 `SELECT * FROM drh_live_camp_date WHERE camp_id = 16905 limit 1` 返回 0，只会让 `isDisplayHuacaiCoinInfo` 返回 false，影响华彩豆展示/奖励，不是完课标签的直接拦截条件。

### 代码推导

本次 SQL 形态只能来自下面分支：

```java
if (livingStudyInfo.getStatus().equals(FINISH) || Objects.isNull(length) || length.equals(0)) {
    update seconds, degree, sliceId;
    // 已经完课，不再触发完课标签
    // worksProducerBean.doSendQwTag(userId, liveId, MqDayEnum.finish);
} else {
    update seconds, status, degree, sliceId;
    if (status == 2) {
        worksProducerBean.doSendQwTag(userId, liveId, MqDayEnum.finish);
    }
}
```

因此未打完课标签的直接原因是：`doSave` 进入了兼容分支，兼容分支不发送完课标签。

需要通过数据库把兼容分支再拆成两类；用户补充已确认 `drh_live.length` 不是 0，因此当前优先级应收敛到第 1 类：

1. `drh_living_study_info.status = 2`：系统认为此前已经完课，本次请求按防重逻辑只累计观看数据，不重复打完课标签。若企微侧没有标签，问题应按“历史完课标签 MQ 丢失/消费失败/企微写入失败”补偿排查。
2. `drh_live.length IS NULL OR drh_live.length = 0` 且 `drh_living_study_info.status != 2`：课程时长缺失导致代码进入兼容分支，未把本次累计观看换算成完课状态，也不会发送完课标签；该项已被用户补充信息初步排除。

## 调用链

1. `POST /living/save` 进入 `LivingController#save`。
2. `BaseController#getRoomInfo` 从请求头 `room` 解密得到 `campId=16905`、`livingId=1143726`。
3. 请求体提供 `userId=189338`、`seconds=25`、`degree=5674`、`sliceId=248308`、`studySource=app`。
4. `LivingStudyInfoRecordServiceImpl#doSave` 先发送 `SLS_ASYNC` 观看记录 MQ。
5. `doSave` 从缓存或数据库读取 `LivingStudyInfo`、`LiveInfo`、`LiveCamp`。
6. `isDisplayHuacaiCoinInfo` 查询 `drh_live_camp_date`，本次返回空，只影响华彩豆展示。
7. 代码累计 `resultSeconds = oldSeconds + seconds = 8212`。
8. 因旧状态已完课或 `LiveInfo.length` 为空/0，代码进入兼容分支，只更新 `seconds/degree/sliceId`。
9. 由于未进入 `status == 2` 分支，未执行 `worksProducerBean.doSendQwTag(userId, liveId, MqDayEnum.finish)`。

## 用户场景与测试

### 用户故事 1 - 定位完课标签未触发原因（优先级：P1）

研发需要判断这次未打完课标签是观看时长不足、请求被限流、华彩豆配置缺失、已完课防重，还是直播时长字段缺失。

**独立测试**：用日志 SQL 形态对齐 `doSave` 分支，确认是否执行 `status == 2` 和 `doSendQwTag(... finish)`。

**验收场景**：

1. **Given** `drh_living_study_info.status=1` 且 `drh_live.length` 有有效值，**When** 累计观看满足完课阈值，**Then** SQL 应包含 `status=?`，且发送 `QW_TAG` 的 `finish` 消息。
2. **Given** `drh_living_study_info.status=1` 且 `drh_live.length` 为空或 0，**When** 累计观看达到 8212 秒，**Then** SQL 只更新 `seconds/degree/sliceId`，不会发送完课标签。
3. **Given** `drh_living_study_info.status=2`，**When** 再次上报观看进度，**Then** 只累计观看数据，不重复发送完课标签。

### 用户故事 2 - 后续修复或补偿边界（优先级：P2）

研发后续需要决定是补数据、补标签，还是改代码兜底，避免把华彩豆查询问题误修成完课标签问题。

**独立测试**：分别构造“已完课但标签缺失”和“length 缺失未完课”两类数据，验证补偿和代码方案不会重复打标签。

**验收场景**：

1. **Given** `status=2` 但企微没有完课标签，**When** 执行补偿，**Then** 应按幂等策略补发 `finish` 标签，不回改观看状态。
2. **Given** `length` 缺失且 `status=1`，**When** 补齐 `drh_live.length` 或代码增加销转课兜底，**Then** 再次上报或补偿扫描可以计算 `status=2` 并发送完课标签。

## 关键日志证据

- 请求入口：`controller 请求url:http://kapi.likeduoduiyi.cn/endpoint/living/save`
- 请求体：`{"degree":5674,"operatingSystem":"android","seconds":25,"sliceId":248308,"studySource":"app","userId":189338}`
- 请求头：包含 `unionid=oNGxt59okAFPuAQSb6qd3GYr3eB4` 和加密 `room`
- `doSave` 入参：`{"campId":16905,"degree":5674,"livingId":1143726,"operatingSystem":"android","seconds":25,"sliceId":248308,"studySource":"app","userId":189338}`
- 观看记录 MQ：`messageType=SLS_ASYNC`，不是 `QW_TAG`
- 华彩豆营期日期查询：`SELECT * FROM drh_live_camp_date WHERE (camp_id = ?) limit 1`，参数 `16905`，返回 `Total: 0`
- 观看进度更新：`UPDATE drh_living_study_info SET seconds=?,degree=?,slice_id=? WHERE (id = ?)`，参数 `8212, 5674, 248308, 39994622`

## 复核 SQL

```sql
-- 1. 确认观看记录当前状态。若 status=2，说明本次未打标签属于已完课防重分支。
SELECT id, living_id, user_id, status, seconds, degree, slice_id, update_time
FROM drh_living_study_info
WHERE id = 39994622
   OR (living_id = 1143726 AND user_id = 189338);

-- 2. 确认课程时长。若 length 为空或 0，说明本次进入兼容分支的原因是直播时长缺失。
SELECT id, live_camp_id, length, end_time, status, class_time, is_del
FROM drh_live
WHERE id = 1143726;

-- 3. 确认营期类型。销转课 is_class=0 时完课阈值本可按分钟配置计算；正式课 is_class=1 依赖 length。
SELECT id, name, is_class, category
FROM drh_live_camp
WHERE id = 16905;

-- 4. 说明日志里 camp_date 返回空的影响范围：只影响华彩豆展示/奖励。
SELECT *
FROM drh_live_camp_date
WHERE camp_id = 16905
LIMIT 1;
```

## 历史问题防漏分析

- 关键参数来源和赋值时机：
  - `room`：来源请求头；`LivingController#save` 调用 `getRoomInfo` 解密；下游用于设置 `campId` 和 `livingId`。
  - `campId=16905`：来源 `RoomInfoDto.liveCampId`；进入 `doSave` 前赋值；下游用于 SLS MQ 和 `isDisplayHuacaiCoinInfo`。
  - `liveId/livingId=1143726`：来源 `RoomInfoDto.liveId`；进入 `doSave` 前赋值；下游用于读取 `LiveInfo`、`LivingStudyInfo` 和发送标签。
  - `userId=189338`：来源请求体；进入 `doSave` 前赋值；下游用于读取 `LiveUser`、`LivingStudyInfo` 和发送标签。
  - `seconds=25`：来源请求体；进入 `doSave` 后参与基础校验和累计时长计算。
  - `resultSeconds=8212`：来源 `LivingStudyInfo.seconds + seconds`；当前层计算；下游用于状态计算和数据库更新。
  - `length`：来源 `LiveInfo.length`；当前层读取；为空或 0 时直接进入兼容分支。
  - `status`：来源 `LivingStudyInfo.status` 和当前层计算；只有普通更新分支会写回并触发 `finish` 标签。
- 下游读取字段清单：
  - `WorksProducerBean#doSendQwTag(Integer userId, Integer liveId, MqDayEnum mqDayEnum)` 读取 `userId/liveId/mqDayEnum`，构造 `MessageType.QW_TAG`。
  - `checkCompleteAttendHuacaiCoinAward` 读取 `livingStudyInfo.status` 和 `isDisplayHuacaiCoinInfo`，只影响华彩豆奖励，不等于企微完课标签。
- 空对象 / 占位对象风险：
  - `LiveInfo` 或 `LiveCamp` 为空会提前 return；本次日志已有后续更新 SQL，说明未在这些空对象处返回。
  - `LiveCampDate` 为空只让 `isDisplayHuacaiCoinInfo=false`，不应作为完课标签原因。
- 调用顺序风险：
  - `SLS_ASYNC` MQ 在状态计算前发送，因此日志里看到 MQ 不代表企微标签已经发送。
  - `status` 计算发生在读取 `LiveInfo.length` 后，但特殊兼容分支会绕开 `status == 2` 的标签发送逻辑。
- 旧逻辑保持：
  - `seconds < 3` 或 `seconds > 180` 过滤不变。
  - 5 秒幂等 key `DataConstants.getStudyInfoKey(liveId, userId)` 不变。
  - 直播中强制 `degree=0/sliceId=null` 的逻辑不变。
  - 销转课未到上课时间直接返回不变。
  - 已完课不重复发送完课标签的防重语义不变，除非另行设计补偿。
- 需要用户确认的设计选择：
  - 若修复 `length` 缺失时的完课判定，需要确认正式课和销转课的兜底阈值是否不同。
  - 若对 `status=2` 但企微标签缺失做补偿，需要确认以哪张表或企微外部联系人标签作为幂等依据。

## 边界情况

- `status=2`：不重复打完课标签是当前代码的预期行为；标签缺失应走补偿链路。
- `length IS NULL/0` 且 `status=1`：当前代码无法进入完课标签发送分支，即使累计观看秒数很高。
- 销转课 `is_class=0`：代码已能按 `KK_FINISH_DEFINE_V2` 计算完课分钟阈值，但 `length` 为空/0 的兼容分支先拦截了标签发送。
- 正式课 `is_class=1`：完课阈值依赖 `length * KK_FINISH_DEFINE`，`length` 缺失时无法判断是否完课。
- `drh_live_camp_date` 无记录：影响 `isDisplayHuacaiCoinInfo` 和华彩豆奖励，不影响是否发送 `MqDayEnum.finish`。
- 日志没有展示 `LivingStudyInfo.status` 和 `LiveInfo.length` 查询结果：最终原因分类必须以数据库复核为准。

## 后续建议

- 先执行复核 SQL，确认 `status`。`length` 已确认不是 0，后续排查重点改为首次 `status` 变更为 2 的请求。
- 若 `status=2`：排查 `QW_TAG` MQ、消费端、企微 `mark_tag` 结果和本地标签持久化，必要时按幂等补发完课标签。
- 若 `status=1` 且 `length IS NULL/0`：优先补齐 `drh_live.length`，再通过补偿任务重算完课状态并发 `finish` 标签。
- 如果需要改代码，建议最小改动：
  - 销转课 `is_class=0` 在 `length` 缺失时仍可使用 `KK_FINISH_DEFINE_V2` 计算完课，不应被 `length` 分支拦截。
  - 正式课 `is_class=1` 在 `length` 缺失时记录明确日志和告警，不静默跳过完课标签。
  - 对“状态已为 2 但标签未落”的情况做独立补偿，不放开 `doSave` 的重复发送。

## 需求

### 功能需求

- **FR-001**：文档 MUST 明确本次请求未进入 `status == 2` 的完课标签发送分支。
- **FR-002**：文档 MUST 说明日志中的 `drh_live_camp_date` 返回空不是完课标签缺失的直接原因。
- **FR-003**：文档 MUST 给出区分 `status=2` 防重和 `length` 缺失两类原因的数据库复核 SQL。
- **FR-004**：文档 MUST 给出后续补偿或修复建议，并明确本阶段不修改业务代码。

## 成功标准

- **SC-001**：能用日志 SQL 形态解释为什么没有发送 `MqDayEnum.finish`。
- **SC-002**：能明确下一步只需核查 `drh_living_study_info.status` 和 `drh_live.length` 即可确定最终分类。
- **SC-003**：后续修复不会误改华彩豆 `drh_live_camp_date` 查询逻辑。

## 假设

- 本地 `kkhc-idc/broadcast` 代码与日志中的 `com.drh.endpoint` 服务逻辑同源；包名和行号可能因分支或部署包不同而有差异，但日志 SQL 与本地代码分支匹配。
- 提供的日志是同一次 `requestId=c81761e7037542ec8462cec80e545199` 请求的完整关键片段。
- 未连接数据库验证 `status`，最终定性以复核 SQL 结果为准。
- 用户已补充 `length` 不是 0，因此后续排查优先按“前序请求已完课，后续请求不重复打标签”处理。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成 `LivingController#save`、`BaseController#getRoomInfo`、`LivingStudyInfoRecordServiceImpl#doSave`、`WorksProducerBean#doSendQwTag`、`LiveCampDateServiceImpl#getLiveCampDateByRedis` 的静态分析。
- 已完成用户日志与代码分支对齐：本次请求进入只更新 `seconds/degree/sliceId` 的兼容分支，没有进入完课标签发送分支。
- 本阶段未修改业务代码。

### D002 - 用户补充后的排查收敛

- 用户补充：同一用户存在多次 `livingStudyInfo save` 日志，前面请求可能已经触发完课并打标签；后续请求因 `status=2` 不再重复打标签。
- 用户补充：`drh_live.length` 已确认不是 0。
- 调整结论：后续优先查首次完课请求是否出现 `完课-打标签完成` 日志、`QW_TAG` MQ 发送日志、消费端 `AppTask` 或企微代理 `mark_tag` 日志，以及本地 OTS/企微侧标签是否实际落地。
