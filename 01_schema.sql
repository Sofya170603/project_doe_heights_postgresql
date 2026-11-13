-- =====================================================================
-- 01_schema.sql — схема БД высот микрорельефа ДОЭ
-- Запуск в psql (база doe_lab, папка проекта): \i 01_schema.sql
-- Скрипт можно запускать повторно: схема doe каждый раз пересоздаётся.
-- =====================================================================

DROP SCHEMA IF EXISTS doe CASCADE;
CREATE SCHEMA doe;
SET search_path TO doe, public;   -- обращаться к таблицам без префикса doe.

-- Образцы ДОЭ (N, S1, S2, ...)
CREATE TABLE sample (
    sample_id   SERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,
    description TEXT
);

-- Измерения: один лист Excel = одно измерение; образец (1) — измерения (N)
CREATE TABLE measurement (
    measurement_id SERIAL PRIMARY KEY,
    sample_id      INTEGER NOT NULL REFERENCES sample (sample_id),
    measured_on    DATE NOT NULL,
    label          TEXT,                  -- метка из названия листа, напр. 'v2'
    source_sheet   TEXT NOT NULL UNIQUE   -- исходный лист; UNIQUE защищает от двойной загрузки
);

-- Справочник 16 линз и их положение в сетке 4x4.
-- Номер физический, поэтому задаётся вручную, без автонумерации.
CREATE TABLE lens (
    lens_no  INTEGER PRIMARY KEY,
    grid_row INTEGER NOT NULL,   -- 1 = верхняя строка
    grid_col INTEGER NOT NULL    -- 1 = левый столбец
);

-- Нумерация линз по столбцам сверху вниз: столбец 1 = линзы 1–4, столбец 2 = 5–8 и т.д.
INSERT INTO lens (lens_no, grid_row, grid_col) VALUES
    (1, 1, 1),  (2, 2, 1),  (3, 3, 1),  (4, 4, 1),
    (5, 1, 2),  (6, 2, 2),  (7, 3, 2),  (8, 4, 2),
    (9, 1, 3),  (10, 2, 3), (11, 3, 3), (12, 4, 3),
    (13, 1, 4), (14, 2, 4), (15, 3, 4), (16, 4, 4);

-- Высоты: одна строка = одна линза в одном измерении (связь измерений и линз M:N)
CREATE TABLE lens_height (
    measurement_id INTEGER NOT NULL REFERENCES measurement (measurement_id),
    lens_no        INTEGER NOT NULL REFERENCES lens (lens_no),
    height_um      NUMERIC(5,2) NOT NULL,     -- мкм, точное десятичное
    PRIMARY KEY (measurement_id, lens_no)     -- у линзы в измерении только одна высота
);

-- Проверка после запуска:
--     \dt doe.*                                  -- 4 таблицы
--     SELECT * FROM doe.lens ORDER BY lens_no;   -- 16 строк