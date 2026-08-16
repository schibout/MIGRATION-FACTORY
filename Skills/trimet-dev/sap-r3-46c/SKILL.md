---
name: sap-r3-46c
description: >
  Modèle de données SAP R/3 4.6C : structure organisationnelle, DDIC,
  tables maîtres (articles, clients, fournisseurs, PM, classification),
  tables T de customizing, extraction. Utiliser pour comprendre les
  tables sources SAP d'une migration et leurs clés.
---

# SAP R/3 4.6C — modèle de données et extraction

## 1. Architecture R/3 : MANDT et structure organisationnelle
SAP R/3 sépare les données par mandant : MANDT est le premier champ clé de nombreuses tables applicatives.
Company Code : T001 (MANDT, BUKRS), niveau société FI.
Plant/Division : T001W (MANDT, WERKS), site logistique rattaché au référentiel organisationnel.
Storage Location/Magasin : T001L (MANDT, WERKS, LGORT), subdivision de stock dans un plant.
Sales Organization : TVKO (MANDT, VKORG), Distribution Channel : TVTW (MANDT, VTWEG), Division commerciale : à vérifier.
Purchasing Organization : T024E (MANDT, EKORG) ; affectation plant/achat : T024W (MANDT, WERKS, EKORG).
Implication extraction : conserver MANDT et les zéros significatifs ; filtrer BUKRS/WERKS/VKORG seulement après cadrage métier.

## 2. DDIC : tables, champs, domaines et types de tables
Le DDIC décrit la structure technique SAP : tables, champs, domaines, éléments de données et textes.
Tables : DD02L (TABNAME, AS4LOCAL, AS4VERS) ; textes tables : DD02T (TABNAME, DDLANGUAGE, AS4LOCAL, AS4VERS).
Champs : DD03L (TABNAME, FIELDNAME, AS4LOCAL, AS4VERS, POSITION) ; textes champs : DD03T (TABNAME, DDLANGUAGE, AS4LOCAL, FIELDNAME).
Domaines : DD01L (DOMNAME, AS4LOCAL, AS4VERS) ; Data Elements : DD04L (ROLLNAME, AS4LOCAL, AS4VERS).
DD02L-TABCLASS distingue TRANSP, CLUSTER, POOL, VIEW, INTTAB, APPEND.
Relations/check tables : source DDIC dédiée à vérifier si DD08L/DD08T ne sont pas disponibles localement.
Implication extraction : si DD03L/DD03T locales sont vides, reconstruire clés/types depuis sources DDIC externes et exports réels.

## 3. Material Master : MARA, MARC, MARD, MAKT, MBEW, MVKE
MARA (MANDT, MATNR) porte les données générales Material Master, indépendantes du plant.
MARC (MANDT, MATNR, WERKS) porte les données article par plant.
MARD (MANDT, MATNR, WERKS, LGORT) porte les données article par storage location.
MAKT (MANDT, MATNR, SPRAS) porte les descriptions langue du material.
MBEW (MANDT, MATNR, BWKEY, BWTAR) porte la valorisation par valuation area/type ; T001K (MANDT, BWKEY) décrit la valuation area.
MVKE (MANDT, MATNR, VKORG, VTWEG) porte les données commerciales article.
Relations : MARA est le tronc ; MARC, MARD, MBEW et MVKE ajoutent les niveaux organisationnels.
Implication extraction : ne pas joindre sans tenir compte de WERKS, LGORT, BWKEY, VKORG, VTWEG, SPRAS et BWTAR.

## 4. Customers et Suppliers : niveaux général, société, ventes/achats
Customer général : KNA1 (MANDT, KUNNR), identité commune du client.
Customer Company Code : KNB1 (MANDT, KUNNR, BUKRS), données client par société.
Customer Sales Area : KNVV (MANDT, KUNNR, VKORG, VTWEG, SPART), données client par organisation commerciale.
Vendor général : LFA1 (MANDT, LIFNR), identité commune du fournisseur.
Vendor Company Code : LFB1 (MANDT, LIFNR, BUKRS), données fournisseur par société.
Vendor Purchasing Organization : LFM1 (MANDT, LIFNR, EKORG), données fournisseur par organisation achats.
Relations : les niveaux société, ventes et achats dépendent du partenaire général et des référentiels organisationnels.
Implication extraction : extraire les niveaux séparément ; ne pas dédupliquer KUNNR/LIFNR en supprimant BUKRS, VKORG, VTWEG, SPART ou EKORG.

## 5. Maintenance PM : Functional Location, Equipment, plans et gammes
Functional Location : IFLOT (MANDT, TPLNR), structure technique ; localisation/affectation : ILOA (MANDT, ILOAN).
Equipment : EQUI (MANDT, EQUNR), master data équipement ; texte équipement : EQKT (MANDT, EQUNR, SPRAS).
Maintenance Plan : MPLA (MANDT, WARPL), en-tête plan d'entretien.
Maintenance Item : MPOS (MANDT, WAPOS), poste du plan ; lien précis plan/poste à vérifier sur export/DDIC client.
Maintenance Plan History : MHIS (MANDT, WARPL, ABNUM, ZAEHL), historique d'appel/plan.
Task List header : PLKO (MANDT, PLNTY, PLNNR, PLNAL, ZAEHL) ; operation/activity : PLPO (MANDT, PLNTY, PLNNR, PLNKN, ZAEHL).
Implication extraction : PM mélange objets techniques, textes langue, plans et gammes ; garder les clés complètes et les statuts à part.

## 6. Classification : classes, characteristics et valeurs d'objet
Class header : KLAH (MANDT, CLINT), définition d'une classe.
Characteristic : CABN (MANDT, ATINN, ADZHL), définition technique d'une caractéristique.
Characteristic values : CAWN (MANDT, ATINN, ATZHL, ADZHL), valeurs autorisées d'une caractéristique.
Object characteristic values : AUSP (MANDT, OBJEK, ATINN, ATZHL, MAFID, KLART, ADZHL), valeurs portées par un objet.
Internal object link : INOB (MANDT, CUOBJ), lien entre numéro interne et objet classé.
Chemin général : identifier l'objet via INOB si nécessaire, lire AUSP, enrichir par CABN et CAWN, puis rattacher à KLAH selon la classe.
Implication extraction : OBJEK/CUOBJ peuvent dépendre du type d'objet ; valider le format réel avant mapping vers IFS.

## 7. Customizing : tables T* et libellés
Les tables T* sont des référentiels de codes SAP utilisés par les tables maîtres et transactionnelles.
Company Codes : T001 (MANDT, BUKRS) ; Plants : T001W (MANDT, WERKS) ; Storage Locations : T001L (MANDT, WERKS, LGORT).
Units of Measurement : T006 (MANDT, MSEHI) ; textes unités : T006A (MANDT, SPRAS, MSEHI).
Sales Organization texts : TVKOT (MANDT, SPRAS, VKORG) ; Distribution Channel texts : TVTWT (MANDT, SPRAS, VTWEG).
Division commerciale texte : TSPAT (MANDT, SPRAS, SPART) ; table code SPART à vérifier.
Purchasing Organizations : T024E (MANDT, EKORG) ; validité plant/achat : T024W (MANDT, WERKS, EKORG).
Implication extraction : extraire codes et textes avec SPRAS ; sans tables T*, les codes SAP sont difficiles à interpréter côté IFS.

## 8. Extraction : SE16/SE16N, RFC_READ_TABLE, fichiers et codepages
SE16 (Data Browser) et SE16N (General Table Display) servent à consulter/exporter des tables quand autorisés.
RFC_READ_TABLE expose QUERY_TABLE, DELIMITER, NO_DATA, ROWSKIPS, ROWCOUNT, OPTIONS, FIELDS et DATA.
La sortie DATA est de type TAB512 ; TAB512 contient WA, champ de 512 bytes.
Les options WHERE passent par RFC_DB_OPT ; la liste de champs passe par RFC_DB_FLD.
Les exceptions documentées incluent table inactive, structure sans données, option/champ invalide, autorisation et DATA_BUFFER_EXCEEDED.
R/3 4.6C est non-Unicode dans le contexte projet : décoder les exports avec la codepage source ; cp1252/latin-1 Europe Ouest est à vérifier sur fichier.
Implication extraction : limiter les champs/lignes, paginer, préférer exports fichiers fiables, et tracer encodage, séparateur, compte lignes et MANDT.

## Sources
SAP Help Portal, recherche officielle, info ECC/support quand 4.6C non trouvée : Corporate Structure, Tables related to dictionary objects, Material Master Data Structures, Tables SAP Classification, Character Codes.
https://help.sap.com/http.svc/elasticsearch?q=organizational+structure+company+code+plant+storage+location+sales+organization+SAP+R%2F3 (doc ECC/support)
https://help.sap.com/http.svc/elasticsearch?q=DD02L+DD02T+DD03L+DD03T+ABAP+Dictionary+transparent+pool+cluster+tables (doc support)
https://help.sap.com/http.svc/elasticsearch?q=Material+master+MARA+MARC+MARD+MAKT+MBEW+MVKE+views (doc support/ECC)
https://help.sap.com/http.svc/elasticsearch?q=classification+KLAH+CABN+CAWN+AUSP+INOB+SAP+characteristics+object (doc support)
https://help.sap.com/http.svc/elasticsearch?q=non-Unicode+code+page+SAP+R%2F3 (doc ECC)
https://www.sapdatasheet.org/abap/tabl/dd02l.html ; https://www.sapdatasheet.org/abap/tabl/dd03l.html ; https://www.sapdatasheet.org/abap/doma/tabclass.html (DDIC)
https://www.sapdatasheet.org/abap/tabl/mara.html ; marc.html ; mard.html ; makt.html ; mbew.html ; mvke.html (DDIC)
https://www.sapdatasheet.org/abap/tabl/kna1.html ; knb1.html ; knvv.html ; lfa1.html ; lfb1.html ; lfm1.html (DDIC)
https://www.sapdatasheet.org/abap/tabl/iflot.html ; iloa.html ; equi.html ; eqkt.html ; mpla.html ; mpos.html ; mhis.html ; plko.html ; plpo.html (DDIC)
https://www.sapdatasheet.org/abap/tabl/klah.html ; cabn.html ; cawn.html ; ausp.html ; inob.html (DDIC)
https://www.sapdatasheet.org/abap/tabl/t001.html ; t001w.html ; t001l.html ; t006.html ; t006a.html ; tvko.html ; tvtw.html ; tvkot.html ; tvtwt.html ; tspat.html ; t024e.html ; t024w.html ; t001k.html (DDIC)
https://www.sapdatasheet.org/abap/func/rfc_read_table.html ; https://www.sapdatasheet.org/abap/tabl/tab512.html ; rfc_db_opt.html ; rfc_db_fld.html ; https://www.sapdatasheet.org/abap/tran/se16.html ; se16n.html (DDIC/support)
