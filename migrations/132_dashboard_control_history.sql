-- Tableau de bord : historique des controles des ecrans Donnees IFS, une mesure par controle et par jour
-- (la derniere de la journee remplace les precedentes). Sert aussi de cache : la page lit la derniere mesure.
-- anomalies NULL = controle non calculable (a ne pas confondre avec 0). Rejouable.
CREATE TABLE IF NOT EXISTS public.dashboard_control_history (
    jour          date        NOT NULL,
    ecran         varchar(40) NOT NULL,
    code          varchar(80) NOT NULL,
    label         text        NOT NULL,
    anomalies     integer,
    calculated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (jour, ecran, code)
);
