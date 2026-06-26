package com.drh.gemini.api;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Real regression runner for spec 112.
 *
 * It invokes FcOssFFmpeg-3278/VideoToNoteSeq through the same async FC + Redis
 * path used by PianoHomeWorkVideoV2Task, then evaluates the returned note
 * sequence with the local V2 engineering matcher. It intentionally does not
 * call Gemini; for high-confidence engineering matches and manual-review
 * short-circuits the final course classification is deterministic in code.
 */
public final class RealPianoRegressionRunner {

    private static final String SERVICE_NAME = "FcOssFFmpeg-3278";
    private static final String FUNCTION_NAME = "VideoToNoteSeq";
    private static final double MIN_CONFIDENCE = 0.5d;
    private static final double LOW_SCORE_MANUAL_REVIEW_THRESHOLD = 0.50d;
    private static final double OUT_OF_SCALE_RATIO_THRESHOLD = 0.30d;

    private RealPianoRegressionRunner() {
    }

    public static void main(String[] args) throws Exception {
        Path output = args.length > 0
                ? Paths.get(args[0])
                : Paths.get("specs/112-piano-video-transpose-rescue-and-xuancaohua-prompt/out/real-regression-results.json");
        Files.createDirectories(output.toAbsolutePath().getParent());

        RegressionCase[] cases = new RegressionCase[] {
                new RegressionCase("V1-1_D4", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V1-1.mp4",
                        "D4", "D1 / 补交作业", ids(1), values("四季歌"), values("补交作业")),
                new RegressionCase("V1-2_D4", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V1-2.mp4",
                        "D4", "D1 / 补交作业", ids(1), values("四季歌"), values("补交作业")),
                new RegressionCase("V2-1_D4", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V2-1.mp4",
                        "D4", "未指定明确期望；仅记录实际工程侧结果", ids(), values(), values()),
                new RegressionCase("V3-1_D4", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V3-1.mp4",
                        "D4", "D3 或 D4 / 沧海一声笑", ids(3, 4), values("沧海一声笑"), values("今日作业", "补交作业")),
                new RegressionCase("V5-1_D4", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V5-1.mp4",
                        "D4", "D5 / 提前提交（未来作业）", ids(5), values("萱草花"), values("提前提交")),
                new RegressionCase("V5-1_D2", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V5-1.mp4",
                        "D2", "D5 / 提前提交", ids(5), values("萱草花"), values("提前提交")),
                new RegressionCase("V1-1_D2", "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo/V1-1.mp4",
                        "D2", "D1 / 补交作业", ids(1), values("四季歌"), values("补交作业")),
                new RegressionCase("a8bdb7b2_D4", "https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_fb19fed680d94327b9e47831834dc17e/link_msg/19b8e245-7478-4102-8ef9-a5950b827bd9/a8bdb7b2-828b-448b-b21a-e86aa4792c1f.mp4",
                        "D4", "id=-1", ids(-1), values("未知"), values("未知")),
                new RegressionCase("ec62a262_D4", "https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_950f035ddfe848bb955395f7f37dd813/link_msg/2165eee8-c654-42b6-9266-20169e43a4a2/ec62a262-1162-450d-a544-42988134f7a3.mp4",
                        "D4", "id=-1", ids(-1), values("未知"), values("未知")),
                new RegressionCase("e57f1dda_D4", "https://kkhc.tos-cn-beijing.volces.com/mh/puppet_workmate_fb19fed680d94327b9e47831834dc17e/link_msg/fe73816b-a9fa-4443-85c6-daf802cf999e/e57f1dda-661b-4596-a6b3-3d14fbf6a327.mp4",
                        "D4", "沧海一声笑 或 id=-1", ids(-1, 3, 4), values("未知", "沧海一声笑"), values("未知", "今日作业", "补交作业"))
        };

        JSONObject report = new JSONObject(true);
        report.put("generatedAt", OffsetDateTime.now().toString());
        report.put("serviceName", SERVICE_NAME);
        report.put("functionName", FUNCTION_NAME);
        report.put("minConfidence", MIN_CONFIDENCE);
        report.put("mode", "real VideoToNoteSeq call + local V2 engineering decision; Gemini not called");
        JSONArray rows = new JSONArray();
        report.put("cases", rows);

        PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller caller =
                new PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller(new ProcessEnvironment());
        for (RegressionCase regressionCase : cases) {
            JSONObject row = runOne(regressionCase, caller);
            rows.add(row);
            Files.write(output, JSON.toJSONString(report, true).getBytes(StandardCharsets.UTF_8));
            System.out.println(row.toJSONString());
        }
    }

    private static JSONObject runOne(RegressionCase regressionCase,
                                     PianoHomeWorkVideoV2Task.DefaultNoteSequenceCaller caller) {
        long started = System.currentTimeMillis();
        JSONObject row = new JSONObject(true);
        row.put("caseId", regressionCase.caseId);
        row.put("videoUrl", regressionCase.videoUrl);
        row.put("expectedDay", regressionCase.expectedDay);
        row.put("userExpected", regressionCase.userExpected);
        try {
            JSONObject event = new JSONObject(true);
            event.put("video_path", regressionCase.videoUrl);
            event.put("task_id", "spec112-real-regression-" + regressionCase.caseId);
            event.put("cacheKey", "ai:gemini:pianoVideoV2:noteSeq:spec112:" + regressionCase.caseId
                    + ":" + System.currentTimeMillis());
            putEnvIfPresent(event, "db");
            putEnvIfPresent(event, "redis_host");
            putEnvIfPresent(event, "redis_password");

            JSONObject noteResult = caller.fetchNoteSequence(SERVICE_NAME, FUNCTION_NAME, event);
            PianoNoteSequenceFeatureExtractor.ExtractResult extractResult =
                    PianoNoteSequenceFeatureExtractor.extract(noteResult, MIN_CONFIDENCE);
            PianoNoteSequenceTemplateMatcher.MatchResult matchResult =
                    PianoNoteSequenceTemplateMatcher.match(
                            extractResult.pitchClasses,
                            extractResult.engineeringContextJson.getBooleanValue("isMonoDescending"));

            JSONObject engineeringContext = extractResult.engineeringContextJson;
            engineeringContext.put("templateScores", matchResult.toTemplateScoresJson());
            JSONObject engineeringDecision = buildEngineeringDecision(matchResult, regressionCase.expectedDay);
            if (engineeringDecision != null) {
                engineeringContext.put("engineeringDecision", engineeringDecision);
            }

            JSONObject actual = decide(extractResult, matchResult, regressionCase.expectedDay);
            JSONObject expectation = regressionCase.toJson();
            JSONObject verdict = verdict(regressionCase, actual);

            row.put("status", "OK");
            row.put("rawNoteCount", noteResult == null ? 0 : noteResult.getIntValue("noteCount"));
            row.put("noteSequenceText", extractResult.noteSequenceText);
            row.put("engineeringContext", engineeringContext);
            row.put("actual", actual);
            row.put("expectation", expectation);
            row.put("verdict", verdict);
        } catch (Exception e) {
            row.put("status", "ERROR");
            row.put("errorClass", e.getClass().getName());
            row.put("error", e.getMessage());
        }
        row.put("elapsedMillis", System.currentTimeMillis() - started);
        return row;
    }

    private static JSONObject decide(PianoNoteSequenceFeatureExtractor.ExtractResult extractResult,
                                     PianoNoteSequenceTemplateMatcher.MatchResult matchResult,
                                     String expectedDay) {
        JSONObject actual = new JSONObject(true);
        int validNoteCount = extractResult.engineeringContextJson.getIntValue("validNoteCount");
        if (validNoteCount < 5) {
            return manual(actual, "INSUFFICIENT_NOTES", "有效音符不足");
        }
        if (matchResult.bestScore.score < LOW_SCORE_MANUAL_REVIEW_THRESHOLD) {
            return manual(actual, "LOW_SCORE_MANUAL_REVIEW", "工程侧曲目模板分数低");
        }
        if (isFakeHighConfidenceD2(matchResult)) {
            return manual(actual, "FAKE_HIGH_CONFIDENCE_D2", "D2覆盖满但连续短语极低");
        }
        if (!matchResult.highConfidence
                && extractResult.engineeringContextJson.getDoubleValue("outOfScaleRatio") >= OUT_OF_SCALE_RATIO_THRESHOLD) {
            return manual(actual, "OUT_OF_SCALE_MANUAL_REVIEW", "课程外音级占比高且工程侧非高置信");
        }
        if (!matchResult.highConfidence) {
            int candidateId = resolveTemplateDayId(matchResult.bestTemplate, expectedDay);
            actual.put("resultType", "NEEDS_GEMINI");
            actual.put("isHomeWork", "未知");
            actual.put("id", candidateId);
            actual.put("title", matchResult.bestTemplate.title);
            actual.put("recognizedDay", "D" + candidateId);
            actual.put("submissionType", resolveTemplateSubmissionType(matchResult.bestTemplate, expectedDay));
            actual.put("needHumanReview", true);
            actual.put("confidence", matchResult.decisionConfidence());
            return actual;
        }
        int recognizedId = resolveTemplateDayId(matchResult.bestTemplate, expectedDay);
        actual.put("resultType", "ENGINEERING_HIGH_CONFIDENCE");
        actual.put("isHomeWork", "是");
        actual.put("id", recognizedId);
        actual.put("title", matchResult.bestTemplate.title);
        actual.put("recognizedDay", "D" + recognizedId);
        actual.put("submissionType", resolveTemplateSubmissionType(matchResult.bestTemplate, expectedDay));
        actual.put("needHumanReview", false);
        actual.put("confidence", matchResult.decisionConfidence());
        return actual;
    }

    private static JSONObject manual(JSONObject actual, String resultType, String reason) {
        actual.put("resultType", resultType);
        actual.put("isHomeWork", "否");
        actual.put("id", -1);
        actual.put("title", "未知");
        actual.put("recognizedDay", "未知");
        actual.put("submissionType", "未知");
        actual.put("needHumanReview", true);
        actual.put("confidence", 0.3d);
        actual.put("reason", reason);
        return actual;
    }

    private static JSONObject buildEngineeringDecision(PianoNoteSequenceTemplateMatcher.MatchResult matchResult,
                                                       String expectedDay) {
        JSONObject decision = matchResult.toEngineeringDecisionJson();
        if (decision == null) {
            return null;
        }
        int recognizedId = resolveTemplateDayId(matchResult.bestTemplate, expectedDay);
        decision.put("recognizedDay", "D" + recognizedId);
        decision.put("id", recognizedId);
        decision.put("submissionType", resolveTemplateSubmissionType(matchResult.bestTemplate, expectedDay));
        decision.put("templateDay", matchResult.bestTemplate.day);
        return decision;
    }

    private static boolean isFakeHighConfidenceD2(PianoNoteSequenceTemplateMatcher.MatchResult matchResult) {
        return matchResult.highConfidence
                && "D2".equals(matchResult.bestTemplate.day)
                && !matchResult.endingRepeatedE
                && matchResult.d2Score.coverage >= 0.95d
                && matchResult.d2Score.contiguousPhraseSimilarity < 0.12d;
    }

    private static int resolveTemplateDayId(PianoNoteSequenceTemplateMatcher.Template template, String expectedDay) {
        int expectedId = parseDayNumber(expectedDay);
        if (expectedId <= 0) {
            return template.id;
        }
        if (expectedId >= template.dayMin && expectedId <= template.dayMax) {
            return expectedId;
        }
        if (template.dayMax < expectedId) {
            return template.dayMax;
        }
        return template.dayMin;
    }

    private static String resolveTemplateSubmissionType(PianoNoteSequenceTemplateMatcher.Template template,
                                                        String expectedDay) {
        int expectedId = parseDayNumber(expectedDay);
        if (expectedId <= 0) {
            return "未知";
        }
        if (expectedId >= template.dayMin && expectedId <= template.dayMax) {
            return "今日作业";
        }
        return template.dayMax < expectedId ? "补交作业" : "提前提交";
    }

    private static int parseDayNumber(String day) {
        if (day == null || day.trim().isEmpty()) {
            return -1;
        }
        String normalized = day.trim().toUpperCase();
        if (normalized.startsWith("D")) {
            normalized = normalized.substring(1);
        }
        try {
            return Integer.parseInt(normalized);
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    private static JSONObject verdict(RegressionCase regressionCase, JSONObject actual) {
        JSONObject verdict = new JSONObject(true);
        int actualId = actual.getIntValue("id");
        String actualTitle = actual.getString("title");
        String actualSubmissionType = actual.getString("submissionType");
        boolean asserted = !regressionCase.acceptedIds.isEmpty();
        boolean idPass = !asserted || regressionCase.acceptedIds.contains(actualId);
        boolean titlePass = regressionCase.acceptedTitles.isEmpty()
                || regressionCase.acceptedTitles.contains(actualTitle);
        boolean submissionPass = regressionCase.acceptedSubmissionTypes.isEmpty()
                || regressionCase.acceptedSubmissionTypes.contains(actualSubmissionType);
        verdict.put("asserted", asserted);
        verdict.put("idPass", idPass);
        verdict.put("titlePass", titlePass);
        verdict.put("submissionPass", submissionPass);
        verdict.put("pass", idPass && titlePass && submissionPass);
        if (!asserted) {
            verdict.put("note", "用户未给明确期望，本条仅记录真实调用结果。");
        }
        if ("NEEDS_GEMINI".equals(actual.getString("resultType"))) {
            verdict.put("note", "工程侧未高置信，真实 V2 最终结果还依赖 Gemini；本条只给工程候选。");
        }
        return verdict;
    }

    private static void putEnvIfPresent(JSONObject event, String name) {
        String value = System.getenv(name);
        if (value != null && !value.trim().isEmpty()) {
            event.put(name, value);
        }
    }

    private static Set<Integer> ids(Integer... ids) {
        return new LinkedHashSet<>(Arrays.asList(ids));
    }

    private static Set<String> values(String... values) {
        return new LinkedHashSet<>(Arrays.asList(values));
    }

    private static final class RegressionCase {
        private final String caseId;
        private final String videoUrl;
        private final String expectedDay;
        private final String userExpected;
        private final Set<Integer> acceptedIds;
        private final Set<String> acceptedTitles;
        private final Set<String> acceptedSubmissionTypes;

        private RegressionCase(String caseId,
                               String videoUrl,
                               String expectedDay,
                               String userExpected,
                               Set<Integer> acceptedIds,
                               Set<String> acceptedTitles,
                               Set<String> acceptedSubmissionTypes) {
            this.caseId = caseId;
            this.videoUrl = videoUrl;
            this.expectedDay = expectedDay;
            this.userExpected = userExpected;
            this.acceptedIds = acceptedIds;
            this.acceptedTitles = acceptedTitles;
            this.acceptedSubmissionTypes = acceptedSubmissionTypes;
        }

        private JSONObject toJson() {
            JSONObject json = new JSONObject(true);
            json.put("acceptedIds", acceptedIds);
            json.put("acceptedTitles", acceptedTitles);
            json.put("acceptedSubmissionTypes", acceptedSubmissionTypes);
            return json;
        }
    }

    private static final class ProcessEnvironment implements PianoHomeWorkVideoV2Task.Environment {
        @Override
        public String getenv(String name) {
            return System.getenv(name);
        }
    }
}
