Require Import LibWfenv Core_Infrastructure
               Source_Definitions Target_Definitions
               Source_Properties Target_Properties.
Require Import CpdtTactics.
Require Import Recdef.

(* for applications where the type argument is irrelevant *)
Definition dummy_type := t_typ_bool.
Definition s_dummy_type := s_typ_bool.

Fixpoint cps_type_trans (s:typ) :=
  match s with
    | s_typ_bool => t_typ_bool
    | s_typ_arrow s1 s2 =>
      t_typ_arrow (t_typ_pair (cps_type_trans s1)
                              (t_typ_arrow (cps_type_trans s2) (t_typ_bvar 1)))
                  (t_typ_bvar 0)
    | _ => typ_bad
  end.

Notation "( s +)" := (cps_type_trans s) (at level 0).

Lemma cps_type_trans_preserves_well_formed_types : forall s,
  s_type s -> t_type (s+).
Proof.
  induction 1; auto.
  simpl. apply_fresh t_type_arrow as X; simpl; auto.
  apply t_type_pair; rewrite* open_tt_rec_t_type.
  apply_fresh t_type_arrow as Y; rewrite* open_tt_rec_t_type.
Qed.

Lemma cps_type_trans_preserves_wft : forall s,
  s_type s -> t_wft empty (s+).
Proof.
  induction 1; auto.
  apply_fresh t_wft_arrow as X; simpl; auto.
  apply t_wft_pair. rewrite* open_tt_rec_t_type. apply* t_wft_weaken.
  apply_fresh t_wft_arrow as Y; simpl; auto.
  repeat rewrite* open_tt_rec_t_type. repeat apply* t_wft_weaken.
Qed.

Lemma cps_type_trans_preserves_wfenv : forall G,
  wfenv s_type G -> wfenv (t_wft empty) (map cps_type_trans G).
Proof.
  apply wfenv_ind.
  rewrite map_empty. apply wfenv_empty.
  intros.
  rewrite map_push.
  apply wfenv_push; auto.
  apply* cps_type_trans_preserves_wft.
Qed.

Definition cps_type_trans_computation (s : typ) :=
  t_typ_arrow (t_typ_arrow (s+) (t_typ_bvar 1)) (t_typ_bvar 0).

Notation "( s %)" := (cps_type_trans_computation s) (at level 0).

Function cps_term_trans (G : env_term)  (e : trm) {measure trm_size e}: trm :=
match e with
| s_trm_fvar v =>
  let s := get v G in
  match s with
  | Some s' =>
    (* λ [σ] k:s+ → α . k [_] x *)
    (t_trm_abs (t_typ_arrow (cps_type_trans s') (t_typ_bvar 0))
               (t_trm_app (t_trm_bvar 0) dummy_type (t_trm_fvar v)))
  | None => trm_bad
  end
| s_trm_true =>
  (* λ [σ] k:bool+ → α . k [_] true *)
  (t_trm_abs (t_typ_arrow (cps_type_trans s_typ_bool) (t_typ_bvar 0))
                     (t_trm_app (t_trm_bvar 0) dummy_type t_trm_true))
| s_trm_false =>
  (* λ [σ] k:bool+ → α . k [_] false *)
  (t_trm_abs (t_typ_arrow (cps_type_trans s_typ_bool) (t_typ_bvar 0))
                     (t_trm_app (t_trm_bvar 0) dummy_type t_trm_false))
| s_trm_abs s1 bdy =>
  (* TODO: write a type inferencer to get s2 *)
  let s2 := s_dummy_type in
  let x := var_gen (fv_ee source bdy) in
  let v := cps_term_trans (G & x ~ s1) (s_open_ee_var bdy x) in
  (* λ [α] k:((σ1 → σ2)+ → α) . *)
  (t_trm_abs (t_typ_arrow (cps_type_trans (s_typ_arrow s1 s2)) (t_typ_bvar 0))
    (* k [_] ... *)
    (t_trm_app (t_trm_bvar 0) dummy_type
      (* (λ [β] pr:(σ1+ ⅹ (σ2+ → β)) . *)
      (t_trm_abs (t_typ_pair (cps_type_trans s1) (t_typ_arrow (cps_type_trans s2) (t_typ_bvar 0)))
        (* TODO: check let projection bvar indices *)
        (* let y = fst pr in let k' = snd pr in *)
        (t_trm_let_fst (t_trm_bvar 0)
          (t_trm_let_snd (t_trm_bvar 1)
            (* (v [β] k') *)
            (t_trm_app v (t_typ_bvar 0) (t_trm_bvar 0)))))))
| s_trm_app e1 e2 =>
  (* TODO: s2 -> s from type inference e1 *)
  let s := s_dummy_type in
  let s2 := s_dummy_type in
  let s_arr_plus := (cps_type_trans (s_typ_arrow s2 s)) in
  let v1 := (cps_term_trans G e1) in
  let v2 := (cps_term_trans G e2) in
  (t_trm_abs
    (* k : s+ -> α *)
    (t_typ_arrow (cps_type_trans s) (t_typ_bvar 0))
    (t_trm_app v1 (t_typ_bvar 0)
      (* λ [_] x1:(σ2→σ)+ . *)
      (t_trm_abs s_arr_plus
        (* v1 [σ] ... *)
        (t_trm_app v2 (t_typ_bvar 1)
          (* λ [_] x2:σ2+ . *)
          (t_trm_abs (cps_type_trans s2)
            (* x1 [σ] (x2, k) *)
            (t_trm_app (t_trm_bvar 1) (t_typ_bvar 2)
              (t_trm_pair (t_trm_bvar 0) (t_trm_bvar 2))))))))

| s_trm_if e e1 e2 =>
  (* TODO: s from type inference of e2 *)
  let s_plus := (cps_type_trans s_dummy_type) in
  let v := (cps_term_trans G e) in
  let v1 := (cps_term_trans G e1) in
  let v2 := (cps_term_trans G e2) in
  (* λ [α] k:(σ+ → α) . ...*)
  (t_trm_abs (t_typ_arrow s_plus (t_typ_bvar 0))
    (* v [σ] ... *)
    (t_trm_app v (t_typ_bvar 0)
      (* λ [_] x:bool . if x then (v1 [α] k) else (v2 [α] k) *)
      (t_trm_abs t_typ_bool
        (t_trm_if (t_trm_bvar 0)
          (t_trm_app v1 (t_typ_bvar 0) (t_trm_bvar 1))
          (t_trm_app v2 (t_typ_bvar 0) (t_trm_bvar 1))))))


| _ => trm_bad
end.
(* termination proof *)
  (* abs case *)
  intros. simpl. pick_fresh x. rewrite* s_trm_size_open_var. crush.
  (* if case *)
  crush. crush. crush.
  (* app case *)
  crush. crush.
Defined.

Inductive cps_trans : env_term -> trm -> typ -> trm -> Prop :=
  | cps_trans_var : forall G x s, wfenv s_type G -> binds x s G ->
    cps_trans G (s_trm_fvar x) s
      (t_trm_abs (t_typ_arrow (s+) (t_typ_bvar 1))
        (t_trm_app (t_trm_bvar 0) dummy_type (t_trm_fvar x)))
  | cps_trans_true : forall G, wfenv s_type G ->
    cps_trans G s_trm_true s_typ_bool
      (t_trm_abs (t_typ_arrow t_typ_bool (t_typ_bvar 1))
        (t_trm_app (t_trm_bvar 0) dummy_type t_trm_true))
  | cps_trans_false : forall G, wfenv s_type G ->
    cps_trans G s_trm_false s_typ_bool
      (t_trm_abs (t_typ_arrow t_typ_bool (t_typ_bvar 1))
        (t_trm_app (t_trm_bvar 0) dummy_type t_trm_false))
  | cps_trans_abs : forall L G e s1 s2 u,
      (forall x, x \notin L ->
        cps_trans (G & x ~ s1) (s_open_ee_var e x) s2 (open_ee_rec target 1 (t_trm_fvar x) u)) ->
      s_type s1 ->
      cps_trans G (s_trm_abs s1 e) (s_typ_arrow s1 s2)
        (t_trm_abs (*A*)
                   (*k*)(t_typ_arrow ((s_typ_arrow s1 s2)+) (t_typ_bvar 1))
          (t_trm_app (*k*)(t_trm_bvar 0) dummy_type
            (t_trm_abs (*B*)
                       (*p*) (t_typ_pair (s1+) (t_typ_arrow (s2+) (t_typ_bvar 1)))
              (t_trm_let_fst (t_trm_bvar 0) (* let x = fst p in *)
                (t_trm_let_snd (t_trm_bvar 1) (* let k' = snd p in *)
                  (t_trm_app u (*B*)(t_typ_bvar 0) (*k'*)(t_trm_bvar 0)))))))
  | cps_trans_if : forall G e1 e2 e3 s u1 u2 u3,
      cps_trans G e1 s_typ_bool u1 ->
      cps_trans G e2 s u2 -> cps_trans G e3 s u3 ->
      cps_trans G (s_trm_if e1 e2 e3) s
        (t_trm_abs (*A*) (*k*)(t_typ_arrow (s+) (t_typ_bvar 1))
          (t_trm_app u1 (t_typ_bvar 0)
            (t_trm_abs (*x*)t_typ_bool
              (t_trm_if (t_trm_bvar 0)
                (t_trm_app u2 (t_typ_bvar 1) (t_trm_bvar 1))
                (t_trm_app u3 (t_typ_bvar 1) (t_trm_bvar 1))))))
  | cps_trans_app : forall G e1 e2 s1 s2 u1 u2,
      cps_trans G e1 (s_typ_arrow s1 s2) u1 -> cps_trans G e2 s1 u2 ->
      cps_trans G (s_trm_app e1 e2) s2
        (t_trm_abs (*A*) (*k*)(t_typ_arrow (s2+) (t_typ_bvar 1))
          (t_trm_app u1 (t_typ_bvar 0)
            (t_trm_abs (*x1*)((s_typ_arrow s1 s2)+)
              (t_trm_app u2 (t_typ_bvar 1)
                (t_trm_abs (*x2*)(s1+)
                  (t_trm_app (t_trm_bvar 1) (t_typ_bvar 2)
                    (t_trm_pair (t_trm_bvar 0) (t_trm_bvar 2)))))))).

(* compiler only defined on well-typed source terms *)
Lemma cps_trans_implies_s_typing : forall G e s u,
  cps_trans G e s u -> s_typing G e s.
Proof. induction 1; eauto. Qed.

(* hints for following lemma *)
Hint Local Resolve
     cps_type_trans_preserves_wfenv 
     cps_type_trans_preserves_wft
     cps_type_trans_preserves_well_formed_types
     (wfenv_binds s_type)
     cps_trans_implies_s_typing
     t_wft_weaken.

Ltac prove_app :=
  match goal with
    | [ |- t_typing (empty & ?X ~ star) _ (t_trm_app _ _ _) _] =>
      replace (t_typ_fvar X) with (open_tt (t_typ_fvar X) dummy_type); auto;
      apply* t_typing_app end.

Ltac simplify_t_wft_arrow :=
  let Y := fresh "Y" in
    apply_fresh t_wft_arrow as Y; simpl; repeat rewrite* open_tt_rec_t_type; try apply* t_wft_var.

Ltac prove_t_wft :=
  match goal with
    | [ |- t_wft _ (t_typ_arrow _ _)] => simplify_t_wft_arrow; prove_t_wft
    | [ |- t_wft _ (t_typ_pair _ _)] => apply* t_wft_pair; prove_t_wft
    | [ |- (t_wft _ _)] =>
      apply* t_wft_weaken; repeat apply* ok_push; auto using cps_type_trans_preserves_wft; prove_t_wft end.

Ltac prove_t_value_typing :=
  match goal with
    | [ |- t_value_typing _ _ (t_trm_fvar _) _] => apply* t_value_typing_var
    | [ |- t_value_typing _ _ t_trm_true _] => apply* t_value_typing_true
    | [ |- t_value_typing _ _ t_trm_false _] => apply* t_value_typing_false
    | [ |- t_value_typing _ _ (t_trm_abs _ _) _] =>
      let y := fresh "y" in apply_fresh* t_value_typing_abs as y; intros; simpl end;
  repeat rewrite* open_tt_rec_t_type;
  repeat apply wfenv_push; try apply (wfenv_implies (t_wft empty)); auto;
  try apply cps_type_trans_preserves_wfenv; try apply* s_typing_implies_wfenv;
  try prove_t_wft.

(* type-preserving compilation *)
Lemma cps_trans_implies_t_typing : forall G e s u,
  cps_trans G e s u -> t_value_typing empty (map cps_type_trans G) u (s%).
Proof.
  induction 1;
  apply_fresh* t_value_typing_abs as k; (* all cases start with lambda k. _ *)
  try solve [apply* cps_type_trans_preserves_wfenv; apply* s_typing_implies_wfenv];
  intros; simpl;
  rename x into k. (* I dunno why the "as k" above doesn't work but whatever *)

  (* variable case *)
  prove_app; prove_t_value_typing.

  (* true case *)
  prove_app; prove_t_value_typing.

  (* false case *)
  prove_app; prove_t_value_typing.

  (* abs case *)
  assert (s_type s2).
    apply* s_typing_implies_s_type. apply* cps_trans_implies_s_typing. apply* (H k).
  repeat rewrite* open_tt_rec_t_type. unfold inc_if_eq. simpl.
  prove_app; simpl. (* k (lambda ...) *)
    (* k *)
    prove_t_value_typing.

    (* (lambda ...) *)
    simpl. repeat rewrite* open_tt_rec_t_type. prove_t_value_typing.
    apply_fresh t_typing_let_fst as x; simpl. prove_t_value_typing.
    apply_fresh t_typing_let_snd as k'; simpl. prove_t_value_typing.
    replace (t_typ_fvar X0) with (open_tt (t_typ_bvar 0) (t_typ_fvar X0)); auto.
    unfold inc_if_eq. cases_if*.
    apply t_typing_app with (t1 := t_typ_arrow (s2+) (t_typ_bvar 1));
    auto; simpl; repeat rewrite* open_tt_rec_t_type.
    rewrite* open_ee_rec_t_term;
    rewrite* t_open_ee_rec_open_te_rec; rewrite* open_te_rec_t_term;
    rewrite* t_open_ee_rec_open_ee_rec; rewrite* open_ee_rec_t_term;
    rewrite* t_open_ee_rec_open_te_rec; rewrite* open_te_rec_t_term;
    rewrite* t_open_ee_rec_open_ee_rec; rewrite* open_ee_rec_t_term.
    apply t_value_typing_weaken.
    apply t_value_typing_weaken_generalized. apply t_value_typing_weaken_generalized.
    repeat apply* t_value_typing_weaken_delta.
    rewrite <- map_push.
    apply* H0.
    (* clean up after all those weakens *)
    repeat apply wfenv_push; auto. apply* (wfenv_implies (t_wft empty)).
    apply cps_type_trans_preserves_wfenv. apply* s_typing_implies_wfenv.
    prove_t_wft.

    repeat apply wfenv_push; auto. apply* (wfenv_implies (t_wft empty)).
    apply cps_type_trans_preserves_wfenv. apply* s_typing_implies_wfenv.
    prove_t_wft. prove_t_wft.
 
    repeat apply wfenv_push; auto. apply* (wfenv_implies (t_wft empty)).
    apply cps_type_trans_preserves_wfenv. apply* s_typing_implies_wfenv.
    prove_t_wft. prove_t_wft. prove_t_wft.

    (* ok on to k' finally *)
    prove_t_value_typing.

  (* if case *)
  assert (s_type s). apply* s_typing_implies_s_type.
  replace (t_typ_fvar X) with (open_tt (t_typ_bvar 0) (t_typ_fvar X)); auto.
  apply* t_typing_app; simpl.
    (* u1 *)
    rewrite* open_ee_rec_t_term. rewrite* open_te_rec_t_term. rewrite* open_tt_rec_t_type.
    apply* t_value_typing_weaken. apply* t_value_typing_weaken_delta. apply wfenv_push; auto.
      apply (wfenv_implies (t_wft empty)); auto;
        apply cps_type_trans_preserves_wfenv; apply* s_typing_implies_wfenv.
      prove_t_wft.
    
    (* if x then u2 else u3 *)
    unfold inc_if_eq. cases_if*.
    prove_t_value_typing. apply* t_typing_if; try prove_t_value_typing;
    replace (t_typ_fvar X) with (open_tt (t_typ_bvar 0) (t_typ_fvar X)); auto;
    apply* t_typing_app; simpl;
    try (rewrite* open_te_rec_t_term; rewrite* open_ee_rec_t_term;
         rewrite* open_te_rec_t_term; rewrite* open_ee_rec_t_term;
         repeat apply* t_value_typing_weaken; try solve [repeat apply* t_value_typing_weaken_delta];
         repeat apply wfenv_push; auto; try prove_t_wft; apply (wfenv_implies (t_wft empty)); auto;
         apply cps_type_trans_preserves_wfenv; apply* s_typing_implies_wfenv);
    simpl; prove_t_value_typing.

  (* app case *)
  assert (s_type s1). apply* s_typing_implies_s_type.
  assert (s_type s2). apply* s_typing_implies_s_type.
  replace (t_typ_fvar X) with (open_tt (t_typ_bvar 0) (t_typ_fvar X)); auto.
  apply* t_typing_app; simpl.
    (* u1 *)
    rewrite* open_ee_rec_t_term. rewrite* open_te_rec_t_term. rewrite* open_tt_rec_t_type.
    apply* t_value_typing_weaken. apply* t_value_typing_weaken_delta. apply wfenv_push; auto.
      apply (wfenv_implies (t_wft empty)); auto;
        apply cps_type_trans_preserves_wfenv; apply* s_typing_implies_wfenv.
      prove_t_wft.
    
    (* u2 *)
    unfold inc_if_eq. cases_if*.
    prove_t_value_typing.
    replace (t_typ_fvar X) with (open_tt (t_typ_bvar 0) (t_typ_fvar X)); auto.
    apply* t_typing_app; simpl.
    rewrite* open_te_rec_t_term; rewrite* open_ee_rec_t_term;
    rewrite* open_te_rec_t_term; rewrite* open_ee_rec_t_term.
    repeat apply* t_value_typing_weaken; try solve [repeat apply* t_value_typing_weaken_delta];
    repeat apply wfenv_push; auto; try prove_t_wft; apply (wfenv_implies (t_wft empty)); auto;
    apply cps_type_trans_preserves_wfenv; apply* s_typing_implies_wfenv.
    
    (* x1 x2 *)
    simpl. rewrite* open_tt_rec_t_type. prove_t_value_typing.
    replace (t_typ_fvar X) with (open_tt (t_typ_bvar 0) (t_typ_fvar X)); auto.
    apply* t_typing_app; simpl. prove_t_value_typing. simpl. apply* t_value_typing_pair; prove_t_value_typing.
Qed.
