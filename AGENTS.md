Konventionen:

Benennung
SnakeCase
Bspw: xxxx_yyyyy_zzzzz
<PBI-Komponenten-Kürzel>_<Objektname>
Dataflow: df_<Objektname> (Bspw: df_
Semantisches Modell: sm_<Objektname>
Tabelle: <dim|fakt>_<Objektname>
...
Spaltenbenennung (Bspw. für BBW Faktentabelle)
PrimaryKeys immer nur 'ID'
ForeignKeys: ID_<AttributName> (Bspw. ID_FAHRZEUG)
Namen in deutsch für Spalten
Herausfinden: Gibt es Spalten bei Reports, die weiterverarbeitet werden, bei denen die Spalten fest-definierte Namen haben müssen? (Hendrik)
Entwicklungskonvention
Generell:
Mit Reverse-Engineering Spalten, die gar nicht verwendet werden herausfinden und nach Abwägung entfernen 
So simpel, einfach wie möglich, um den Wartungsaufwand zu verringern
Spalten können auch im Nachhinein dazugefügt werden bei Bedarf
Ist Historisierung relevant?
Müssen Daten geladen werden, die bspw. Deaktiviert sind?
müssen wir eine Historisierung einbauen in das Laden der Daten? (Bspw. Ingestiontime, nur letzten 3 Jahre laden (möglichst schon im Dataflow eingrenzen))
Dataflow
Ein Dataflow pro Ziel-Tabelle, Ziel-Tabelle kann Dimension/Faktentabelle sein, die bspw. aus 3 Quell-Tabellen bestehen kann
Denormalisieren durch joins direkt in Quell Query
Vorteil: gemeinsame Dimensionen kommen nur in einem flow vor
Wenn möglich immer Query-Folding verwenden (SQL Eingabefenster im 1. Source Step)
Auch bei den "einfachsten" Steps (Dataflows, die die Tabellen 1:1 laden)
Nur die Spalten laden, die es wirklich braucht
Spalten und Zeilen auf nötiges reduzieren, kein select *, wenn möglich Zeitraum filtern bei Fakten
ist inkrementeller Load / delta möglich ?
Semantisches Modell:
Measures
immer Namen in deutsch
Dezimalstellen
2 Dezimalstellen wenn möglich
Beschreibendes Kommentar hinzufügen für jedes Measure
Measure-Container → in eine eigene Tabelle
Name: "_measures" (dadurch ganz oben)
IDs immer als Text
Darauf achten:
PKs und FKs sind keine aggreggierbaren Datentypen
Spalten, die nicht aggregiert werden sollen, nicht aggregieren
Dimension/Faktentabellen
Beschreibendes Kommentar hinzufügen
Relationen
Kardinalität 1:1 oder 1:N; N:M immer vermeiden
Per default immer Filter-Direction "single", nur in Ausnahmefällen "both"
Reports:
Paginated vs. PBI mit Visuals
Präferiert werden PBI Reports 
nach dem Grad der Interaktion
wenn mehr als 150k Zeilen → Paginated
Bericht für PDF Export → Paginated
Reports mit sonstige Tabellen, Diagramme, Filtern, Interaktion, Drill-down, Vergleichen zwischen verschiedenen Ansichten → PBI Report
Paginated eher für Details und mehrseitige Ausgaben, Ausgabe optimiert (Druck PDF oder Formulare)