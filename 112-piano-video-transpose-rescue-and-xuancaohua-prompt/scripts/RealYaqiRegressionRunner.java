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
 * Real Yaqi regression runner for spec 112.
 *
 * It invokes FcOssFFmpeg-3278/VideoToNoteSeq, then evaluates the returned note
 * sequence with the Yaqi group matcher used by speakerId=113.
 */
public final class RealYaqiRegressionRunner {

    private static final String SERVICE_NAME = "FcOssFFmpeg-3278";
    private static final String FUNCTION_NAME = "VideoToNoteSeq";
    private static final double MIN_CONFIDENCE = 0.5d;
    private static final String BASE_URL = "https://drh-test.oss-cn-beijing.aliyuncs.com/video_demo3/";

    private RealYaqiRegressionRunner() {
    }

    public static void main(String[] args) throws Exception {
        Path output = args.length > 0
                ? Paths.get(args[0])
                : Paths.get("specs/112-piano-video-transpose-rescue-and-xuancaohua-prompt/out/real-yaqi-regression-results.json");
        Files.createDirectories(output.toAbsolutePath().getParent());

        RegressionCase[] cases = new RegressionCase[] {
                groupX("yaqi_D1_1", "D1"),
                groupX("yaqi_D1_2", "D1"),
                groupX("yaqi_D1_3", "D1"),
                groupX("yaqi_D1_4", "D1"),
                groupX("yaqi_D1_5", "D1"),
                groupX("yaqi_D2_1", "D2"),
                groupX("yaqi_D2_2", "D2"),
                groupX("yaqi_D3_1", "D3"),
                groupX("yaqi_D3_2", "D3"),
                groupX("yaqi_D3_3", "D3"),
                groupY("yaqi_D4_1", "D4"),
                manual("yaqi_D4_2", "D4", "D4 视频但音序组X/组Y低分接近，安全侧未匹配人工"),
                groupY("yaqi_D4_3", "D4")
        };

        JSONObject report = new JSONObject(true);
        report.put("generatedAt", OffsetDateTime.now().toString());
        report.put("serviceName", SERVICE_NAME);
        report.put("functionName", FUNCTION_NAME);
        report.put("minConfidence", MIN_CONFIDENCE);
        report.put("speakerId", 113);
        report.put("mode", "real VideoToNoteSeq call + local Yaqi group matcher; Gemini not called");
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
            event.put("task_id", "spec112-yaqi-regression-" + regressionCase.caseId);
            event.put("cacheKey", "ai:gemini:pianoVideoV2:noteSeq:spec112:yaqi:" + regressionCase.caseId
                    + ":" + System.currentTimeMillis());
            putEnvIfPresent(event, "db");
            putEnvIfPresent(event, "redis_host");
            putEnvIfPresent(event, "redis_password");

            JSONObject noteResult = caller.fetchNoteSequence(SERVICE_NAME, FUNCTION_NAME, event);
            PianoNoteSequenceFeatureExtractor.ExtractResult extractResult =
                    PianoNoteSequenceFeatureExtractor.extract(noteResult, MIN_CONFIDENCE);
            PianoNoteSequenceTemplateMatcher.YaqiMatchResult matchResult =
                    PianoNoteSequenceTemplateMatcher.matchYaqi(extractResult.pitchClasses);

            JSONObject engineeringContext = extractResult.engineeringContextJson;
            engineeringContext.put("speakerId", 113);
            engineeringContext.put("recognizedGroup", matchResult.recognizedGroupLabel());
            engineeringContext.put("recognizedTitle", matchResult.recognizedTitle());
            String submissionType = resolveYaqiSubmissionType(matchResult, regressionCase.expectedDay);
            String recognizedDay = resolveYaqiRecognizedDay(matchResult, regressionCase.expectedDay, submissionType);
            engineeringContext.put("submissionType", submissionType);
            if (!recognizedDay.isEmpty()) {
                engineeringContext.put("recognizedDay", recognizedDay);
                engineeringContext.put("recognizedId", parseDayNumber(recognizedDay));
            }
            engineeringContext.put("yaqiTemplateScores", matchResult.toJson());

            JSONObject actual = new JSONObject(true);
            actual.put("matched", matchResult.isMatched());
            actual.put("recognizedGroup", matchResult.recognizedGroupLabel());
            actual.put("recognizedTitle", matchResult.recognizedTitle());
            actual.put("recognizedDay", recognizedDay.isEmpty() ? "未知" : recognizedDay);
            actual.put("recognizedId", recognizedDay.isEmpty() ? -1 : parseDayNumber(recognizedDay));
            actual.put("submissionType", submissionType);
            actual.put("needGeminiForFinalId", matchResult.isMatched() && matchResult.recognizedDayMin() != null
                    && !matchResult.recognizedDayMin().equals(matchResult.recognizedDayMax()));
            actual.put("needHumanReview", !matchResult.isMatched());

            row.put("status", "OK");
            row.put("rawNoteCount", noteResult == null ? 0 : noteResult.getIntValue("noteCount"));
            row.put("noteSequenceText", extractResult.noteSequenceText);
            row.put("engineeringContext", engineeringContext);
            row.put("actual", actual);
            row.put("expectation", regressionCase.toJson());
            row.put("verdict", verdict(regressionCase, actual));
        } catch (Exception e) {
            row.put("status", "ERROR");
            row.put("errorClass", e.getClass().getName());
            row.put("error", e.getMessage());
        }
        row.put("elapsedMillis", System.currentTimeMillis() - started);
        return row;
    }

    private static String resolveYaqiSubmissionType(PianoNoteSequenceTemplateMatcher.YaqiMatchResult matchResult,
                                                    String expectedDay) {
        if (matchResult == null || !matchResult.isMatched()) {
            return "未知";
        }
        int expectedId = parseDayNumber(expectedDay);
        if (expectedId <= 0) {
            return "未知";
        }
        int dayMin = matchResult.recognizedDayMin();
        int dayMax = matchResult.recognizedDayMax();
        if (expectedId >= dayMin && expectedId <= dayMax) {
            return "今日作业";
        }
        return dayMax < expectedId ? "补交作业" : "提前提交";
    }

    private static String resolveYaqiRecognizedDay(PianoNoteSequenceTemplateMatcher.YaqiMatchResult matchResult,
                                                   String expectedDay,
                                                   String submissionType) {
        if (matchResult == null || !matchResult.isMatched()) {
            return "";
        }
        int dayMin = matchResult.recognizedDayMin();
        int dayMax = matchResult.recognizedDayMax();
        if (dayMin == dayMax) {
            return "D" + dayMin;
        }
        if ("今日作业".equals(submissionType)) {
            int expectedId = parseDayNumber(expectedDay);
            if (expectedId >= dayMin && expectedId <= dayMax) {
                return "D" + expectedId;
            }
        }
        return "";
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
        boolean groupPass = regressionCase.acceptedGroups.contains(actual.getString("recognizedGroup"));
        boolean titlePass = regressionCase.acceptedTitles.contains(actual.getString("recognizedTitle"));
        boolean dayPass = regressionCase.acceptedRecognizedDays.isEmpty()
                || regressionCase.acceptedRecognizedDays.contains(actual.getString("recognizedDay"));
        boolean submissionPass = regressionCase.acceptedSubmissionTypes.isEmpty()
                || regressionCase.acceptedSubmissionTypes.contains(actual.getString("submissionType"));
        verdict.put("asserted", true);
        verdict.put("groupPass", groupPass);
        verdict.put("titlePass", titlePass);
        verdict.put("dayPass", dayPass);
        verdict.put("submissionPass", submissionPass);
        verdict.put("pass", groupPass && titlePass && dayPass && submissionPass);
        return verdict;
    }

    private static RegressionCase groupX(String caseId, String expectedDay) {
        return new RegressionCase(caseId,
                BASE_URL + caseId + ".mp4",
                expectedDay,
                expectedDay + " / 组X(但愿人长久) / 今日作业",
                values("组X(但愿人长久)"),
                values("但愿人长久"),
                values(expectedDay),
                values("今日作业"));
    }

    private static RegressionCase groupY(String caseId, String expectedDay) {
        return new RegressionCase(caseId,
                BASE_URL + caseId + ".mp4",
                expectedDay,
                expectedDay + " / 组Y(沧海一声笑) / 今日作业",
                values("组Y(沧海一声笑)"),
                values("沧海一声笑"),
                values("D4"),
                values("今日作业"));
    }

    private static RegressionCase manual(String caseId, String expectedDay, String userExpected) {
        return new RegressionCase(caseId,
                BASE_URL + caseId + ".mp4",
                expectedDay,
                userExpected,
                values("未匹配"),
                values("未知"),
                values("未知"),
                values("未知"));
    }

    private static void putEnvIfPresent(JSONObject event, String name) {
        String value = System.getenv(name);
        if (value != null && !value.trim().isEmpty()) {
            event.put(name, value);
        }
    }

    private static Set<String> values(String... values) {
        return new LinkedHashSet<>(Arrays.asList(values));
    }

    private static final class RegressionCase {
        private final String caseId;
        private final String videoUrl;
        private final String expectedDay;
        private final String userExpected;
        private final Set<String> acceptedGroups;
        private final Set<String> acceptedTitles;
        private final Set<String> acceptedRecognizedDays;
        private final Set<String> acceptedSubmissionTypes;

        private RegressionCase(String caseId,
                               String videoUrl,
                               String expectedDay,
                               String userExpected,
                               Set<String> acceptedGroups,
                               Set<String> acceptedTitles,
                               Set<String> acceptedRecognizedDays,
                               Set<String> acceptedSubmissionTypes) {
            this.caseId = caseId;
            this.videoUrl = videoUrl;
            this.expectedDay = expectedDay;
            this.userExpected = userExpected;
            this.acceptedGroups = acceptedGroups;
            this.acceptedTitles = acceptedTitles;
            this.acceptedRecognizedDays = acceptedRecognizedDays;
            this.acceptedSubmissionTypes = acceptedSubmissionTypes;
        }

        private JSONObject toJson() {
            JSONObject json = new JSONObject(true);
            json.put("acceptedGroups", acceptedGroups);
            json.put("acceptedTitles", acceptedTitles);
            json.put("acceptedRecognizedDays", acceptedRecognizedDays);
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
