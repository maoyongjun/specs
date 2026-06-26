package com.drh.gemini.api;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class YaqiScoreProbe {
    public static void main(String[] args) throws Exception {
        Map<String, String> seqs = new LinkedHashMap<>();
        seqs.put("D2_1", "C4 G3 C4 C4 C4 B3 C4 C4 G3 G3 D4 C#4 D4 G3 A#3 C4 E4 E4 C3 D4 D4 D4 E4 F4 E4 F4 E4 F4 B3 D5 D4 D4 G3 C4 C4 C4 C4 G3 C4 C4 F3 C5 C4 G3 D5 D5 G3 C4 D5 E4 C3 E4 C3 D4 F4 E4 F4 E4 D#4 B3 D4 G3 D4 D4 D4 G3 B3 B4 C4 F3 C4");
        seqs.put("D3_1", "C3 A2 A3 C5 C3 A3 C5");
        seqs.put("D3_3", "C4 F2 D2 C2 B3 C2 C2 A4 B4 B4 A4 B4 B4");
        seqs.put("D4_2", "C3 C3 E3 C2 G5 E5 D5 C5 C4 E3 E3 E3 D#3 E3 C5 E3 C3 D2 C5 A4 E3 A3 G3 E3 A4 G3 A4 C5 D5 E5 G5 G4 E3 G4 F#4 G4 A5 D3 C3 C3 G3 C3 E5 D5 C5 C5 F3 F3 E3 C3 G4 E5 D5 C5 C5 F#3 E3 E3 C5 E4 D4 E2 C3 D2 A3 C3 G3 G3 F#3 G3 F#3 C3 A4 G3 E3 A4 C5 D5 E5 G#4 F#4 G#4 G4 F#3 F3 F3 F3 E3 F3 D3 D3 D4 D3 G4 D3 E5 D5 C5 C4 C5");
        seqs.put("D007_bad", "C2 C3 G3 D5 C4 C3 F2 F2 A3 G4 C2 C2 G3");
        seqs.put("low_close", "F4 F4 D4 C3 D4 F4 F4 F4 D4 C3 D3 G3 A3 F4 D4 A3 F4 D4 G3 F4 D4 G3 A3 A3 D4 E4 F4 G3 G3 C3 E3 D4 E4 F4");

        for (Map.Entry<String, String> entry : seqs.entrySet()) {
            List<Integer> pitchClasses = pitchClasses(entry.getValue());
            PianoNoteSequenceTemplateMatcher.YaqiMatchResult result =
                    PianoNoteSequenceTemplateMatcher.matchYaqi(pitchClasses);
            System.out.println("== " + entry.getKey() + " == " + result.recognizedGroupLabel());
            printScore("X", scoreField(result, "groupXScore"));
            printScore("Y", scoreField(result, "groupYScore"));
        }
    }

    private static List<Integer> pitchClasses(String text) {
        List<Integer> result = new ArrayList<>();
        for (String noteName : text.trim().split("\\s+")) {
            Integer pitchClass = PianoNoteSequenceFeatureExtractor.pitchClassOf(noteName);
            if (pitchClass != null) {
                result.add(pitchClass);
            }
        }
        return result;
    }

    private static PianoNoteSequenceTemplateMatcher.Score scoreField(
            PianoNoteSequenceTemplateMatcher.YaqiMatchResult result, String fieldName) throws Exception {
        Field field = PianoNoteSequenceTemplateMatcher.YaqiMatchResult.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        return (PianoNoteSequenceTemplateMatcher.Score) field.get(result);
    }

    private static void printScore(String label, PianoNoteSequenceTemplateMatcher.Score score) {
        System.out.println(label
                + " lcs=" + score.lcsLength
                + " coverage=" + score.coverage
                + " histogram=" + score.histogramSimilarity
                + " prefix=" + score.prefixSimilarity
                + " contiguous=" + score.contiguousPhraseSimilarity
                + " score=" + score.score);
    }
}
