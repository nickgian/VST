Require Import floyd.proofauto.
Require Import progs.list_dt. Import Links.
Require Import progs.queue.

Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition t_struct_elem := Tstruct _elem noattr.
Definition t_struct_fifo := Tstruct _fifo noattr.


Instance QS: listspec _elem _next. 
Proof. eapply mk_listspec; reflexivity. Defined.

Lemma isnil: forall {T: Type} (s: list T), {s=nil}+{s<>nil}.
Proof. intros. destruct s; [left|right]; auto. intro Hx; inv Hx. Qed.

Definition natural_alignment := 8.

Definition malloc_compatible (n: Z) (p: val) : Prop :=
  match p with
  | Vptr b ofs => (natural_alignment | Int.unsigned ofs) /\
                           Int.unsigned ofs + n < Int.modulus
  | _ => False
  end.

Lemma malloc_compatible_field_compatible:
  forall (cs: compspecs) t p n,
     sizeof t = n ->
     legal_alignas_type t = true ->
     legal_cosu_type t = true ->
     complete_type cenv_cs t = true ->
     (alignof t | natural_alignment) ->
     malloc_compatible n p ->
     field_compatible t nil p.
Proof.
intros.
subst n.
destruct p; simpl in *; try contradiction.
destruct H4.
pose proof (Int.unsigned_range i).
repeat split; simpl; auto; try omega.
clear - H3 H.
eapply Zdivides_trans; eauto.
Qed.

Definition Qsh : share := fst (Share.split Share.Lsh).
Definition Qsh' := Share.lub (snd (Share.split Share.Lsh)) Share.Rsh.

Lemma readable_share_Qsh': readable_share Qsh'.
Proof.
unfold readable_share, Qsh'.
rewrite Share.distrib1.
rewrite Share.glb_idem.
rewrite Share.lub_commute.
rewrite Share.lub_absorb.
apply readable_nonidentity.
apply writable_readable.
apply Share.contains_Rsh_e.
apply sepalg.join_sub_refl.
Qed.  (* share hacking *)

Lemma Qsh_not_readable: ~ readable_share Qsh.
Proof.
unfold Qsh, readable_share; intro.
unfold nonempty_share in H.
apply H; clear H.
assert (Share.glb Share.Rsh (fst (Share.split Share.Lsh)) = Share.bot).
apply sub_glb_bot with Share.Lsh.
exists (snd (Share.split Share.Lsh)).
apply split_join.
destruct (Share.split Share.Lsh); reflexivity.
unfold Share.Rsh, Share.Lsh.
rewrite Share.glb_commute.
apply glb_split.
rewrite H.
apply bot_identity.
Qed.

Hint Resolve Qsh_not_readable. 

Lemma Qsh_nonempty: Qsh <> Share.bot.
Proof.
unfold Qsh; intro.
destruct (Share.split Share.Lsh) eqn:?H.
simpl in H.
apply Share.split_nontrivial in H0; auto.
unfold Share.Lsh in H0; clear - H0.
destruct (Share.split Share.top) eqn:?H.
simpl in H0.
apply Share.split_nontrivial in H; auto.
apply Share.nontrivial in H.
auto.
Qed.

Hint Resolve Qsh_nonempty : valid_pointer.

Lemma Qsh_nonidentity: sepalg.nonidentity Qsh.
Proof.
  intro.
  apply identity_share_bot in H.
  apply Qsh_nonempty in H.
  auto.
Qed.

Hint Resolve Qsh_nonidentity : valid_pointer.

Lemma Qsh_Qsh': sepalg.join Qsh Qsh' Tsh.
Proof.
unfold Qsh, Qsh', Share.Lsh, Share.Rsh.
destruct (Share.split Share.top) as [a c] eqn:?H.
simpl.
destruct (Share.split a) as [x y] eqn:?H.
simpl.
pose proof (Share.split_disjoint x y a H0).
pose proof (Share.split_disjoint _ _ _ H).
split.
rewrite Share.distrib1.
rewrite H1.
rewrite Share.lub_commute, Share.lub_bot.
replace x with (Share.glb x a).
rewrite Share.glb_assoc. rewrite H2.
apply Share.glb_bot.
clear - H0.
apply split_join in H0. destruct H0.
subst a.
apply Share.glb_absorb.
rewrite <- Share.lub_assoc.
apply split_join in H0. destruct H0.
rewrite H3.
apply split_join in H. destruct H.
apply H4.
Qed.

Lemma field_at_list_cell_weak:
  forall sh i j p, 
   readable_share sh ->
  field_at sh list_struct [StructField _a] i p *
  field_at sh list_struct [StructField _b] j p *
  field_at_ sh list_struct [StructField _next] p
  = list_cell QS sh (i,j) p *
  field_at_ sh list_struct [StructField _next] p.
Proof.
intros.
(* new version of proof, for constructive definition of list_cell *)
f_equal.
unfold field_at, list_cell.
autorewrite with gather_prop.
f_equal.
apply ND_prop_ext.
rewrite field_compatible_cons; simpl.
rewrite field_compatible_cons; simpl.
intuition.
+ left; auto.
+ right; left; auto.
Qed.

Lemma make_unmake:
 forall a b p,
 field_at Tsh t_struct_elem [] (Vint a, (Vint b, Vundef)) p =
 field_at Qsh' t_struct_elem [StructField _a] (Vint a) p *
 field_at Qsh' t_struct_elem [StructField _b] (Vint b) p *
 list_cell QS Qsh (Vundef, Vundef) p *
 field_at_ Tsh t_struct_elem [StructField _next] p.
Proof.
intros.
unfold_field_at 1%nat.
rewrite <- !sepcon_assoc.
match goal with |- ?A = _ => set (J := A) end.
unfold field_at_.
(*BUG in Coq 8.4pl6:  if you uncomment the "change" line just below,
  then the "rewrite" fails.  This is
 probably related to the ordering of type-checking and type-class
 resolution; if the "rewrite" is filled in with all implicit
  type-class arguments, then it succeeds.
change (default_val (nested_field_type t_struct_elem [StructField _next])) with Vundef. *)
rewrite <- (field_at_share_join _ _ _ _ _ _ _ Qsh_Qsh').
change (default_val (nested_field_type t_struct_elem [StructField _next])) with Vundef.
rewrite <- !sepcon_assoc.
pull_left (field_at Qsh' t_struct_elem [StructField _next] Vundef p).
pull_left (field_at Qsh' t_struct_elem [StructField _b] (Vint b) p).
pull_left (field_at Qsh' t_struct_elem [StructField _a] (Vint a) p).
rewrite field_at_list_cell_weak  by apply readable_share_Qsh'.
match goal with |- _ = _ * _ * _ * ?A => change A
  with (field_at_ Qsh t_struct_elem [StructField _next] p)
end.
pull_left (list_cell QS Qsh (Vundef, Vundef) p).
rewrite join_cell_link with (psh:=Tsh) by (auto; try apply Qsh_Qsh'; apply readable_share_Qsh').
subst J.
match goal with |- _ * _ * ?A = _ => change A
  with (field_at_ Tsh t_struct_elem [StructField _next] p)
end.
rewrite field_at_list_cell_weak by auto.
rewrite sepcon_assoc.
f_equal.
unfold field_at_.
change (default_val (nested_field_type t_struct_elem [StructField _next])) with Vundef.
rewrite sepcon_comm.
symmetry.
apply (field_at_share_join _ _ _ t_struct_elem [StructField _next] Vundef p Qsh_Qsh').
Qed.

Definition mallocN_spec :=
 DECLARE _mallocN
  WITH n: Z
  PRE [ 1%positive OF tint]
     PROP (4 <= n <= Int.max_unsigned) 
     LOCAL (temp 1%positive (Vint (Int.repr n)))
     SEP ()
  POST [ tptr tvoid ] 
     EX v: val,
     PROP (malloc_compatible n v) 
     LOCAL (temp ret_temp v) 
     SEP (memory_block Tsh n v).

Definition freeN_spec :=
 DECLARE _freeN
  WITH p : val , n : Z
  PRE [ 1%positive OF tptr tvoid , 2%positive OF tint]  
     (* we should also require natural_align_compatible (eval_id 1) *)
      PROP() LOCAL (temp 1%positive p; temp 2%positive (Vint (Int.repr n)))
      SEP (memory_block Tsh n p)
  POST [ tvoid ]  
    PROP () LOCAL () SEP ().


Definition elemrep (rep: elemtype QS) (p: val) : mpred :=
  field_at Tsh t_struct_elem [StructField _a] (fst rep) p * 
  (field_at Tsh t_struct_elem [StructField _b] (snd rep) p *
   (field_at_ Tsh t_struct_elem [StructField _next]) p).

Definition fifo (contents: list val) (p: val) : mpred :=
  (EX ht: (val*val), let (hd,tl) := ht in
      !! is_pointer_or_null hd && !! is_pointer_or_null tl &&
      data_at Tsh t_struct_fifo (hd, tl) p *
      if isnil contents
      then (!!(hd=nullval) && emp)
      else (EX prefix: list val, 
              !!(contents = prefix++tl::nil)
            &&  (lseg QS Qsh Tsh prefix hd tl
                   * list_cell QS Qsh (Vundef,Vundef) tl
                   * field_at Tsh t_struct_elem [StructField _next] nullval tl)))%logic.

Definition fifo_new_spec :=
 DECLARE _fifo_new
  WITH u : unit
  PRE  [  ]
       PROP() LOCAL() SEP ()
  POST [ (tptr t_struct_fifo) ] 
    EX v:val, PROP() LOCAL(temp ret_temp v) SEP (fifo nil v).

Definition fifo_put_spec :=
 DECLARE _fifo_put
  WITH q: val, contents: list val, p: val
  PRE  [ _Q OF (tptr t_struct_fifo) , _p OF (tptr t_struct_elem) ]
          PROP () LOCAL (temp _Q q; temp _p p) 
          SEP (fifo contents q;
                 list_cell QS Qsh (Vundef, Vundef) p;
                 field_at_ Tsh t_struct_elem [StructField _next] p)
  POST [ tvoid ]
          PROP() LOCAL() SEP (fifo (contents++(p :: nil)) q).

Definition fifo_empty_spec :=
 DECLARE _fifo_empty
  WITH q: val, contents: list val
  PRE  [ _Q OF (tptr t_struct_fifo) ]
     PROP() LOCAL (temp _Q q) SEP(fifo contents q)
  POST [ tint ]
      PROP ()
      LOCAL(temp ret_temp (if isnil contents then Vtrue else Vfalse)) 
      SEP (fifo (contents) q).

Definition fifo_get_spec :=
 DECLARE _fifo_get
  WITH q: val, contents: list val, p: val
  PRE  [ _Q OF (tptr t_struct_fifo) ]
       PROP() LOCAL (temp _Q q) SEP (fifo (p :: contents) q) 
  POST [ (tptr t_struct_elem) ] 
       PROP ()
       LOCAL(temp ret_temp p) 
       SEP (fifo contents q;
              list_cell QS Qsh (Vundef, Vundef) p;
              field_at_ Tsh t_struct_elem [StructField _next] p).

Definition make_elem_spec :=
 DECLARE _make_elem
  WITH a: int, b: int
  PRE  [ _a OF tint, _b OF tint ] 
        PROP() LOCAL(temp _a (Vint a); temp _b (Vint b)) SEP()
  POST [ (tptr t_struct_elem) ]
      @exp (environ->mpred) _ _ (fun p:val =>  (* EX notation doesn't work for some reason *)
       PROP() 
       LOCAL (temp ret_temp p) 
       SEP (field_at Qsh' list_struct [StructField _a] (Vint a) p;
              field_at Qsh' list_struct [StructField _b] (Vint b) p;
              list_cell QS Qsh (Vundef, Vundef) p;
              field_at_ Tsh t_struct_elem [StructField _next] p)).  

Definition main_spec := 
 DECLARE _main
  WITH u : unit
  PRE  [] main_pre prog u
  POST [ tint ] main_post prog u.

Definition Gprog : funspecs := 
    mallocN_spec :: freeN_spec :: fifo_new_spec :: fifo_put_spec 
         :: fifo_empty_spec :: fifo_get_spec 
         :: make_elem_spec :: main_spec::nil.

Lemma memory_block_fifo:
 forall p, 
  field_compatible t_struct_fifo nil p ->
  memory_block Tsh 8 p = field_at_ Tsh t_struct_fifo nil p.
Proof.
 intros.
 change 8 with (sizeof t_struct_fifo).
 rewrite memory_block_data_at_; auto.
Qed.

Lemma fifo_isptr: forall al q, fifo al q |-- !! isptr q.
Proof.
intros.
 unfold fifo.
 if_tac; entailer; destruct ht; entailer!.
Qed.

Hint Resolve fifo_isptr : saturate_local.

Lemma body_fifo_empty: semax_body Vprog Gprog f_fifo_empty fifo_empty_spec.
Proof.
start_function.
unfold fifo.
Intros ht; destruct ht as [hd tl].
Intros.
forward. (* h = Q->head; *)
forward. (* return (h == NULL); *)
unfold fifo.
Exists (hd,tl).
destruct (isnil contents).
* entailer!.
  apply andp_right; auto with valid_pointer.
* Intros prefix.
Exists prefix.
  assert_PROP (isptr hd).
    destruct prefix; entailer.
    rewrite lseg_cons_eq by auto. Intros y. subst v. 
    entailer.
 destruct hd; try contradiction.
 entailer!. entailer!.
Qed.

Lemma body_fifo_new: semax_body Vprog Gprog f_fifo_new fifo_new_spec.
Proof.
  start_function.
 
  forward_call (* Q = mallocN(sizeof ( *Q)); *)
     8.
    computable.
  Intros q.
  rewrite memory_block_fifo.
2:  eapply malloc_compatible_field_compatible; try eassumption; 
      auto with typeclass_instances;
      exists 2; reflexivity.
  forward. (* Q->head = NULL; *)
  (* goal_4 *)
  forward. (* Q->tail = NULL; *)
  forward. (* return Q; *)
  (* goal_5 *)
  Exists q. unfold fifo. Exists (nullval,nullval).
  rewrite if_true by auto.
  entailer!.
Qed.

Lemma body_fifo_put: semax_body Vprog Gprog f_fifo_put fifo_put_spec.
Proof.
start_function.
unfold fifo at 1.
Intros ht; destruct ht as [hd tl].
Intros.
(* goal_7 *)
forward. (* p->next = NULL; *)
forward. (*   h = Q->head; *)

forward_if 
  (PROP() LOCAL () SEP (fifo (contents ++ p :: nil) q))%assert.
* if_tac; entailer.  (* typechecking clause *)
    (* entailer! should perhaps solve this one too *)
* (* then clause *)
  subst.
  (* goal 9 *)
  forward. (* Q->head=p; *)
  forward. (* Q->tail=p; *)
  (* goal 10 *)
  entailer.
  destruct (isnil contents).
  + subst. Exists (p,p).
     simpl. rewrite if_false by congruence.
     Exists (@nil val).
      rewrite lseg_nil_eq by auto.
      entailer!.
   + Intros prefix.
      destruct prefix;
      entailer!.
      contradiction (field_compatible_isptr _ _ _ H6).
      rewrite lseg_cons_eq by auto. simpl.
      entailer!.
      saturate_local. (* why is this needed? *)
      contradiction (field_compatible_isptr _ _ _ H8).
* (* else clause *)
  forward. (*  t = Q->tail; *)
  destruct (isnil contents).
  + Intros. contradiction H; auto.
  + Intros prefix.
     forward. (*  t->next=p; *)
  (* goal 12 *)
     forward. (* Q->tail=p; *)
  (* goal 13 *)
     entailer!.
     unfold fifo. Exists (hd, p).
     rewrite if_false by (clear; destruct prefix; simpl; congruence).
     Exists  (prefix ++ tl :: nil).
     entailer.
     match goal with
     | |- _ |-- _ * _ * ?AA => remember AA as A
     end.     (* prevent it from canceling! *)
     cancel. subst A.
     eapply derives_trans; [ |
       apply (lseg_cons_right_neq _ _ _ _ _ (Vundef,Vundef));
        auto ].
     cancel.
* (* after the if *)
     forward. (* return ; *)
Qed.

Lemma body_fifo_get: semax_body Vprog Gprog f_fifo_get fifo_get_spec.
Proof.
start_function.
unfold fifo at 1.
Intros ht; destruct ht as [hd tl].
rewrite if_false by congruence.
Intros prefix.
forward.  (*   p = Q->head; *)
destruct prefix; inversion H; clear H.
+ subst_any.
   rewrite lseg_nil_eq by auto.
   Intros.
   subst_any.
   forward. (*  n=h->next; *)
   forward. (* Q->head=n; *)
   forward. (* return p; *)
   unfold fifo. Exists (nullval, p).
   rewrite if_true by congruence.
   entailer!.
+ rewrite lseg_cons_eq by auto.
    Intros x. 
    simpl @valinject. (* can we make this automatic? *)
    subst_any.
    forward. (*  n=h->next; *)
    forward. (* Q->head=n; *)
    forward. (* return p; *)
    unfold fifo. Exists (x, tl).
    rewrite if_false by (destruct prefix; simpl; congruence).
    Exists prefix.
    entailer!.
    apply derives_refl.
Qed.

Lemma body_make_elem: semax_body Vprog Gprog f_make_elem make_elem_spec.
Proof.
start_function. rename a into a0; rename b into b0.
forward_call (*  p = mallocN(sizeof ( *p));  *) 
  12.
 computable.
Intros p0.
  change 12 with (sizeof t_struct_elem).
  rewrite memory_block_data_at_
  by (eapply malloc_compatible_field_compatible; try eassumption; 
      auto with typeclass_instances;
      exists 2; reflexivity).
Time forward.  (*  p->a=a; *)  (* 11.6 sec -> 10.78 sec -> 7.8 sec -> 6.36 -> 0.775 *)
simpl.  (* this should not be necessary -- Qinxiang, please look *)
Time forward.  (*  p->b=b; *) (* 21 secs -> 56 sec -> 6.82 sec -> 4.84 -> 1.122 *)
Time forward. (* return p; *)  (* 4.73 sec -> 5.0 -> 2.76 *)
Exists p0.
Time entailer!.  (* 7.2 sec -> 5.6 -> 1.074 *)
rewrite make_unmake.
solve [auto].
Qed.

Hint Resolve readable_share_Qsh'.

Lemma body_main:  semax_body Vprog Gprog f_main main_spec.
Proof.
start_function.
forward_call (* Q = fifo_new(); *)  tt.
Intros q.

forward_call  (*  p = make_elem(1,10); *)
     (Int.repr 1, Int.repr 10).
Intros p'.
forward_call (* fifo_put(Q,p);*) 
    ((q, @nil val),p').

forward_call  (*  p = make_elem(2,20); *)
     (Int.repr 2, Int.repr 20).
Intros p2.
simpl app.
 forward_call  (* fifo_put(Q,p); *)
    ((q,(p':: nil)),p2).
simpl app.
forward_call  (*   p' = fifo_get(Q); p = p'; *)
    ((q,(p2 :: nil)),p').
Time forward. (*   i = p->a;  *) (* 28.8 sec -> 1.96 sec *)
forward. (*   j = p->b; *)

forward_call (*  freeN(p, sizeof( *p)); *)
   (p', sizeof t_struct_elem).
{
pose (work_around_coq_bug := fifo [p2] q * 
   data_at Tsh t_struct_elem (Vint (Int.repr 1), (Vint (Int.repr 10), Vundef)) p' *
   field_at Qsh' list_struct [StructField _a] (Vint (Int.repr 2)) p2 *
   field_at Qsh' list_struct [StructField _b] (Vint (Int.repr 20)) p2).
 apply derives_trans with work_around_coq_bug; subst work_around_coq_bug.
 unfold data_at; rewrite make_unmake; cancel.
 apply derives_trans with
   (data_at_ Tsh t_struct_elem p' * fold_right sepcon emp Frame).
 cancel.
 rewrite data_at__memory_block by reflexivity. entailer.
}
unfold map.
forward. (* return i+j; *)
Qed.

Existing Instance NullExtension.Espec.

Parameter body_mallocN:
 semax_external
  (1%positive ::nil)
  (EF_external "mallocN"
     {| sig_args := AST.Tint :: nil; sig_res := Some AST.Tint; sig_cc := cc_default |}) Z
  (fun n : Z =>
   PROP  (4 <= n <= Int.max_unsigned)  LOCAL  (temp 1%positive (Vint (Int.repr n)))  SEP())%assert
  (fun n : Z =>
   EX  v : val,
   PROP  (malloc_compatible n v)
   LOCAL  (temp ret_temp v)  SEP  (memory_block Tsh n v)).

Parameter body_freeN:
semax_external
  (1%positive::2%positive ::nil)
  (EF_external "freeN"
     {| sig_args := AST.Tint :: AST.Tint :: nil; sig_res := None; sig_cc := cc_default |}) (val*Z)
  (fun pn : val*Z => let (p,n) := pn in
      PROP() LOCAL (temp 1%positive p; temp 2%positive (Vint (Int.repr n)))
      SEP (memory_block Tsh n p))
  (fun pn => let (p,n) := pn in
    PROP () LOCAL () SEP ()).

Lemma ret_temp_make_ext_rval:
  forall gx ret p,  
   locald_denote (temp ret_temp p) (make_ext_rval gx ret) -> 
    p = force_val ret.
Proof.
  intros.
  hnf in H.
  rewrite retval_ext_rval in H. auto.
Qed.

Lemma all_funcs_correct:
  semax_func Vprog Gprog (prog_funct prog) Gprog.
Proof.
unfold Gprog, prog, prog_funct; simpl.
semax_func_skipn.
semax_func_cons body_mallocN.
 renormalize. entailer!.
 rewrite (ret_temp_make_ext_rval gx ret _ (eq_refl _)) in Px0.
 auto.
semax_func_cons body_freeN.
  admit.  (* yuck *)
semax_func_cons body_fifo_new.
semax_func_cons body_fifo_put.
semax_func_cons body_fifo_empty.
semax_func_cons body_fifo_get.
semax_func_cons body_make_elem.
semax_func_cons body_main.
apply semax_func_nil.
Qed.


