-- drh_history_pic union_id 备份 SQL（2026-06-02 第二批 92 个 union_id）
-- 目标：将本批 union_id 在“胡琴说（上）”课程、class_id=1124820 下对应作业的人工点评记录 union_id 改为 {union_id}_bak。
-- 注意：仓库内默认 ROLLBACK；本批已按用户确认将执行脚本末尾改为 COMMIT 并提交。
-- 重复执行时，由于原始 union_id 已改为 _bak，目标临时表将不再命中这 92 条记录。

SET NAMES utf8mb4;

START TRANSACTION;

DROP TEMPORARY TABLE IF EXISTS tmp_drh_history_pic_unionid_bak_target;

CREATE TEMPORARY TABLE tmp_drh_history_pic_unionid_bak_target AS
SELECT DISTINCT
    hp.id,
    hp.pic_id,
    wp.live_id AS class_id,
    hp.union_id AS source_union_id,
    CONCAT(hp.union_id, '_bak') AS target_union_id,
    l.name AS live_name
FROM drh_history_pic hp
JOIN drh_works_pic wp
    ON wp.id = hp.pic_id
   AND wp.union_id = hp.union_id
JOIN drh_live l
    ON l.id = wp.live_id
WHERE hp.union_id IN (
    'oNGxt5yrQwK1fKXWmrFcXGTApOsQ',
    'oNGxt5w-vRHioA6eaivlcikVztmk',
    'oNGxt529IINkdPX4hvdYApvbib-o',
    'oNGxt5_lwzGdFV34IW5y1WRXyJ-M',
    'oNGxt58yyTEzXpsOUmQgB4Mhm6sc',
    'oNGxt575zANqLDcge7G-7UEHXmrI',
    'oNGxt57hKl7oNsf899EsaKUY0Gc4',
    'oNGxt52Knkrc-9qWYcDjb1Wz4bIE',
    'oNGxt55uzNArGSMh_jVNA6zX2N3c',
    'oNGxt5xgz82nyeVr2EW9h-3-xvso',
    'oNGxt57GfsNxUWX6jzFppl-O733Y',
    'oNGxt53xwV_wiEKPPtHjQtoIhaBk',
    'oNGxt5wE6nYC40jn32wRZ3MceYrc',
    'oNGxt5-ii3uWraP-9LKUyX8-qhzc',
    'oNGxt5-C7AhXfMPcGTbnGrVcGK3c',
    'oNGxt55KjSzPvbFiZRdYfGw-Mybg',
    'oNGxt56TB_uOPm78R7KQKlHbkmCs',
    'oNGxt5ybgWjqXs6XCVJkwDwhZhn8',
    'oNGxt5xZZxuuPENMWOek3m_CxoCo',
    'oNGxt5wtelQGBj_Tp1yOKPkp5-fY',
    'oNGxt58AHky5VKvNE70e2Mzj0orw',
    'oNGxt5_3lGYIRnRMOuBZYRJNPFbc',
    'oNGxt57TnHmrmgaiclhDbZ0bGnK4',
    'oNGxt59qieLoKhiJ3eKRMx8ULXp4',
    'oNGxt5-KtaL3VPUjO64lJRoj1mK0',
    'oNGxt55ZrdgWl3o3QWa77x9nL1eU',
    'oNGxt53s-D0x1TcoiB3ihj2LuhV0',
    'oNGxt56_DMhHbRX6Uu0GNGEiXPzw',
    'oNGxt57Sk8CJ_XtdJTPgAg8FnpfY',
    'oNGxt51JYwnQfNsfiHm8fa0JNQgo',
    'oNGxt5x6YOdiClwx1QczjJGQRcBI',
    'oNGxt5_l6wYvzDpnKgQxaNjo8HrE',
    'oNGxt5-FSKMwAnVScjwEKtIIA7Hc',
    'oNGxt5_w7Mb373DpWC0vIP9APiR4',
    'oNGxt53M0caQ4F9KdHTZ1vBdZFN8',
    'oNGxt5zcRpbw_TPs8_gV-KtKMgrk',
    'oNGxt56f3WF4juVk20uQgoI5aB8s',
    'oNGxt55bxohlrT_BVQygFohceXhA',
    'oNGxt56aptoTtCTKJ420CBALLPLM',
    'oNGxt54TqwMn5vCU4Unu40WlVO8A',
    'oNGxt50dRFhS0KurajaC9g8O4GX8',
    'oNGxt5xFQxvAqguzgQXFtn4-hOJA',
    'oNGxt588mOk3jGUUqdcniRDWOnpM',
    'oNGxt5_XwnNDqX1Ac6HCM3rTHskI',
    'oNGxt5wh7ORCjwKReBfQjSuHAz_E',
    'oNGxt53APz8O4kdRucqp0fGszOs0',
    'oNGxt5z7d_P8MEOHSq6FzufRfCXU',
    'oNGxt5zyPQxVf1dmFlpvB2ZcXK9E',
    'oNGxt52ebzmNYBOpBD_PldqykOPg',
    'oNGxt5xvKQ8ViNEeRxyc_n_nYxf8',
    'oNGxt515mYY4WRZw1J-Q9UQ2vbwI',
    'oNGxt51ZxO3H0KSJt5JsZ5cv5HiQ',
    'oNGxt54002NpgkKPb6mc00x7NMsc',
    'oNGxt57W-tH0009kuC5AeWVOPGl0',
    'oNGxt52cr_PMPAeIkizAvdDJ-V9U',
    'oNGxt52j7Aw_OlTwT_LYLNtDbXog',
    'oNGxt5_WMm_4RimHJSKDcmRFmHFY',
    'oNGxt59o5PyMqhL5KT0rykM_OwB4',
    'oNGxt59TFnAyPMngHoxPaCe4XktM',
    'oNGxt5_DEH3-8Z3Ad0uIr8vDjFaw',
    'oNGxt5yt7CcxaVfxyOd3jHi1tro0',
    'oNGxt50Ste93L97lmBvHxGD9Dg9Q',
    'oNGxt5-9f2r_clZ48GY49yqqm2jM',
    'oNGxt56kZWOeeow2H3u8EM5zN8IM',
    'oNGxt57088VcrZjEgkkCvdrQTof4',
    'oNGxt54kCzh5o7nmJueJY86moYjA',
    'oNGxt59fy7x4uhbsQnIGNFJMAmYc',
    'oNGxt5y-6d7tgK-3gOkVTtzY7mno',
    'oNGxt5zbXFRrnDBvvsp8iy-XIrlo',
    'oNGxt56BCGYrDDJlduHyCHQsu40o',
    'oNGxt57DxcQhW7zo44DtvEmy-8AI',
    'oNGxt58XajifUSuAhgmKn-tWn11c',
    'oNGxt5_kgWg8HvQ2nyrRu9W1UwVc',
    'oNGxt5-WBZ6KJ1WeM4iAG6178UWo',
    'oNGxt56VPGtzJW9iDi5e2ZeJQUD0',
    'oNGxt5x1cjE8ZofUtGbnaeDjTcLQ',
    'oNGxt5_hIlHVzifnA1uu5mToM6ng',
    'oNGxt54j2-8hQDU4AD4EY1RaITDA',
    'oNGxt53xbYF1geqvTeKlyuoXZQ-4',
    'oNGxt5-caadH7JaDbspB7Ni6o3u4',
    'oNGxt5_5zznYMBMZXAYmDebT4Mh0',
    'oNGxt5zFz6e2wUsMYHLshghT5ilk',
    'oNGxt5-OG9Nqyyw9QEJRo1Bu2vGQ',
    'oNGxt57-9mBbecIK957bCEomLm3E',
    'oNGxt59lC0W3uxiYaF5i22iGfQIQ',
    'oNGxt55yBKViLfS1b2yiShktMRBY',
    'oNGxt53tcYyemRFDeQko00o7AZ3o',
    'oNGxt5-aHD19t60g3q23wAPtCvic',
    'oNGxt56Z_3lspxjJj8VveXSmVia0',
    'oNGxt5xZMaY2ekG8PHsqEcApDR7Q',
    'oNGxt51_vsXp_nZ4YcRWCuZh3D54',
    'oNGxt52e12JD3Ai4998Us9WiYUFk'
)
AND l.name = '胡琴说（上）'
AND wp.live_id = 1124820;

SELECT COUNT(*) INTO @target_count
FROM tmp_drh_history_pic_unionid_bak_target;

-- 审核目标行；执行前预期 target_rows=92、target_union_cnt=92、class_id=1124820。
SELECT
    @target_count AS target_rows,
    COUNT(DISTINCT source_union_id) AS target_union_cnt,
    COUNT(DISTINCT class_id) AS class_cnt,
    MIN(class_id) AS min_class_id,
    MAX(class_id) AS max_class_id
FROM tmp_drh_history_pic_unionid_bak_target;

SELECT class_id, source_union_id, target_union_id, COUNT(*) AS target_count
FROM tmp_drh_history_pic_unionid_bak_target
GROUP BY class_id, source_union_id, target_union_id
ORDER BY class_id, source_union_id;

-- 执行更新；@target_count=92 是本批保护条件。
UPDATE drh_history_pic hp
JOIN tmp_drh_history_pic_unionid_bak_target t
    ON t.id = hp.id
SET hp.union_id = t.target_union_id
WHERE hp.union_id = t.source_union_id
  AND @target_count = 92;

SELECT ROW_COUNT() AS updated_rows;

-- 更新后复核；预期 updated_count=92、not_updated_count=0。
SELECT
    t.class_id,
    COUNT(*) AS target_count,
    SUM(CASE WHEN hp.union_id = t.target_union_id THEN 1 ELSE 0 END) AS updated_count,
    SUM(CASE WHEN hp.union_id <> t.target_union_id THEN 1 ELSE 0 END) AS not_updated_count
FROM tmp_drh_history_pic_unionid_bak_target t
JOIN drh_history_pic hp
    ON hp.id = t.id
GROUP BY t.class_id
ORDER BY t.class_id;

SELECT
    t.source_union_id,
    t.id,
    hp.union_id AS current_union_id,
    t.target_union_id
FROM tmp_drh_history_pic_unionid_bak_target t
JOIN drh_history_pic hp
    ON hp.id = t.id
WHERE hp.union_id <> t.target_union_id
ORDER BY t.source_union_id;

-- 更新后运维接口参数：POST /works/songScore
SELECT JSON_OBJECT(
    'class_id', 1124820,
    'max_score', 83,
    'min_score', 77,
    'song_name', '胡琴说'
) AS song_score_request_body;

-- 审核确认后改为 COMMIT;
ROLLBACK;
