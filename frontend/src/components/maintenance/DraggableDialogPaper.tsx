import React, { useRef, useState } from 'react';
import { Paper, PaperProps } from '@mui/material';

/**
 * Paper de <Dialog> deplacable a la souris par sa barre de titre.
 *
 * Demande metier (2026-09-17) : la fenetre « Ajouter un poste technique »
 * s'ouvre au milieu de l'ecran IH02 et cache les noms de l'arbre qu'on veut
 * recopier. Sans dependance (react-draggable n'est pas dans le projet) :
 * des evenements pointeur sur le Paper, actifs uniquement quand le geste part
 * de l'element portant `id={DRAG_HANDLE_ID}` (le DialogTitle) et hors de ses
 * boutons/champs. Le decalage est un simple translate() ; il repart de zero
 * a chaque ouverture car MUI demonte le Paper a la fermeture.
 *
 * Usage :
 *   <Dialog PaperComponent={DraggableDialogPaper} ...>
 *     <DialogTitle id={DRAG_HANDLE_ID} sx={{ cursor: 'move' }}>...
 */
export const DRAG_HANDLE_ID = 'draggable-dialog-handle';

interface DragState {
  pointerId: number;
  startX: number;
  startY: number;
  baseX: number;
  baseY: number;
}

const DraggableDialogPaper: React.FC<PaperProps> = ({ style, ...props }) => {
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const drag = useRef<DragState | null>(null);

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    const target = e.target as HTMLElement;
    if (e.button !== 0 || !target.closest(`#${DRAG_HANDLE_ID}`)) return;
    // Un clic sur un bouton ou un champ du titre garde son comportement.
    if (target.closest('button, input, textarea, a, [role="button"]')) return;
    drag.current = { pointerId: e.pointerId, startX: e.clientX, startY: e.clientY, baseX: offset.x, baseY: offset.y };
    e.currentTarget.setPointerCapture(e.pointerId);
    e.preventDefault();
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const d = drag.current;
    if (!d || d.pointerId !== e.pointerId) return;
    setOffset({ x: d.baseX + (e.clientX - d.startX), y: d.baseY + (e.clientY - d.startY) });
  };

  const onPointerEnd = (e: React.PointerEvent<HTMLDivElement>) => {
    if (drag.current?.pointerId !== e.pointerId) return;
    drag.current = null;
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId);
  };

  return (
    <Paper
      {...props}
      style={{ ...style, transform: `translate(${offset.x}px, ${offset.y}px)` }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerEnd}
      onPointerCancel={onPointerEnd}
    />
  );
};

export default DraggableDialogPaper;
