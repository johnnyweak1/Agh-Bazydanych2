
-- Przyklad 1 - St_Intersects
-- Przeciecie rastra wektorem
CREATE TABLE schema_name.intersects AS SELECT a.rast, b.municipality FROM rasters.dem AS a,
vectors.porto_parishes AS b WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

-- 1. Dodanie serial primary key
alter table schema_name.intersects add column rid SERIAL PRIMARY KEY;

-- 2. Utworzenie indexu przestrzennego
CREATE INDEX idx_intersects_rast_gist ON schema_name.intersects USING gist (ST_ConvexHull(rast));

-- 3. Dodanie raster constraints
-- schema::name table_name::name raster_column::name 
SELECT AddRasterConstraints('schema_name'::name,'intersects'::name,'rast'::name);

-- Przyklad 2 - St_Clip
-- Obcinanie rastra na podstawie wektora.

CREATE TABLE schema_name.clip AS SELECT ST_Clip(a.rast, b.geom, true), b.municipality FROM rasters.dem AS a,
vectors.porto_parishes AS b WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

-- Przykład 3 - ST_Union
-- Połączenie wielu kafelków w jeden raster.

CREATE TABLE schema_name.union AS SELECT ST_Union(ST_Clip(a.rast, b.geom, true))FROM
rasters.dem AS a, vectors.porto_parishes AS b WHERE b.municipality ilike 'porto' and 
ST_Intersects(b.geom,a.rast);

-- Tworzenie rastrów z wektorów (rastrowanie)
-- Poniższe przykłady pokazują rastrowanie wektoru.

-- Przykład 1 - ST_AsRaster

CREATE TABLE schema_name.porto_parishes AS WITH r AS (SELECT rast FROM rasters.dem LIMIT 1)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast FROM vectors.porto_parishes AS a
, r WHERE a.municipality ilike 'porto';

-- Przykład 2 - ST_Union
DROP TABLE schema_name.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_name.porto_parishes AS WITH r AS (SELECT rast FROM rasters.dem LIMIT 1)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast FROM 
vectors.porto_parishes AS a, r WHERE a.municipality ilike 'porto';

-- Przykład 3 - ST_Tile
DROP TABLE schema_name.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_name.porto_parishes AS WITH r AS (SELECT rast FROM rasters.dem LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS 
rast FROM vectors.porto_parishes AS a, r WHERE a.municipality ilike 'porto';

-- Konwertowanie rastrów na wektory (wektoryzowanie)
-- Przykład 1 - ST_Intersection
create table schema_name.intersection as SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,
(ST_Intersection(b.geom,a.rast)).val FROM rasters.landsat8 AS a, vectors.porto_parishes AS 
b WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-- Przykład 2 - ST_DumpAsPolygons
CREATE TABLE schema_name.dumppolygons AS SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,
(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val FROM rasters.landsat8 AS a,
vectors.porto_parishes AS b WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-- Analiza rastrow
-- Przykład 1 - ST_Band
CREATE TABLE schema_name.landsat_nir AS SELECT rid, ST_Band(rast,4) AS rast FROM rasters.landsat8;

-- Przykład 2 - ST_Clip
CREATE TABLE schema_name.paranhos_dem AS SELECT a.rid,ST_Clip(a.rast, b.geom,true) 
as rast FROM rasters.dem AS a, vectors.porto_parishes AS b WHERE b.parish ilike 'paranhos' 
and ST_Intersects(b.geom,a.rast);

-- Przykład 3 - ST_Slope
CREATE TABLE schema_name.paranhos_slope AS SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') 
as rast FROM schema_name.paranhos_dem AS a;

-- Przykład 4 - ST_Reclass
CREATE TABLE schema_name.paranhos_slope_reclass AS SELECT a.rid,
ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3','32BF',0)
FROM schema_name.paranhos_slope AS a;

-- Przykład 5 - ST_SummaryStats
SELECT st_summarystats(a.rast) AS stats FROM schema_name.paranhos_dem AS a;

-- Przykład 6 - ST_SummaryStats oraz Union
SELECT st_summarystats(ST_Union(a.rast))FROM schema_name.paranhos_dem AS a;

-- Przykład 7 - ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (SELECT st_summarystats(ST_Union(a.rast)) AS stats FROM schema_name.paranhos_dem AS a)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

-- Przykład 8 - ST_SummaryStats w połączeniu z GROUP BY
WITH t AS (SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,b.geom,true))) 
		   AS stats FROM rasters.dem AS a, vectors.porto_parishes AS 
		   b WHERE b.municipality ilike 'porto' and 
		   ST_Intersects(b.geom,a.rast)group by b.parish)
		   SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;
		   
-- Przykład 9 - ST_Value
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

-- Przykład 10 - ST_TPI
create table schema_name.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

-- Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist ON schema_name.tpi30
USING gist (ST_ConvexHull(rast));
-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name,
'tpi30'::name,'rast'::name);

-- PROBLEM DO SAMODZIELNEGO ROZW
create table schema_name.tpi30_porto as
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto'
-- Dodanie indeksu przestrzennego:
CREATE INDEX idx_tpi30_porto_rast_gist ON schema_name.tpi30_porto
USING gist (ST_ConvexHull(rast));
-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name,
'tpi30_porto'::name,'rast'::name);

-- Algebra map
-- Przykład 1 - Wyrażenie Algebry Map
CREATE TABLE schema_name.porto_ndvi AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] +
[rast1.val])::float','32BF'
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi_rast_gist ON schema_name.porto_ndvi
USING gist (ST_ConvexHull(rast));
-- Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name,
'porto_ndvi'::name,'rast'::name);

--Przykład 2 – Funkcja zwrotna
--W pierwszym kroku należy utworzyć funkcję, które będzie wywołana później:
create or replace function schema_name.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;
-- W kwerendzie algebry map należy można wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE schema_name.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'schema_name.ndvi(double precision[],
integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;
-- Dodanie indeksu przestrzennego:
CREATE INDEX idx_porto_ndvi2_rast_gist ON schema_name.porto_ndvi2
USING gist (ST_ConvexHull(rast));
--Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name,
'porto_ndvi2'::name,'rast'::name);

-- Eksport danych
-- Przykład 1 - ST_AsTiff
SELECT ST_AsTiff(ST_Union(rast))
FROM schema_name.porto_ndvi;

-- Przykład 2 - ST_AsGDALRaster
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
FROM schema_name.porto_ndvi;

-- Przykład 3 - Zapisywanie danych na dysku za pomocą dużego obiektu (large object,lo) 
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM schema_name.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'C:\Users\johnny.weak\Desktop\BD2\cw6\myraster.tiff') 
FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
FROM tmp_out; --> Delete the large object.





