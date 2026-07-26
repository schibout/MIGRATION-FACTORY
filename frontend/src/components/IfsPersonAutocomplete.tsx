import { Autocomplete, CircularProgress, TextField } from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import api from '../services/api';

export interface IfsPersonOption {
    person_id: string;
    first_name?: string | null;
    last_name?: string | null;
    internal_display_name?: string | null;
}

interface IfsPersonAutocompleteProps {
    /** person_id actuellement associé (ou null si non associé) */
    value: string | null;
    /** Appelé avec le nouveau person_id sélectionné, ou null si dissocié */
    onChange: (personId: string | null) => void;
    size?: 'small' | 'medium';
    disabled?: boolean;
    label?: string;
    placeholder?: string;
    /** Largeur mini (utile en cellule de tableau) */
    minWidth?: number;
}

const optionLabel = (o: IfsPersonOption): string => {
    const name = [o.first_name, o.last_name].filter(Boolean).join(' ').trim();
    return name ? `${o.person_id} — ${name}` : o.person_id;
};

/**
 * Sélecteur de personne IFS avec recherche intelligente (asynchrone, débouncée)
 * sur l'endpoint /resources/ifs-persons. La valeur manipulée est le person_id (string).
 * Réutilisé sur la liste des utilisateurs SharePoint et la page détail.
 */
const IfsPersonAutocomplete: React.FC<IfsPersonAutocompleteProps> = ({
    value,
    onChange,
    size = 'small',
    disabled = false,
    label,
    placeholder,
    minWidth = 220,
}) => {
    const [query, setQuery] = useState('');
    const [options, setOptions] = useState<IfsPersonOption[]>([]);
    const [loading, setLoading] = useState(false);
    const [open, setOpen] = useState(false);

    // Option représentant la valeur courante (on ne connaît que le person_id)
    const selectedOption: IfsPersonOption | null = useMemo(
        () => (value ? { person_id: value } : null),
        [value]
    );

    // Recherche serveur débouncée, uniquement quand la liste est ouverte
    useEffect(() => {
        if (!open) return;
        let active = true;
        setLoading(true);
        const handle = setTimeout(async () => {
            try {
                const response = await api.get('/resources/ifs-persons', {
                    params: { page: 1, per_page: 20, search: query.trim() },
                });
                if (active) setOptions(response.data.data || []);
            } catch {
                if (active) setOptions([]);
            } finally {
                if (active) setLoading(false);
            }
        }, 300);
        return () => {
            active = false;
            clearTimeout(handle);
        };
    }, [query, open]);

    // Injecte la valeur courante dans les options pour qu'elle s'affiche même sans recherche
    const mergedOptions = useMemo(() => {
        if (selectedOption && !options.some((o) => o.person_id === selectedOption.person_id)) {
            return [selectedOption, ...options];
        }
        return options;
    }, [selectedOption, options]);

    return (
        <Autocomplete
            size={size}
            disabled={disabled}
            open={open}
            onOpen={() => setOpen(true)}
            onClose={() => setOpen(false)}
            options={mergedOptions}
            value={selectedOption}
            loading={loading}
            isOptionEqualToValue={(o, v) => o.person_id === v.person_id}
            getOptionLabel={optionLabel}
            filterOptions={(x) => x} // filtrage côté serveur
            onChange={(_e, newValue) => onChange(newValue ? newValue.person_id : null)}
            onInputChange={(_e, v, reason) => {
                if (reason === 'input') setQuery(v);
            }}
            renderInput={(params) => (
                <TextField
                    {...params}
                    label={label}
                    placeholder={placeholder || 'Rechercher une personne IFS…'}
                    InputProps={{
                        ...params.InputProps,
                        endAdornment: (
                            <>
                                {loading ? <CircularProgress color="inherit" size={16} /> : null}
                                {params.InputProps.endAdornment}
                            </>
                        ),
                    }}
                />
            )}
            noOptionsText="Aucune personne trouvée"
            sx={{ minWidth }}
        />
    );
};

export default IfsPersonAutocomplete;
