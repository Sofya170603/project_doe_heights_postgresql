-- =====================================================================
-- 03_queries.sql — лесенка запросов от простых к сложным
-- Запуск в psql: \i 03_queries.sql (или по одному запросу в pgAdmin)
-- =====================================================================
SET search_path TO doe, public;

-- ======================= УРОВЕНЬ 1. Выборка =========================

-- 1.1 Все измерения с кодом образца (JOIN)
SELECT m.measurement_id, s.code, m.measured_on, m.label
FROM measurement m
JOIN sample s ON s.sample_id = m.sample_id
ORDER BY m.measured_on;

-- 1.2 Высоты всех 16 линз одного измерения (по имени листа)
SELECT lh.lens_no, lh.height_um
FROM lens_height lh
JOIN measurement m ON m.measurement_id = lh.measurement_id
WHERE m.source_sheet = '09.02.26 (SD)'
ORDER BY lh.lens_no;

-- 1.3 Все случаи, когда высота превысила 4.7 мкм
SELECT m.source_sheet, lh.lens_no, lh.height_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
WHERE lh.height_um > 4.7
ORDER BY lh.height_um DESC;

-- ======================= УРОВЕНЬ 2. Агрегаты ========================

-- 2.1 Статистика по каждому измерению
SELECT m.source_sheet,
       count(*)                              AS n,
       round(avg(lh.height_um), 3)           AS mean_um,
       min(lh.height_um)                     AS min_um,
       max(lh.height_um)                     AS max_um,
       max(lh.height_um) - min(lh.height_um) AS range_um,
       round(stddev_samp(lh.height_um), 3)   AS sd_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
GROUP BY m.measurement_id, m.source_sheet
ORDER BY m.measured_on;

-- 2.2 HAVING: измерения, где разброс высот между линзами больше 0.8 мкм
SELECT m.source_sheet, max(lh.height_um) - min(lh.height_um) AS range_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
GROUP BY m.measurement_id, m.source_sheet
HAVING max(lh.height_um) - min(lh.height_um) > 0.8
ORDER BY range_um DESC;

-- 2.3 Средняя высота каждой линзы по всем измерениям, кроме образца SD (он ~1 мкм)
SELECT lh.lens_no, round(avg(lh.height_um), 3) AS mean_um, count(*) AS n
FROM lens_height lh
JOIN measurement m USING (measurement_id)
JOIN sample s USING (sample_id)
WHERE s.code <> 'SD'
GROUP BY lh.lens_no
ORDER BY lh.lens_no;

-- 2.4 Медиана вместо среднего (устойчива к выбросам)
SELECT m.source_sheet,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY lh.height_um) AS median_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
GROUP BY m.measurement_id, m.source_sheet, m.measured_on
ORDER BY m.measured_on;

-- ================== УРОВЕНЬ 3. Подзапросы и CTE =====================

-- 3.1 Измерение с наибольшей средней высотой (подзапрос в HAVING)
SELECT m.source_sheet, round(avg(lh.height_um), 3) AS mean_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
GROUP BY m.measurement_id, m.source_sheet
HAVING avg(lh.height_um) = (
    SELECT max(mean_h)
    FROM (SELECT avg(height_um) AS mean_h FROM lens_height GROUP BY measurement_id) t
);

-- 3.2 Линзы, которые выше среднего ВНУТРИ своего измерения (CTE + JOIN)
WITH stats AS (
    SELECT measurement_id, avg(height_um) AS mean_h
    FROM lens_height
    GROUP BY measurement_id
)
SELECT m.source_sheet, lh.lens_no, lh.height_um, round(st.mean_h, 3) AS mean_um
FROM lens_height lh
JOIN stats st USING (measurement_id)
JOIN measurement m USING (measurement_id)
WHERE lh.height_um > st.mean_h
ORDER BY m.measured_on, lh.lens_no;

-- 3.3 Однородность: разброс в % от средней высоты, рейтинг измерений (CTE)
WITH s AS (
    SELECT measurement_id,
           (max(height_um) - min(height_um)) / avg(height_um) * 100 AS spread_pct
    FROM lens_height
    GROUP BY measurement_id
)
SELECT m.source_sheet, round(s.spread_pct, 1) AS spread_pct
FROM s JOIN measurement m USING (measurement_id)
ORDER BY s.spread_pct;

-- ================== УРОВЕНЬ 4. Оконные функции ======================

-- 4.1 Ранг линзы по высоте внутри каждого измерения
SELECT m.source_sheet, lh.lens_no, lh.height_um,
       rank() OVER (PARTITION BY lh.measurement_id ORDER BY lh.height_um DESC) AS rnk
FROM lens_height lh
JOIN measurement m USING (measurement_id)
ORDER BY m.measured_on, rnk;

-- 4.2 Отклонение каждой линзы от среднего своего измерения
SELECT m.source_sheet, lh.lens_no, lh.height_um,
       round(lh.height_um - avg(lh.height_um) OVER (PARTITION BY lh.measurement_id), 3) AS dev_um
FROM lens_height lh
JOIN measurement m USING (measurement_id)
ORDER BY m.measured_on, lh.lens_no;

-- 4.3 Выбросы: |z| > 2 внутри измерения
SELECT *
FROM (
    SELECT m.source_sheet, lh.lens_no, lh.height_um,
           (lh.height_um - avg(lh.height_um) OVER w) / stddev_samp(lh.height_um) OVER w AS z
    FROM lens_height lh
    JOIN measurement m USING (measurement_id)
    WINDOW w AS (PARTITION BY lh.measurement_id)
) t
WHERE abs(z) > 2
ORDER BY abs(z) DESC;

-- 4.4 Динамика: как менялась средняя высота от измерения к измерению (LAG)
WITH per_m AS (
    SELECT m.measurement_id, m.measured_on, m.source_sheet, avg(lh.height_um) AS mean_h
    FROM measurement m
    JOIN lens_height lh USING (measurement_id)
    GROUP BY m.measurement_id
)
SELECT source_sheet, round(mean_h, 3) AS mean_um,
       round(mean_h - lag(mean_h) OVER (ORDER BY measured_on), 3) AS change_um
FROM per_m
ORDER BY measured_on;

-- 4.5 Скользящее среднее по линзе (две предыдущие + текущая) в хронологии
SELECT lh.lens_no, m.measured_on, lh.height_um,
       round(avg(lh.height_um) OVER (
           PARTITION BY lh.lens_no
           ORDER BY m.measured_on
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 3) AS moving_avg
FROM lens_height lh
JOIN measurement m USING (measurement_id)
WHERE lh.lens_no = 1
ORDER BY m.measured_on;
