# 规格执行说明

本目录用于“学习之星奖状图片生成”的 Spec Kit 文档。当前目标是先确定图片生成方式，暂不实现圈选学员和微信发送编排。

## 作用范围

- 规格文档：`C:\workspace\ju-chat\specs\031-learning-star-certificate-image`
- 目标 workspace：`C:\workspace\ju-chat`
- 候选实现模块：
  - 图片生成服务优先参考 `C:\workspace\ju-chat\kkhc\kkhc-idc\lms`
  - 后续发送接入参考 `C:\workspace\ju-chat\fc\sop-reply`
  - 管理端素材上传参考 `C:\workspace\ju-chat\data-RC\juzi-service`

## 当前目标

- 明确学习之星奖状图片生成的动态字段、固定文案和边界。
- 调研现有图片合成、OSS 上传和微信图片发送链路。
- 给出可落地的服务端生成方案，等待最终底图和坐标确认后再实现。

## 执行原则

- 图片生成优先采用服务端 `ImageIO/Graphics2D`，避免依赖人工页面截图。
- 字段必须先解析、校验、格式化，再进入渲染；不能用空对象或占位 URL 下传。
- 固定文案必须使用本需求口径：`学习之星`、`完课情况`、`开开华彩弹琴6日体验课`。
- 日期必须使用 `Asia/Shanghai` 时区，避免服务器默认时区导致日期错位。
- 中文字体必须显式确认；生产环境缺字时不能生成乱码或方块字图片。
- 后续接入发送时，必须保持既有 `JuziUtil.sendJuzi` 图片消息 payload 结构不变。

## 强制门禁

- 最终底图、尺寸、坐标、字体、颜色、签名口径未确认前，不进入业务代码实现。
- 生成图片失败时不得继续发送图片消息。
- 任何新增接口、数据库表、MQ 字段、Redis key、素材中心调用或批量任务策略，都必须先补充规格和测试映射。
- 不允许把旧 `实践之星`、`作业情况`、`开开华彩声乐6日体验课` 文案带入新生成链路。

## 重点代码位置

- 服务端图片合成参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\lms\src\main\java\com\kkhc\idc\lms\service\works\impl\NotePicsServiceImpl.java`
- 通用图片工具参考：`C:\workspace\ju-chat\kkhc\kkhc-idc\base-common\src\main\java\com\kkhc\common\utils\ImageUtil.java`
- 微信图片发送参考：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\sop\SopConfigSender.java`
- 发送 payload 组装参考：`C:\workspace\ju-chat\fc\sop-reply\src\main\java\com\drh\homework\util\JuziUtil.java`
- 素材/OSS 上传参考：`C:\workspace\ju-chat\data-RC\juzi-service\src\main\java\com\drh\data\juzi\homeworkconfig\service\HomeworkMaterialService.java`

## 文档维护

- `spec.md` 描述需求、边界、字段来源、验收标准和待确认问题。
- `tasks.md` 记录事实确认、风险门禁、实现任务和测试任务。
- `research.md` 记录调研结论和推荐实现方案。
- `checklists\requirements.md` 用于确认实施前置条件。
- 用户补充底图、签名、发送示例或圈选逻辑后，需要追加 Dxxx 纠正记录并同步更新相关文档。
