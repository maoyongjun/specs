# 规格执行说明

本目录记录雅琪钢琴作业点评配置同步、创建和验证过程。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\108-yaqi-piano-homework-config`
- 目标项目：`C:\workspace\ju-chat\data-RC\juzi-service`
- 运行时匹配模块：`C:\workspace\ju-chat\fc\sop-reply`
- 素材目录：`C:\workspace\homework_yaqi`

## 当前目标

- 备份测试环境作业点评三表。
- 将正式环境三表全量同步到测试环境。
- 将原钢琴 route 归属到李瑶 `speakerId=110`。
- 为雅琪 `speakerId=113` 新增 D1-D4 第 1 次作业点评配置。

## 执行原则

- 生产库只读，不执行任何写操作。
- 测试库写入必须先跑 `database-sql-skill` 的 SQL 分析。
- 只操作 `drh_ai_config_homework_strategy`、`drh_ai_config_homework_action`、`drh_ai_config_homework_route`。
- 不修改代码、不新增接口、不新增表结构。
- 测试接口统一使用 `https://test-api.opensplendid.cn/juzi-service`。

## 重点代码位置

- `HomeworkConfigAdminController`：admin 配置接口。
- `HomeworkConfigService`：strategy/action/route 写入和查询逻辑。
- `SopConfigSender`：运行时 route/action 多条件匹配。
- `SopHomeWorkHandleService`：识别结果 `question1~question4` 拼接为 `question`。

## 数据与接口约束

- `skuId=4` 表示钢琴。
- 李瑶 `speakerId=110`，雅琪 `speakerId=113`。
- 原钢琴 route 的 strategy/action 保持不变，只更新 route 条件。
- 雅琪 route 使用 `currentDay&&homeworkDayRelation&&speakerId`。
- D1 子目录名就是 `conditionValue`：`节奏有问题`、`翘指`、`折指`。
- `.mp3` 上传为 `VOICE`，`.png/.jpg` 上传为 `IMAGE`，普通 `.txt` 读取为 `TEXT`，`*_Vxx.txt` 建为 `VIDEO_CHANNEL`。

## 文档维护

- SQL、脚本、备份说明和验证摘要都保存在本目录。
- 每次实际写库或接口创建后，更新 `spec.md` 与 `tasks.md` 的执行记录。
