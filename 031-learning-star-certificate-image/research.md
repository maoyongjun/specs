# 调研记录与实现方案：学习之星奖状图片生成

**调研日期**：`2026-05-26`

## 本地代码事实

- 旧“实践之星”页面源码未在当前 workspace 中定位到。已搜索 `实践之星`、`奖状模板`、`html2canvas`、`复制截图`、`下载截图`、`toDataURL` 等关键词，未找到可直接复用的前端页面实现。
- 当前仓库已有服务端图片合成参考：`NotePicsServiceImpl` 会下载模板图，使用 `ImageIO/Graphics2D` 绘制合成图，写入临时 PNG，再上传 OSS 并返回 CDN URL。
- 当前仓库已有微信图片发送参考：`SopConfigSender` 的 `IMAGE` action 会把 `materialUrl` 放入 `SendJuziParamDto.picUrl`，`JuziUtil.sendJuzi` 最终把图片 URL 写入消息 payload 的 `url`。
- 当前仓库已有素材上传参考：`HomeworkMaterialService` 提供 OSS 上传和素材中心创建逻辑，可作为后续“生成图是否入素材中心”的实现参考。
- 姓名来源仍需后续圈选逻辑确认。现有代码能看到 `WebChatVoiceDto.contactName`、OTS 表 `drh_external_user_info.name`、配置 JSON 中的 `name_tushu`，但未定位到 `tuhsu_name` 同名字段。

## 推荐方案

采用服务端图片生成，不沿用前端截图作为主链路。

1. 增加纯渲染服务，例如 `LearningStarCertificateRenderer`。
2. 输入规范化 DTO，例如：

```java
class LearningStarCertificateRequest {
    private String realName;
    private String tuhsuName;
    private String wecomNickName;
    private LocalDate issueDate;
}
```

3. 渲染前统一生成字段：
   - `studentDisplayName`：真实姓名 > `tuhsuName` > 企微昵称；企微昵称超过 5 个字符时截断为前 5 个字符加 `...`。
   - `currentYearText`：`LocalDate.now(Asia/Shanghai)` 得到 `YYYY年`。
   - `courseName`：`开开华彩弹琴6日体验课`。
   - `honorTitle`：`学习之星`。
   - `standardDesc`：`完课情况`。
   - `issueDateText`：按 `YYYY年MM月DD日` 生成。
4. 使用 `BufferedImage` 读取底图，`Graphics2D` 开启抗锯齿，按坐标绘制文本，输出 PNG 或 JPG。
5. 生成成功后上传 OSS/CDN，返回 `imageUrl`；后续发送逻辑只消费这个 URL。
6. 发送接入时，先发送固定话术，再发送 `imageUrl` 图片消息，沿用现有 `JuziUtil` payload 结构。

## 坐标与样式建议

以下坐标仅按用户截图的目标图做排版参考，不能替代最终切图标注。假设底图约 `1484 x 1016`。

| 字段 | 建议位置 | 对齐 | 说明 |
| --- | --- | --- | --- |
| 主标题 `学习之星` | x=742, y=205 | 居中 | 如果底图已含标题则不绘制 |
| 副标题 `~开开华彩音乐学院~` | x=742, y=310 | 居中 | 如果底图已含副标题则不绘制 |
| 学员名称 | x=255, y=392 | 左对齐 | 与 `同学：` 同行 |
| `同学：` | 紧跟姓名后 | 左对齐 | 姓名长度变化时动态测宽 |
| 描述句 | x=742, y=465 | 居中 | 包含年份、课程名、标准描述 |
| 荣誉称号 | x=742, y=545 | 居中 | `“学习之星”` 较大字号红色 |
| 发证日期 | x=355, y=760 | 居中 | 日期区横线之上，格式 `YYYY年MM月DD日` |
| 落款单位 | x=1110, y=760 | 居中 | 如底图已含单位则不绘制 |
| 落款签名 | x=1110, y=835 | 居中 | 是否绘制待确认 |

字体建议随服务打包中文字体，例如思源宋体/思源黑体或产品指定字体，并在启动或渲染前注册，避免服务器缺字。

## 不推荐方案

不建议把旧页面截图逻辑作为自动化主链路。原因是前端截图依赖浏览器、字体加载、DOM 尺寸和跨域图片，批量任务中更容易出现空白图、字体漂移和环境差异。旧页面可以作为人工预览工具或坐标参考，但生成服务应在后端完成。

## 测试方案

- 姓名解析测试：真实姓名优先、`tuhsu_name` 兜底、企微昵称截断、全空兜底。
- 日期测试：使用固定 Clock，断言 `2026年` 和 `2026年05月26日`。
- 渲染测试：使用测试底图，断言输出图片尺寸、文件大小大于 0、`ImageIO.read` 可读。
- 上传测试：Mock OSS 上传，断言返回 URL 被写入生成结果。
- 发送接入测试：Mock `JuziUtil`，断言图片消息 payload 使用生成 URL。
- 回归搜索：实现后搜索确认新链路没有使用 `实践之星`、`作业情况`、`开开华彩声乐6日体验课`。

## 待确认问题

- 需要最终生产底图，最好是不含动态文字的 PNG。
- 需要确认落款签名是否已经在底图中；如果需要绘制，默认签名文字是什么。
- 日期格式已按用户需求固定为 `YYYY年MM月DD日`；如最终视觉要求空格样式，需要再确认并更新规格。
- 需要确认图片输出格式和是否必须保存到素材中心。
- 需要后续圈选逻辑提供学员姓名字段的真实来源和字段名。
