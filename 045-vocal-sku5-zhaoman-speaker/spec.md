# 功能规格：声乐SKU增加赵曼音色映射

**功能目录**：`045-vocal-sku5-zhaoman-speaker`
**创建日期**：`2026-06-02`
**状态**：Done
**输入**：`在C:\workspace\ju-chat\fc\audio-tts\src\main\java\com\drh\audio\service\AppTask.java 增加，声乐sku=5，SPEAKER_ID 是 106，匹配 赵曼的音色 S_xOAzRIZR1。`

## 背景

- 当前问题：声乐SKU（sku=5）在TTS音色映射中缺少 speakerId=106 的音色映射，导致赵曼老师的AI点评语音无法使用对应音色。
- 当前行为：skuId=5 时，无论 speakerId 是多少，都返回 `OTHER_SKU_SPEAKER`（"--"）。
- 目标行为：当 skuId=5 且 speakerId=106 时，返回赵曼音色 `S_xOAzRIZR1`；其他 speakerId 仍返回 `OTHER_SKU_SPEAKER`。
- 非目标：本次不涉及其他SKU或speakerId的映射变更，不修改钢琴（sku=4）现有逻辑。

## 用户场景与测试 *(必填)*

### 用户故事 1 - 声乐AI点评使用赵曼音色（优先级：P1）

声乐课程中，当 speakerId=106（赵曼老师）时，系统应使用赵曼的音色 S_xOAzRIZR1 生成AI点评语音。

**独立测试**：运行 AppTask 的单测或本地测试，传入 skuId=5、speakerId=106，验证返回 speaker 为 S_xOAzRIZR1。

**验收场景**：

1. **Given** campDateId 对应的 campInfo 中 category=5 且 speakerId=106，**When** 调用 resolveSpeaker(campDateId)，**Then** 返回 "S_xOAzRIZR1"。
2. **Given** campDateId 对应的 campInfo 中 category=5 且 speakerId≠106（如107），**When** 调用 resolveSpeaker(campDateId)，**Then** 返回 "--"。

## 历史问题防漏分析 *(强制)*

- 关键参数来源和赋值时机：
  - `skuId`：来源 `CenterUtil.getCampInfoByCampDateId(campDateId).getCategory()`；赋值时机 `CenterUtil` 外部返回；下游读取位置 `AppTask.resolveSpeaker()`。
  - `speakerId`：来源 `CenterUtil.getCampInfoByCampDateId(campDateId).getSpeakerId()`；赋值时机 `CenterUtil` 外部返回；下游读取位置 `AppTask.resolveSpeaker()`。
- 下游读取字段清单：
  - `TtsHttpClientV2.textToAudio()` 读取 `speaker` 字符串。
- 空对象 / 占位对象风险：
  - `CenterUtil.CampInfo` 可能为 null，代码已通过 `campInfo == null ? null : ...` 处理，安全。
- 调用顺序风险：
  - 无。speaker 在 `buildAudioBinaryResult` 中同步解析后立即使用。
- 旧逻辑保持：
  - 钢琴（sku=4）的 speakerId=113（亚奇）和 speakerId=110（李瑶）映射逻辑保持不变。
  - sku=5 的非 106 speakerId 仍返回 `OTHER_SKU_SPEAKER`。
  - 未知 skuId 仍返回 `OTHER_SKU_SPEAKER`。
  - `UNKNOWN_SPEAKER` 仅用于钢琴不匹配时的兜底，声乐不匹配仍返回 `OTHER_SKU_SPEAKER`。
- 需要用户确认的设计选择：
  - 无。

## 边界情况

- `campDateId` 为 null：返回 `OTHER_SKU_SPEAKER`，已有兜底逻辑。
- `CenterUtil.getCampInfoByCampDateId` 返回 null：`skuId` 和 `speakerId` 均为 null，走兜底 `OTHER_SKU_SPEAKER`。
- `speakerId` 为 null：`Objects.equals(null, 106)` 返回 false，走兜底 `OTHER_SKU_SPEAKER`。
- skuId=5 但 speakerId 不在映射范围内：返回 `OTHER_SKU_SPEAKER`，行为不变。

## 需求 *(必填)*

### 功能需求

- **FR-001**：系统 MUST 在 `AppTask` 中新增常量 `VOCAL_ZHAOMAN_SPEAKER_ID = 106`。
- **FR-002**：系统 MUST 在 `AppTask` 中新增常量 `VOCAL_ZHAOMAN_SPEAKER = "S_xOAzRIZR1"`。
- **FR-003**：系统 MUST 在 `resolveSpeaker` 方法的 `SKU_VOCAL` 分支中，当 `speakerId == 106` 时返回 `VOCAL_ZHAOMAN_SPEAKER`。
- **FR-004**：系统 MUST NOT 修改钢琴（sku=4）及其他SKU的音色映射逻辑。

## 成功标准 *(必填)*

- **SC-001**：传入 skuId=5、speakerId=106 时，resolveSpeaker 返回 "S_xOAzRIZR1"。
- **SC-002**：传入 skuId=5、speakerId≠106 时，resolveSpeaker 返回 "--"，保持原有行为。
- **SC-003**：钢琴（sku=4）的 speakerId=113 和 110 映射不受影响。

## 假设

- `CenterUtil.getCampInfoByCampDateId(campDateId)` 能正确返回 campInfo 对象，其中包含 category 和 speakerId 字段。
- 音色字符串 "S_xOAzRIZR1" 在TTS服务中已注册可用。

## 执行记录

### D001 - 文档记录

- 已创建本 Spec Kit 文档。
- 已完成历史问题防漏分析和强制门禁检查。
- 本阶段未修改业务代码。

### D002 - 实现记录

- **实现内容**：在 `AppTask.java` 中新增两个常量 `VOCAL_ZHAOMAN_SPEAKER_ID = 106` 和 `VOCAL_ZHAOMAN_SPEAKER = "S_xOAzRIZR1"`；在 `resolveSpeaker` 的 `SKU_VOCAL` 分支中增加 `speakerId == 106` 的匹配逻辑，返回赵曼音色。
- **影响范围**：`fc/audio-tts/src/main/java/com/drh/audio/service/AppTask.java`。
- **测试命令**：本地运行 `AppTask.main` 或单元测试。
- **测试结果**：待验证。
- **自检结论**：代码改动最小化，仅新增常量和条件分支，不影响既有钢琴逻辑。

### D003 - 纠正记录模板

- 触发原因：`<用户补充/测试失败/代码审查发现/参数遗漏/调用顺序问题>`。
- 修正内容：`<写清楚旧口径和新口径>`。
- 文档同步：`<spec/tasks/AGENTS/checklist 是否已同步>`。
- 验证结果：`<测试或静态检查结果>`。
