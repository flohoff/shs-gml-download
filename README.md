
In diesem Code geht es daraum das downloaden von GML ALKIS Files des Landes
Schleswig-Holstein zu automatisieren, und die heruntergeladenen files in 
eine Postgis zu laden und shapes für z.b. Hausumringe zu exportieren.

Im moment ist der code ziemlich Work-in-Progress.

Florian Lohoff <f@zz.de>

Datenbank (postgres) erzeugen
=============================

	createdb shs 
	psql shs -c "create extension postgis;"
	psql shs -f sql/schema.sql


Alle Flure aus der API holen
============================

Um alle Flure aus der der API zu holen dieses Programm aufrufen.

	perl flure-get

Geht die UTM 32N zone für SHS durch und versucht durch kleiner werdenden Bounding Boxen
alle Flure zu holen. Die gesamte JSON response wird abgespeichert um ggfs die Ausdehnung
d.h. das Polygon der Flure zu haben. Zusätzlich schneidet die API auch die polygone kaputt
wenn diese am Rand der Bounding Box sind. Daher updated flure-get die
polygone wenn deren JSON größer wird (quick hack)

Je nach Startpunkt und Split Verhältnis kommt es dazu das einige Flure nicht mit ihrem heilen,
ganzen Polygon geholt werden. Hier könnte man verbessern das man die BBox zwar viertelt, 
aber jedes viertel 75% der größe der original BBox werden lässt. Work in Progress aber
auch nicht so wichtig weil nicht das polygon des Flurs, sondern dessen **Flurnummer**
unf **ogc_fid** später wichtig ist.

Das dauert ein paar Minuten. Danach sollten in der Datenbank 16917 Flure sein.

	flo@p5:~/$ psql shs -c "select count(*) from flur;"
	 count
	-------
	 16917
	(1 row)

Wenn man die Flure visualisiern möchte z.b. mit QGIS sollte man jetzt die geom spalte
updaten aus dem GeoJSON das in der reponse ist.

	psql shs -c "update flur set geom=ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(response->>'geometry'),25832),4326) where geom is null;"

Download der GML files
======================

Zum download der GML files das ausgabeverzeichnis erzeugen und dann gml-files-get starten.

    mkdir output
	perl gml-files-get

Dieser versucht nach und nach alle Flure die in der SHS datenbank sind aus der API zu requesten, zu warten bis diese bereitgestellt sind und
dann runterzuladen. Da das bereitstellen aktuell so 10-15 Sekunden dauert, und wir von ~17000 Fluren reden sind wir bei >250000 Sekunden
was bei 86400 Sekunden/Tag mehrere Tage bedeutet.

Eine möglichkeit der Parallelisierung ist

	yes | xargs -P4 ./gml-files-get

Hierbei werden 4 prozesse parallel gestartet die Flure herunterladen.

Vorbereitungen für den import der GML files
===========================================

    createdb shs-alkis
    psql shs-alkis -c "create extension postgis;"

    git clone git@github.com:norBIT/alkisimport.git
    cd alkisimport

    psql shs-alkis \
	-v alkis_epsg=25832 \
	-v alkis_schema=public \
	-v postgis_schema=public \
	-v parent_schema=public \
	-f alkis-init.sql 

Scheinbar weicht das ALKIS/GML in Schleswig-Holstein teilweise vom Standard Schema ab. Daher hab ich folgende
constraints noch entfernt:

    psql shs-alkis -c "alter table ax_bodenschaetzung alter column kulturart drop not null;"
    psql shs-alkis -c "alter table ax_lagefestpunkt alter column gemeinde_land drop not null;"
    psql shs-alkis -c "alter table ax_lagefestpunkt alter column land_land drop not null;"
    psql shs-alkis -c "alter table ax_hoehenfestpunkt alter column gemeinde_land drop not null;"
    psql shs-alkis -c "alter table ax_hoehenfestpunkt alter column land_land drop not null;"
    psql shs-alkis -c "alter table ax_schwerefestpunkt alter column gemeinde_land drop not null;"
    psql shs-alkis -c "alter table ax_schwerefestpunkt alter column land_land drop not null;"
    psql shs-alkis -c "alter table ax_georeferenziertegebaeudeadresse alter column hatauch drop not null;"
    psql shs-alkis -c "alter table ax_schwere alter column schweresystem drop not null;"

Import der GML Dateien
======================

    ./gml-import-files

Lädt alle dateien aus "output" in die postgis enablete Datenbank **shs-alkis**. Kann zu jedem zeitpunkt abgebrochen werden und fängt wieder an. Dieser import dauert mehrere Stunden bis Tage.


Export Hausumring shape
=======================

Erst muss eine tabelle mit den entsprechenden infos erzeugt werden wie z.b. hier:

	drop table if exists hu_shs;
	select  *
	into    hu_shs
	from    (
		select  ogc_fid, gml_id, '31001_' || gebaeudefunktion as gfk, wkb_geometry
		from    ax_gebaeude
		where   lagezurerdoberflaeche is null or lagezurerdoberflaeche <> '1200'
		union all
		select  ogc_fid, gml_id, '31002_' || bauart as gfk, wkb_geometry
		from    ax_bauteil
		where   lagezurerdoberflaeche is null or lagezurerdoberflaeche <> '1200'
		union all
		select  ogc_fid, gml_id, '51109_' || bauwerksfunktion as gfk, wkb_geometry
		from    ax_sonstigesbauwerkodersonstigeeinrichtung
		union all
		select  ogc_fid, gml_id, '51002_' || bauwerksfunktion as gfk, wkb_geometry
		from    ax_bauwerkoderanlagefuerindustrieundgewerbe
		) hu
	where   GeometryType(wkb_geometry) in ( 'POLYGON', 'MULTIPOLYGON');

Und anschliessend kann die Tabelle als Shape exportiert werden:

	ogr2ogr -f "ESRI Shapefile" \
		hu_shs.shp \
		PG:"dbname='shs-alkis'" \
		hu_shs


Abhaengigkeiten (Debian)
========================

    apt-get install postgis postgresql libfile-slurp-perl libjson-perl libwww-perl gdal-bin


