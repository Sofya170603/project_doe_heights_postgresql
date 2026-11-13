-- =====================================================================
-- 02_load.sql — загрузка данных из heights_clean.csv в таблицы
-- Запуск:  \i 02_load.sql
-- =====================================================================

SET search_path TO doe, public;

DROP TABLE IF EXISTS stg_heights;       

CREATE TABLE stg_heights (
    source_sheet TEXT,       
    sample_code  TEXT,      
    measured_on  DATE,       
    label        TEXT,       
    lens_no      INTEGER,    
    height_um    NUMERIC    
);

\copy stg_heights FROM 'heights_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')


INSERT INTO sample (code)
SELECT DISTINCT sample_code
FROM stg_heights
ORDER BY sample_code;


INSERT INTO measurement (sample_id, measured_on, label, source_sheet)
SELECT DISTINCT s.sample_id, t.measured_on, t.label, t.source_sheet
FROM stg_heights t
JOIN sample s ON s.code = t.sample_code
ORDER BY t.measured_on;

INSERT INTO lens_height (measurement_id, lens_no, height_um)
SELECT m.measurement_id, t.lens_no, t.height_um
FROM stg_heights t
JOIN measurement m ON m.source_sheet = t.source_sheet;

SELECT (SELECT count(*) FROM sample)      AS samples,
       (SELECT count(*) FROM measurement) AS measurements,
       (SELECT count(*) FROM lens_height) AS heights;

DROP TABLE stg_heights;
