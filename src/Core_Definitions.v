(********************************************************
 * Core source/target/combined language definitions     *
 * from Ahmed & Blume ICFP 2011                         *
 * William J. Bowman, Phillip Mates & James T. Perconti *
 ********************************************************)

Set Implicit Arguments.
Require Import LibLN.
Implicit Type x : var.
Implicit Type X : var.

(* Syntax of pre-types *)

Inductive typ : Set :=
  (* Source types *)
  | s_typ_bool : typ                    (* bool *)
  | s_typ_arrow : typ -> typ -> typ (* s -> s *)

  (* Target types *)
  | t_typ_bool : typ                    (* bool *)
  | t_typ_pair : typ -> typ -> typ  (* t x t *)
  | t_typ_bvar : nat -> typ             (* n *)
  | t_typ_fvar : var -> typ             (* X *)
  | t_typ_arrow : typ -> typ -> typ (* forall . t -> t *).

(* Syntax of pre-terms *)

Inductive trm : Set :=
  (* source values *)
  | s_trm_bvar : nat -> trm
  | s_trm_fvar : var -> trm
  | s_trm_true : trm
  | s_trm_false : trm
  | s_trm_abs : typ -> trm -> trm
  (* source non-values *)
  | s_trm_if : trm -> trm -> trm -> trm
  | s_trm_app : trm -> trm -> trm

  (* target values *)
  | t_trm_bvar  : nat -> trm
  | t_trm_fvar  : var -> trm
  | t_trm_true  : trm
  | t_trm_false : trm
  | t_trm_pair  : trm -> trm -> trm
  | t_trm_abs   : typ -> trm -> trm
  (* target non-values *)
  | t_trm_if    : trm -> trm -> trm -> trm
  (* let 0 be 1st proj of pair in body *)
  | t_trm_let_fst : trm -> trm -> trm
  (* let 0 be 2nd proj of pair in body *)
  | t_trm_let_snd : trm -> trm -> trm
  | t_trm_app   : trm -> typ -> trm -> trm
  (* Boundary Terms *)
  | st_trm : trm -> typ -> trm
  | ts_trm : trm -> typ -> trm -> trm.

(* Opening up a type binder occuring in a type *)
Fixpoint open_tt_rec (K : nat) (U : typ) (T : typ) {struct T} : typ :=
  match T with
  | s_typ_bool        => T
  | s_typ_arrow _ _   => T
  | t_typ_bool        => T
  | t_typ_pair T1 T2  => t_typ_pair (open_tt_rec K U T1)
                                    (open_tt_rec K U T2)
  | t_typ_bvar J      => If K = J then U else (t_typ_bvar J)
  | t_typ_fvar X      => T
  | t_typ_arrow T1 T2 => t_typ_arrow (open_tt_rec (S K) U T1)
                                     (open_tt_rec (S K) U T2)
  end.

Definition open_tt T U := open_tt_rec 0 U T.

(** Opening up a type binder occuring in a term *)

Fixpoint open_te_rec (K : nat) (U : typ) (e : trm) {struct e} : trm :=
  match e with
  | s_trm_bvar i      => s_trm_bvar i
  | s_trm_fvar x      => s_trm_fvar x
  | s_trm_true        => s_trm_true
  | s_trm_false       => s_trm_false
  | s_trm_abs t e1    => s_trm_abs (open_tt_rec (S K) U t) (open_te_rec (S K) U e1)
  | s_trm_if v e1 e2  => s_trm_if (open_te_rec K U v)
                                  (open_te_rec K U e1)
                                  (open_te_rec K U e2)
  | s_trm_app e1 e2   => s_trm_app (open_te_rec K U e1)
                                   (open_te_rec K U e2)
  | t_trm_bvar i      => t_trm_bvar i
  | t_trm_fvar x      => t_trm_fvar x
  | t_trm_true        => t_trm_true
  | t_trm_false       => t_trm_false
  | t_trm_pair v1 v2  => t_trm_pair (open_te_rec K U v1) (open_te_rec K U v2)
  | t_trm_abs t e1    => t_trm_abs (open_tt_rec (S K) U t) (open_te_rec (S K) U e1)
  | t_trm_if v e1 e2  => t_trm_if (open_te_rec K U v)
                                  (open_te_rec K U e1)
                                  (open_te_rec K U e2)
  | t_trm_let_fst v e => t_trm_let_fst (open_te_rec K U v)
                                       (open_te_rec K U e)
  | t_trm_let_snd v e => t_trm_let_snd (open_te_rec K U v)
                                       (open_te_rec K U e)
  | t_trm_app e1 t e2 => t_trm_app (open_te_rec K U e1)
                                   (open_tt_rec K U t)
                                   (open_te_rec K U e2)
  | st_trm e t       => st_trm (open_te_rec K U e)
                               (open_tt_rec K U t)
  | ts_trm e1 t e2   => ts_trm (open_te_rec K U e1)
                               (open_tt_rec K U t)
                               (open_te_rec K U e2)
  end.

Definition open_te t U := open_te_rec 0 U t.

(** Opening up a term binder occuring in a term *)

Fixpoint open_ee_rec (k : nat) (f : trm) (e : trm) {struct e} : trm :=
  match e with
  | s_trm_bvar i      => If k = i then f else (s_trm_bvar i)
  | s_trm_fvar x      => s_trm_fvar x
  | s_trm_true        => s_trm_true
  | s_trm_false       => s_trm_false
  | s_trm_abs t e1    => s_trm_abs t (open_ee_rec (S k) f e1)
  | s_trm_if v e1 e2  => s_trm_if (open_ee_rec k f v)
                                  (open_ee_rec k f e1)
                                  (open_ee_rec k f e2)
  | s_trm_app e1 e2   => s_trm_app (open_ee_rec k f e1)
                                   (open_ee_rec k f e2)
  | t_trm_bvar i      => If k = i then f else (t_trm_bvar i)
  | t_trm_fvar x      => t_trm_fvar x
  | t_trm_true        => t_trm_true
  | t_trm_false       => t_trm_false
  | t_trm_pair v1 v2  => t_trm_pair (open_ee_rec k f v1) (open_ee_rec k f v2)
  | t_trm_abs t e1    => t_trm_abs t (open_ee_rec (S k) f e1)
  | t_trm_if v e1 e2  => t_trm_if (open_ee_rec k f v)
                                  (open_ee_rec k f e1)
                                  (open_ee_rec k f e2)
  | t_trm_let_fst v e => t_trm_let_fst (open_ee_rec k f v)
                                       (open_ee_rec (S k) f e)
  | t_trm_let_snd v e => t_trm_let_snd (open_ee_rec k f v)
                                       (open_ee_rec (S k) f e)
  | t_trm_app e1 t e2 => t_trm_app (open_ee_rec k f e1)
                                   t
                                   (open_ee_rec k f e2)
  | st_trm e t        => st_trm (open_ee_rec k f e) t
  | ts_trm e1 t e2    => ts_trm (open_ee_rec k f e1) t (open_ee_rec k f e2)
  end.

Definition open_ee t u := open_ee_rec 0 u t.

(** Notation for opening up binders with type or term variables *)

(* changing type vars in a term *)
Definition t_open_te_var e X := (open_te e (t_typ_fvar X)).
(* changing type vars in a type *)
Definition t_open_tt_var T X := (open_tt T (t_typ_fvar X)).
(* changing a term var in a term *)
Definition s_open_ee_var e x := (open_ee e (s_trm_fvar x)).
Definition t_open_ee_var e x := (open_ee e (t_trm_fvar x)).

(* Syntax of types *)
Inductive t_type : typ -> Prop :=
  | t_type_bool :
      t_type t_typ_bool
  | t_type_pair : forall T1 T2,
      t_type T1 -> t_type T2 -> t_type (t_typ_pair T1 T2)
  | t_type_var : forall X,
      t_type (t_typ_fvar X)
  | t_type_arrow : forall L T1 T2,
      (forall X, X \notin L ->
        t_type (t_open_tt_var T1 X)) ->
      (forall X, X \notin L -> t_type (t_open_tt_var T2 X)) ->
      t_type (t_typ_arrow T1 T2).

Inductive s_type : typ -> Prop :=
  | s_type_bool : s_type s_typ_bool
  | s_type_arrow : forall T1 T2, s_type (s_typ_arrow T1 T2).


Inductive type : typ -> Prop :=
  | type_t : forall t, t_type t -> type t
  | type_s : forall t, s_type t -> type t.


(* Source terms *)
Inductive s_term : trm -> Prop :=
  | s_term_value : forall v, s_value v -> s_term v
  | s_term_if : forall e1 e2 e3,
      s_term e1 -> s_term e2 -> s_term e3 ->
      s_term (s_trm_if e1 e2 e3)
  | s_term_app : forall e1 e2,
      s_term e1 -> s_term e2 ->
      s_term (s_trm_app e1 e2)

with s_value : trm -> Prop :=
  | s_value_var : forall x, s_value (s_trm_fvar x)
  | s_value_true : s_value s_trm_true
  | s_value_false : s_value s_trm_false
  | s_value_abs  : forall L T e,
      (forall x, x \notin L -> s_term (s_open_ee_var e x)) ->
      s_value (s_trm_abs T e).

Scheme s_term_mut := Induction for s_term Sort Prop
with s_value_mut := Induction for s_value Sort Prop.

(* Target terms *)
Inductive t_term : trm -> Prop :=
  | t_term_value : forall v, t_value v -> t_term v
  | t_term_if : forall v e1 e2,
      t_value v ->
      t_term e1 ->
      t_term e2 ->
      t_term (t_trm_if v e1 e2)
  | t_term_let_fst : forall L v e,
      t_value v ->
      (forall x, x \notin L -> t_term (t_open_ee_var e x)) ->
      t_term (t_trm_let_fst v e)
  | t_term_let_snd : forall L v e,
      t_value v ->
      (forall x, x \notin L -> t_term (t_open_ee_var e x)) ->
      t_term (t_trm_let_snd v e)
  | t_term_app : forall T v1 v2,
      t_value v1 ->
      t_type T ->
      t_value v2 ->
      t_term (t_trm_app v1 T v2)

with t_value : trm -> Prop :=
  | t_value_var : forall x,
      t_value (t_trm_fvar x)
  | t_value_true : t_value t_trm_true
  | t_value_false : t_value t_trm_false
  | t_value_pair : forall v1 v2,
      t_value v1 -> t_value v2 -> t_value (t_trm_pair v1 v2)
  | t_value_abs  : forall L T e1,
      (forall X, X \notin L ->
        t_type (t_open_tt_var T X)) ->
      (forall x X, x \notin L -> X \notin L ->
        t_term (t_open_te_var (t_open_ee_var e1 x) X)) ->
      t_value (t_trm_abs T e1).

Scheme t_term_mut := Induction for t_term Sort Prop
with t_value_mut := Induction for t_value Sort Prop.

(* Multi-language terms *)
Inductive term : trm -> Prop :=
  | term_t : forall t, t_term t -> term t
  | term_s : forall t, s_term t -> term t.

(* TODO: Environments *)
(* TODO: Contexts *)
(* TODO: Reduction rules *)
(* TODO: Equivalence *)
