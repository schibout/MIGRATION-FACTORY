import React, { useEffect, useMemo, useState } from 'react';
import { Autocomplete, TextField } from '@mui/material';

import { getLovValues, LovValue } from '../../services/lovService';

/**
 * Combobox alimentee par une liste de valeurs (public.maintenance_lov_*).
 *
 * Volontairement bati sur le MEME <Autocomplete size="small"> + <TextField>
 * que "Poste de travail" / "Poste responsable" dans la fiche d'un poste
 * technique : aucun style propre, le rendu suit le theme sombre comme les
 * autres champs du formulaire.
 *
 * La valeur REMONTEE par onChange est le CODE de la valeur ('CR1', 'Z-17'),
 * jamais le libelle : c'est le code qui est stocke en base.
 *
 * Valeur hors liste : si `value` ne correspond a aucun code de la liste (cas
 * des saisies en texte libre anterieures a la bascule LOV, ou d'une valeur
 * desactivee depuis), elle est AJOUTEE a la liste et marquee « hors liste »
 * plutot que d'etre ignoree. Sans cela, ouvrir la fiche en modification puis
 * enregistrer effacerait silencieusement la valeur existante.
 */
interface LovSelectProps {
  listCode: string;
  /** Site ; omis = toutes les valeurs actives de la liste. */
  contract?: string;
  value: string | null | undefined;
  /** Recoit le CODE ; la valeur complete est fournie en 2e argument pour les
   *  appelants qui veulent afficher le libelle (recapitulatif de modification
   *  en masse, par exemple). */
  onChange: (code: string, valeur?: LovValue | null) => void;
  label: string;
  disabled?: boolean;
}

const LovSelect: React.FC<LovSelectProps> = ({
  listCode, contract, value, onChange, label, disabled,
}) => {
  const [options, setOptions] = useState<LovValue[]>([]);
  const [loading, setLoading] = useState(false);
  const [erreur, setErreur] = useState(false);

  useEffect(() => {
    let annule = false;
    (async () => {
      setLoading(true);
      setErreur(false);
      try {
        const vals = await getLovValues(listCode, contract);
        if (!annule) setOptions(vals);
      } catch {
        // Liste inconnue cote serveur, ou API indisponible : on n'efface pas
        // le champ pour autant, la valeur deja saisie reste affichee.
        if (!annule) { setOptions([]); setErreur(true); }
      } finally {
        if (!annule) setLoading(false);
      }
    })();
    return () => { annule = true; };
  }, [listCode, contract]);

  // La valeur courante doit toujours etre selectionnable, meme absente de la liste.
  const optionsAffichees = useMemo(() => {
    const courante = (value ?? '').trim();
    if (!courante || options.some((o) => o.code === courante)) return options;
    return [...options, { code: courante, libelle: '(hors liste)', contract: null }];
  }, [options, value]);

  const selection = optionsAffichees.find((o) => o.code === (value ?? '')) || null;

  const messageAide = erreur
    ? 'Liste de valeurs indisponible'
    : (!loading && options.length === 0 ? 'Aucune valeur paramétrée' : undefined);

  return (
    <Autocomplete
      size="small"
      options={optionsAffichees}
      loading={loading}
      disabled={disabled}
      getOptionLabel={(opt) => (opt.libelle ? `${opt.code} - ${opt.libelle}` : opt.code)}
      value={selection}
      onChange={(_, val) => onChange(val?.code || '', val)}
      isOptionEqualToValue={(opt, val) => opt.code === val.code}
      renderInput={(params) => (
        <TextField {...params} label={label} helperText={messageAide} />
      )}
    />
  );
};

export default LovSelect;
