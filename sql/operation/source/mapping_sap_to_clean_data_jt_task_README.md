Mapping SAP vers clean_data.jt_task

Généré le 2026-07-08T23:33:08

Fichier principal: /opt/data/ifs_model_analysis/mapping_sap_to_clean_data_jt_task.csv

Source IFS: /opt/data/ifs_model_analysis/ifs_fields_catalog.csv
Workbook: Lot11_Maintenance_Opérations_V2.0.xlsx
Table cible: JT_TASK / clean_data.jt_task
Nombre de colonnes cible: 169
Colonnes avec une source/règle proposée: 91
Colonnes sans mapping direct: 78

Hypothèse fonctionnelle:
JT_TASK représente l'opération/tâche de maintenance IFS. La source SAP principale proposée est l'opération d'ordre SAP PM, portée par AFVC, enrichie par AFVV pour dates/durées, AFKO pour l'ordre/BT, AFRU pour le réel/confirmations, CRHD/CRTX pour les postes de travail, JEST/JCDS pour les statuts.

Tables SAP disponibles vérifiées dans raw_data:
- afvc, afvv, afko, afru, crhd, crtx, jest, jcds sont présentes.
- afih, aufk, qmel, qmfe, resb ne sont pas présentes actuellement dans raw_data au moment de l'analyse.

Jointures proposées:
- AFKO.AUFPL = AFVC.AUFPL
- AFVV.AUFPL = AFVC.AUFPL AND AFVV.APLZL = AFVC.APLZL
- AFRU.RUECK = AFVC.RUECK AND AFRU.RMZHL = AFVC.RMZHL, ou AFRU.AUFPL/AFRU.APLZL si les confirmations sont au niveau opération
- CRHD.OBJID = AFVC.ARBID AND CRHD.WERKS = AFVC.WERKS
- JEST.OBJNR = AFVC.OBJNR avec JEST.INACT vide/non X

Points à valider métier:
- TASK_SEQ: généré par IFS ou généré ETL depuis AFVC.AUFPL/APLZL.
- WO_NO: mapping vers AFKO.AUFNR, en conservant ou non les zéros SAP.
- ORGANIZATION_ID / TEAM_ID: transcodification CRHD.ARBPL vers référentiel IFS.
- WORK_TYPE_ID / WORK_STAGE_ID: transcodification AFVC.STEUS.
- PRIORITY_ID: AFKO.APRIO proposé, mais AFIH.PRIOK serait plus PM si AFIH est chargé.
- Dates planifiées/réelles: choix entre dates AFVV et confirmations AFRU selon règle métier.
- Champs défaut obligatoires IFS: EXCLUDE_FROM_SCHEDULING_DB, APPOINTMENT_REQUIRED, REMOTELY_FULFILLED, SCHEDULED_MANUALLY.
