Require Import floyd.proofauto.
Require Import progs.nest3.

Local Open Scope logic.

Definition get_spec :=
 DECLARE _get
  WITH v : reptype' t_struct_c
  PRE  [] 
         PROP () LOCAL()
        SEP(`(data_at Ews t_struct_c (repinj _ v)) (eval_var _p t_struct_c))
  POST [ tint ]
         PROP() (LOCAL (`(eq (Vint (snd (snd (snd v))))) (eval_id 1%positive))
         SEP (`(data_at Ews t_struct_c (repinj _ v)) (eval_var _p t_struct_c))).

Definition update222 (i: int) (v: reptype' t_struct_c) : reptype' t_struct_c :=
   (fst v, (fst (snd v), (fst (snd (snd v)), i))).

Definition set_spec :=
 DECLARE _set
  WITH i : int, v : reptype' t_struct_c
  PRE  [ _i OF tint ] 
         PROP () LOCAL(`(eq (Vint i)) (eval_id _i))
        SEP(`(data_at Ews t_struct_c (repinj _ v)) (eval_var _p t_struct_c))
  POST [ tvoid ]
        `(data_at Ews t_struct_c (repinj _ (update222 i v))) (eval_var _p t_struct_c).

Definition Vprog : varspecs := (_p, t_struct_c)::nil.

Definition Gprog : funspecs := 
    get_spec::set_spec::nil.

Definition Gtot := do_builtins (prog_defs prog) ++ Gprog.

Lemma body_get:  semax_body Vprog Gtot f_get get_spec.
Proof.
 start_function.
name i _i.
apply (remember_value (eval_var _p t_struct_c)); intro p.
simpl_data_at.
 fold t_struct_a.
forward.
forward.
erewrite elim_globals_only by (split3; [eassumption | reflexivity.. ]).
simpl_data_at.
cancel.
Qed.

Lemma body_set:  semax_body Vprog Gtot f_set set_spec.
Proof.
 start_function.
name i_ _i.
apply (remember_value (eval_var _p t_struct_c)); intro p.
simpl_data_at.
forward.
forward.
unfold at_offset, id; fold t_struct_a; simpl.
erewrite elim_globals_only by (split3; [eassumption | reflexivity.. ]).
forget (eval_var _p t_struct_c rho) as p.
simpl_data_at.
fold t_struct_a.
cancel.
Qed.