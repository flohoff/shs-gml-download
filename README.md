
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

Das dauert ein paar minuten. Danach sollten in der Datenbank so etwa 16000+ Flure sein.

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

Import der GML files
====================

    git clone git@github.com:norBIT/alkisimport.git
    cd alkisimport
    psql shs -v alkis_epsg=25832 -v alkis_schema=public -v postgis_schema=public -v parent_schema=public -f alkis-init.sql 

Scheinbar weicht das ALKIS/GML in Schleswig-Holstein teilweise vom Standard Schema ab. Daher hab ich folgende
constraints noch entfernt:

    psql shs -c "alter table ax_bodenschaetzung alter column kulturart drop not null;"
    psql shs -c "alter table ax_lagefestpunkt alter column gemeinde_land drop not null;"
    psql shs -c "alter table ax_lagefestpunkt alter column land_land drop not null;"
    psql shs -c "alter table ax_hoehenfestpunkt alter column gemeinde_land drop not null;"
    psql shs -c "alter table ax_hoehenfestpunkt alter column land_land drop not null;"
    psql shs -c "alter table ax_schwerefestpunkt alter column gemeinde_land drop not null;"
    psql shs -c "alter table ax_schwerefestpunkt alter column land_land drop not null;"
    psql shs -c "alter table ax_georeferenziertegebaeudeadresse alter column hatauch drop not null;"
    psql shs -c "alter table ax_schwere alter column schweresystem drop not null;"

Abhaengigkeiten (Debian)
========================

    apt-get install postgis postgresql libfile-slurp-perl libjson-perl libwww-perl gdal-bin


