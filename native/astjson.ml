(*** This is basically a copy of https://github.com/ocaml/ocaml/blob/4.04/parsing/parsetree.mli ***)
(*** adding `[@@deriving yojson]` to every type and its dependencies                            ***)

(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)


(*** Dependencies from Longident ***)

type longident_t = Longident.t =
    Lident of string
  | Ldot of longident_t * string
  | Lapply of longident_t * longident_t
[@@deriving yojson]


(*** Dependencies from Lexing ***)

type lexing_position = Lexing.position = {
  pos_fname : string;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
}
[@@deriving yojson]


(*** Dependencies from Location ***)

and location_t = Location.t = {
  loc_start: lexing_position;
  loc_end: lexing_position;
  loc_ghost: bool;
}
[@@deriving yojson]

and 'a location_loc = 'a Location.loc = {
  txt : 'a;
  loc : location_t;
}
[@@deriving yojson]


(*** Dependencies from Asttypes ***)

and rec_flag = Asttypes.rec_flag = Nonrecursive | Recursive
[@@deriving yojson]

and direction_flag = Asttypes.direction_flag = Upto | Downto
[@@deriving yojson]

(* Order matters, used in polymorphic comparison *)
and private_flag = Asttypes.private_flag = Private | Public
[@@deriving yojson]

and mutable_flag = Asttypes.mutable_flag = Immutable | Mutable
[@@deriving yojson]

and virtual_flag = Asttypes.virtual_flag = Virtual | Concrete
[@@deriving yojson]

and override_flag = Asttypes.override_flag = Override | Fresh
[@@deriving yojson]

and closed_flag = Asttypes.closed_flag = Closed | Open
[@@deriving yojson]

and label = string
[@@deriving yojson]

and arg_label = Asttypes.arg_label =
    Nolabel
  | Labelled of string (*  label:T -> ... *)
  | Optional of string (* ?label:T -> ... *)
[@@deriving yojson]

and variance = Asttypes.variance =
  | Covariant
  | Contravariant
  | Invariant
[@@deriving yojson]


(*** From Parsetree ***)

type constant = Parsetree.constant =
    Pconst_integer of string * char option
  (* 3 3l 3L 3n

     Suffixes [g-z][G-Z] are accepted by the parser.
     Suffixes except 'l', 'L' and 'n' are rejected by the typechecker
  *)
  | Pconst_char of char
  (* 'c' *)
  | Pconst_string of string * string option
  (* "constant"
     {delim|other constant|delim}
  *)
  | Pconst_float of string * char option
  (* 3.4 2e5 1.4e-4

     Suffixes [g-z][G-Z] are accepted by the parser.
     Suffixes are rejected by the typechecker.
  *)
[@@deriving yojson]

(** {2 Extension points} *)

and attribute = string location_loc * payload
       (* [@id ARG]
          [@@id ARG]

          Metadata containers passed around within the AST.
          The compiler ignores unknown attributes.
       *)
[@@deriving yojson]

and extension = string location_loc * payload
      (* [%id ARG]
         [%%id ARG]

         Sub-language placeholder -- rejected by the typechecker.
      *)
[@@deriving yojson]

and attributes = attribute list
[@@deriving yojson]

and payload = Parsetree.payload =
  | PStr of structure
  | PSig of signature (* : SIG *)
  | PTyp of core_type  (* : T *)
  | PPat of pattern * expression option  (* ? P  or  ? P when E *)
[@@deriving yojson]

(** {2 Core language} *)

(* Type expressions *)

and core_type = Parsetree.core_type =
    {
     ptyp_desc: core_type_desc;
     ptyp_loc: location_t;
     ptyp_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and core_type_desc = Parsetree.core_type_desc =
  | Ptyp_any
        (*  _ *)
  | Ptyp_var of string
        (* 'a *)
  | Ptyp_arrow of arg_label * core_type * core_type
        (* T1 -> T2       Simple
           ~l:T1 -> T2    Labelled
           ?l:T1 -> T2    Otional
         *)
  | Ptyp_tuple of core_type list
        (* T1 * ... * Tn

           Invariant: n >= 2
        *)
  | Ptyp_constr of longident_t location_loc * core_type list
        (* tconstr
           T tconstr
           (T1, ..., Tn) tconstr
         *)
  | Ptyp_object of (string * attributes * core_type) list * closed_flag
        (* < l1:T1; ...; ln:Tn >     (flag = Closed)
           < l1:T1; ...; ln:Tn; .. > (flag = Open)
         *)
  | Ptyp_class of longident_t location_loc * core_type list
        (* #tconstr
           T #tconstr
           (T1, ..., Tn) #tconstr
         *)
  | Ptyp_alias of core_type * string
        (* T as 'a *)
  | Ptyp_variant of row_field list * closed_flag * label list option
        (* [ `A|`B ]         (flag = Closed; labels = None)
           [> `A|`B ]        (flag = Open;   labels = None)
           [< `A|`B ]        (flag = Closed; labels = Some [])
           [< `A|`B > `X `Y ](flag = Closed; labels = Some ["X";"Y"])
         *)
  | Ptyp_poly of string list * core_type
        (* 'a1 ... 'an. T

           Can only appear in the following context:

           - As the core_type of a Ppat_constraint node corresponding
             to a constraint on a let-binding: let x : 'a1 ... 'an. T
             = e ...

           - Under Cfk_virtual for methods (not values).

           - As the core_type of a Pctf_method node.

           - As the core_type of a Pexp_poly node.

           - As the pld_type field of a label_declaration.

           - As a core_type of a Ptyp_object node.
         *)

  | Ptyp_package of package_type
        (* (module S) *)
  | Ptyp_extension of extension
        (* [%id] *)
[@@deriving yojson]

and package_type = longident_t location_loc * (longident_t location_loc * core_type) list
      (*
        (module S)
        (module S with type t1 = T1 and ... and tn = Tn)
       *)
[@@deriving yojson]

and row_field = Parsetree.row_field =
  | Rtag of label * attributes * bool * core_type list
        (* [`A]                   ( true,  [] )
           [`A of T]              ( false, [T] )
           [`A of T1 & .. & Tn]   ( false, [T1;...Tn] )
           [`A of & T1 & .. & Tn] ( true,  [T1;...Tn] )

          - The 2nd field is true if the tag contains a
            constant (empty) constructor.
          - '&' occurs when several types are used for the same constructor
            (see 4.2 in the manual)

          - TODO: switch to a record representation, and keep location
        *)
  | Rinherit of core_type
        (* [ T ] *)
[@@deriving yojson]

(* Patterns *)

and pattern = Parsetree.pattern =
    {
     ppat_desc: pattern_desc;
     ppat_loc: location_t;
     ppat_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and pattern_desc = Parsetree.pattern_desc =
  | Ppat_any
        (* _ *)
  | Ppat_var of string location_loc
        (* x *)
  | Ppat_alias of pattern * string location_loc
        (* P as 'a *)
  | Ppat_constant of constant
        (* 1, 'a', "true", 1.0, 1l, 1L, 1n *)
  | Ppat_interval of constant * constant
        (* 'a'..'z'

           Other forms of interval are recognized by the parser
           but rejected by the type-checker. *)
  | Ppat_tuple of pattern list
        (* (P1, ..., Pn)

           Invariant: n >= 2
        *)
  | Ppat_construct of longident_t location_loc * pattern option
        (* C                None
           C P              Some P
           C (P1, ..., Pn)  Some (Ppat_tuple [P1; ...; Pn])
         *)
  | Ppat_variant of label * pattern option
        (* `A             (None)
           `A P           (Some P)
         *)
  | Ppat_record of (longident_t location_loc * pattern) list * closed_flag
        (* { l1=P1; ...; ln=Pn }     (flag = Closed)
           { l1=P1; ...; ln=Pn; _}   (flag = Open)

           Invariant: n > 0
         *)
  | Ppat_array of pattern list
        (* [| P1; ...; Pn |] *)
  | Ppat_or of pattern * pattern
        (* P1 | P2 *)
  | Ppat_constraint of pattern * core_type
        (* (P : T) *)
  | Ppat_type of longident_t location_loc
        (* #tconst *)
  | Ppat_lazy of pattern
        (* lazy P *)
  | Ppat_unpack of string location_loc
        (* (module P)
           Note: (module P : S) is represented as
           Ppat_constraint(Ppat_unpack, Ptyp_package)
         *)
  | Ppat_exception of pattern
        (* exception P *)
  | Ppat_extension of extension
        (* [%id] *)
  | Ppat_open of longident_t location_loc * pattern
[@@deriving yojson]

(* Value expressions *)

and expression = Parsetree.expression =
    {
     pexp_desc: expression_desc;
     pexp_loc: location_t;
     pexp_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and expression_desc = Parsetree.expression_desc =
  | Pexp_ident of longident_t location_loc
        (* x
           M.x
         *)
  | Pexp_constant of constant
        (* 1, 'a', "true", 1.0, 1l, 1L, 1n *)
  | Pexp_let of rec_flag * value_binding list * expression
        (* let P1 = E1 and ... and Pn = EN in E       (flag = Nonrecursive)
           let rec P1 = E1 and ... and Pn = EN in E   (flag = Recursive)
         *)
  | Pexp_function of case list
        (* function P1 -> E1 | ... | Pn -> En *)
  | Pexp_fun of arg_label * expression option * pattern * expression
        (* fun P -> E1                          (Simple, None)
           fun ~l:P -> E1                       (Labelled l, None)
           fun ?l:P -> E1                       (Optional l, None)
           fun ?l:(P = E0) -> E1                (Optional l, Some E0)

           Notes:
           - If E0 is provided, only Optional is allowed.
           - "fun P1 P2 .. Pn -> E1" is represented as nested Pexp_fun.
           - "let f P = E" is represented using Pexp_fun.
         *)
  | Pexp_apply of expression * (arg_label * expression) list
        (* E0 ~l1:E1 ... ~ln:En
           li can be empty (non labeled argument) or start with '?'
           (optional argument).

           Invariant: n > 0
         *)
  | Pexp_match of expression * case list
        (* match E0 with P1 -> E1 | ... | Pn -> En *)
  | Pexp_try of expression * case list
        (* try E0 with P1 -> E1 | ... | Pn -> En *)
  | Pexp_tuple of expression list
        (* (E1, ..., En)

           Invariant: n >= 2
        *)
  | Pexp_construct of longident_t location_loc * expression option
        (* C                None
           C E              Some E
           C (E1, ..., En)  Some (Pexp_tuple[E1;...;En])
        *)
  | Pexp_variant of label * expression option
        (* `A             (None)
           `A E           (Some E)
         *)
  | Pexp_record of (longident_t location_loc * expression) list * expression option
        (* { l1=P1; ...; ln=Pn }     (None)
           { E0 with l1=P1; ...; ln=Pn }   (Some E0)

           Invariant: n > 0
         *)
  | Pexp_field of expression * longident_t location_loc
        (* E.l *)
  | Pexp_setfield of expression * longident_t location_loc * expression
        (* E1.l <- E2 *)
  | Pexp_array of expression list
        (* [| E1; ...; En |] *)
  | Pexp_ifthenelse of expression * expression * expression option
        (* if E1 then E2 else E3 *)
  | Pexp_sequence of expression * expression
        (* E1; E2 *)
  | Pexp_while of expression * expression
        (* while E1 do E2 done *)
  | Pexp_for of
      pattern *  expression * expression * direction_flag * expression
        (* for i = E1 to E2 do E3 done      (flag = Upto)
           for i = E1 downto E2 do E3 done  (flag = Downto)
         *)
  | Pexp_constraint of expression * core_type
        (* (E : T) *)
  | Pexp_coerce of expression * core_type option * core_type
        (* (E :> T)        (None, T)
           (E : T0 :> T)   (Some T0, T)
         *)
  | Pexp_send of expression * string
        (*  E # m *)
  | Pexp_new of longident_t location_loc
        (* new M.c *)
  | Pexp_setinstvar of string location_loc * expression
        (* x <- 2 *)
  | Pexp_override of (string location_loc * expression) list
        (* {< x1 = E1; ...; Xn = En >} *)
  | Pexp_letmodule of string location_loc * module_expr * expression
        (* let module M = ME in E *)
  | Pexp_letexception of extension_constructor * expression
        (* let exception C in E *)
  | Pexp_assert of expression
        (* assert E
           Note: "assert false" is treated in a special way by the
           type-checker. *)
  | Pexp_lazy of expression
        (* lazy E *)
  | Pexp_poly of expression * core_type option
        (* Used for method bodies.

           Can only be used as the expression under Cfk_concrete
           for methods (not values). *)
  | Pexp_object of class_structure
        (* object ... end *)
  | Pexp_newtype of string * expression
        (* fun (type t) -> E *)
  | Pexp_pack of module_expr
        (* (module ME)

           (module ME : S) is represented as
           Pexp_constraint(Pexp_pack, Ptyp_package S) *)
  | Pexp_open of override_flag * longident_t location_loc * expression
        (* let open M in E
           let! open M in E
        *)
  | Pexp_extension of extension
        (* [%id] *)
  | Pexp_unreachable
        (* . *)
[@@deriving yojson]

and case = Parsetree.case =  (* (P -> E) or (P when E0 -> E) *)
    {
     pc_lhs: pattern;
     pc_guard: expression option;
     pc_rhs: expression;
    }
[@@deriving yojson]

(* Value descriptions *)

and value_description = Parsetree.value_description =
    {
     pval_name: string location_loc;
     pval_type: core_type;
     pval_prim: string list;
     pval_attributes: attributes;  (* ... [@@id1] [@@id2] *)
     pval_loc: location_t;
    }
[@@deriving yojson]

(*
  val x: T                            (prim = [])
  external x: T = "s1" ... "sn"       (prim = ["s1";..."sn"])
*)

(* Type declarations *)

and type_declaration = Parsetree.type_declaration =
    {
     ptype_name: string location_loc;
     ptype_params: (core_type * variance) list;
           (* ('a1,...'an) t; None represents  _*)
     ptype_cstrs: (core_type * core_type * location_t) list;
           (* ... constraint T1=T1'  ... constraint Tn=Tn' *)
     ptype_kind: type_kind;
     ptype_private: private_flag;   (* = private ... *)
     ptype_manifest: core_type option;  (* = T *)
     ptype_attributes: attributes;   (* ... [@@id1] [@@id2] *)
     ptype_loc: location_t;
    }
[@@deriving yojson]

(*
  type t                     (abstract, no manifest)
  type t = T0                (abstract, manifest=T0)
  type t = C of T | ...      (variant,  no manifest)
  type t = T0 = C of T | ... (variant,  manifest=T0)
  type t = {l: T; ...}       (record,   no manifest)
  type t = T0 = {l : T; ...} (record,   manifest=T0)
  type t = ..                (open,     no manifest)
*)

and type_kind = Parsetree.type_kind =
  | Ptype_abstract
  | Ptype_variant of constructor_declaration list
        (* Invariant: non-empty list *)
  | Ptype_record of label_declaration list
        (* Invariant: non-empty list *)
  | Ptype_open
[@@deriving yojson]

and label_declaration = Parsetree.label_declaration =
    {
     pld_name: string location_loc;
     pld_mutable: mutable_flag;
     pld_type: core_type;
     pld_loc: location_t;
     pld_attributes: attributes; (* l [@id1] [@id2] : T *)
    }
[@@deriving yojson]

(*  { ...; l: T; ... }            (mutable=Immutable)
    { ...; mutable l: T; ... }    (mutable=Mutable)

    Note: T can be a Ptyp_poly.
*)

and constructor_declaration = Parsetree.constructor_declaration =
    {
     pcd_name: string location_loc;
     pcd_args: constructor_arguments;
     pcd_res: core_type option;
     pcd_loc: location_t;
     pcd_attributes: attributes; (* C [@id1] [@id2] of ... *)
    }
[@@deriving yojson]

and constructor_arguments = Parsetree.constructor_arguments =
  | Pcstr_tuple of core_type list
  | Pcstr_record of label_declaration list
[@@deriving yojson]

(*
  | C of T1 * ... * Tn     (res = None,    args = Pcstr_tuple [])
  | C: T0                  (res = Some T0, args = [])
  | C: T1 * ... * Tn -> T0 (res = Some T0, args = Pcstr_tuple)
  | C of {...}             (res = None,    args = Pcstr_record)
  | C: {...} -> T0         (res = Some T0, args = Pcstr_record)
  | C of {...} as t        (res = None,    args = Pcstr_record)
*)

and type_extension = Parsetree.type_extension =
    {
     ptyext_path: longident_t location_loc;
     ptyext_params: (core_type * variance) list;
     ptyext_constructors: extension_constructor list;
     ptyext_private: private_flag;
     ptyext_attributes: attributes;   (* ... [@@id1] [@@id2] *)
    }
(*
  type t += ...
*)
[@@deriving yojson]

and extension_constructor = Parsetree.extension_constructor =
    {
     pext_name: string location_loc;
     pext_kind : extension_constructor_kind;
     pext_loc : location_t;
     pext_attributes: attributes; (* C [@id1] [@id2] of ... *)
    }
[@@deriving yojson]

and extension_constructor_kind = Parsetree.extension_constructor_kind =
    Pext_decl of constructor_arguments * core_type option
      (*
         | C of T1 * ... * Tn     ([T1; ...; Tn], None)
         | C: T0                  ([], Some T0)
         | C: T1 * ... * Tn -> T0 ([T1; ...; Tn], Some T0)
       *)
  | Pext_rebind of longident_t location_loc
      (*
         | C = D
       *)
[@@deriving yojson]

(** {2 Class language} *)

(* Type expressions for the class language *)

and class_type = Parsetree.class_type =
    {
     pcty_desc: class_type_desc;
     pcty_loc: location_t;
     pcty_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and class_type_desc = Parsetree.class_type_desc =
  | Pcty_constr of longident_t location_loc * core_type list
        (* c
           ['a1, ..., 'an] c *)
  | Pcty_signature of class_signature
        (* object ... end *)
  | Pcty_arrow of arg_label * core_type * class_type
        (* T -> CT       Simple
           ~l:T -> CT    Labelled l
           ?l:T -> CT    Optional l
         *)
  | Pcty_extension of extension
        (* [%id] *)
[@@deriving yojson]

and class_signature = Parsetree.class_signature =
    {
     pcsig_self: core_type;
     pcsig_fields: class_type_field list;
    }
(* object('selfpat) ... end
   object ... end             (self = Ptyp_any)
 *)
[@@deriving yojson]

and class_type_field = Parsetree.class_type_field =
    {
     pctf_desc: class_type_field_desc;
     pctf_loc: location_t;
     pctf_attributes: attributes; (* ... [@@id1] [@@id2] *)
    }
[@@deriving yojson]

and class_type_field_desc = Parsetree.class_type_field_desc =
  | Pctf_inherit of class_type
        (* inherit CT *)
  | Pctf_val of (string * mutable_flag * virtual_flag * core_type)
        (* val x: T *)
  | Pctf_method  of (string * private_flag * virtual_flag * core_type)
        (* method x: T

           Note: T can be a Ptyp_poly.
         *)
  | Pctf_constraint  of (core_type * core_type)
        (* constraint T1 = T2 *)
  | Pctf_attribute of attribute
        (* [@@@id] *)
  | Pctf_extension of extension
        (* [%%id] *)
[@@deriving yojson]

and 'a class_infos = 'a Parsetree.class_infos =
    {
     pci_virt: virtual_flag;
     pci_params: (core_type * variance) list;
     pci_name: string location_loc;
     pci_expr: 'a;
     pci_loc: location_t;
     pci_attributes: attributes;  (* ... [@@id1] [@@id2] *)
    }
(* class c = ...
   class ['a1,...,'an] c = ...
   class virtual c = ...

   Also used for "class type" declaration.
*)
[@@deriving yojson]

and class_description = class_type class_infos
[@@deriving yojson]

and class_type_declaration = class_type class_infos
[@@deriving yojson]

(* Value expressions for the class language *)

and class_expr = Parsetree.class_expr =
    {
     pcl_desc: class_expr_desc;
     pcl_loc: location_t;
     pcl_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and class_expr_desc = Parsetree.class_expr_desc =
  | Pcl_constr of longident_t location_loc * core_type list
        (* c
           ['a1, ..., 'an] c *)
  | Pcl_structure of class_structure
        (* object ... end *)
  | Pcl_fun of arg_label * expression option * pattern * class_expr
        (* fun P -> CE                          (Simple, None)
           fun ~l:P -> CE                       (Labelled l, None)
           fun ?l:P -> CE                       (Optional l, None)
           fun ?l:(P = E0) -> CE                (Optional l, Some E0)
         *)
  | Pcl_apply of class_expr * (arg_label * expression) list
        (* CE ~l1:E1 ... ~ln:En
           li can be empty (non labeled argument) or start with '?'
           (optional argument).

           Invariant: n > 0
         *)
  | Pcl_let of rec_flag * value_binding list * class_expr
        (* let P1 = E1 and ... and Pn = EN in CE      (flag = Nonrecursive)
           let rec P1 = E1 and ... and Pn = EN in CE  (flag = Recursive)
         *)
  | Pcl_constraint of class_expr * class_type
        (* (CE : CT) *)
  | Pcl_extension of extension
        (* [%id] *)
[@@deriving yojson]

and class_structure = Parsetree.class_structure =
    {
     pcstr_self: pattern;
     pcstr_fields: class_field list;
    }
(* object(selfpat) ... end
   object ... end           (self = Ppat_any)
 *)
[@@deriving yojson]

and class_field = Parsetree.class_field =
    {
     pcf_desc: class_field_desc;
     pcf_loc: location_t;
     pcf_attributes: attributes; (* ... [@@id1] [@@id2] *)
    }
[@@deriving yojson]

and class_field_desc = Parsetree.class_field_desc =
  | Pcf_inherit of override_flag * class_expr * string option
        (* inherit CE
           inherit CE as x
           inherit! CE
           inherit! CE as x
         *)
  | Pcf_val of (string location_loc * mutable_flag * class_field_kind)
        (* val x = E
           val virtual x: T
         *)
  | Pcf_method of (string location_loc * private_flag * class_field_kind)
        (* method x = E            (E can be a Pexp_poly)
           method virtual x: T     (T can be a Ptyp_poly)
         *)
  | Pcf_constraint of (core_type * core_type)
        (* constraint T1 = T2 *)
  | Pcf_initializer of expression
        (* initializer E *)
  | Pcf_attribute of attribute
        (* [@@@id] *)
  | Pcf_extension of extension
        (* [%%id] *)
[@@deriving yojson]

and class_field_kind = Parsetree.class_field_kind =
  | Cfk_virtual of core_type
  | Cfk_concrete of override_flag * expression
[@@deriving yojson]

and class_declaration = class_expr class_infos
[@@deriving yojson]

(** {2 Module language} *)

(* Type expressions for the module language *)

and module_type = Parsetree.module_type =
    {
     pmty_desc: module_type_desc;
     pmty_loc: location_t;
     pmty_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and module_type_desc = Parsetree.module_type_desc =
  | Pmty_ident of longident_t location_loc
        (* S *)
  | Pmty_signature of signature
        (* sig ... end *)
  | Pmty_functor of string location_loc * module_type option * module_type
        (* functor(X : MT1) -> MT2 *)
  | Pmty_with of module_type * with_constraint list
        (* MT with ... *)
  | Pmty_typeof of module_expr
        (* module type of ME *)
  | Pmty_extension of extension
        (* [%id] *)
  | Pmty_alias of longident_t location_loc
        (* (module M) *)
[@@deriving yojson]

and signature = signature_item list
[@@deriving yojson]

and signature_item = Parsetree.signature_item =
    {
     psig_desc: signature_item_desc;
     psig_loc: location_t;
    }
[@@deriving yojson]

and signature_item_desc = Parsetree.signature_item_desc =
  | Psig_value of value_description
        (*
          val x: T
          external x: T = "s1" ... "sn"
         *)
  | Psig_type of rec_flag * type_declaration list
        (* type t1 = ... and ... and tn = ... *)
  | Psig_typext of type_extension
        (* type t1 += ... *)
  | Psig_exception of extension_constructor
        (* exception C of T *)
  | Psig_module of module_declaration
        (* module X : MT *)
  | Psig_recmodule of module_declaration list
        (* module rec X1 : MT1 and ... and Xn : MTn *)
  | Psig_modtype of module_type_declaration
        (* module type S = MT
           module type S *)
  | Psig_open of open_description
        (* open X *)
  | Psig_include of include_description
        (* include MT *)
  | Psig_class of class_description list
        (* class c1 : ... and ... and cn : ... *)
  | Psig_class_type of class_type_declaration list
        (* class type ct1 = ... and ... and ctn = ... *)
  | Psig_attribute of attribute
        (* [@@@id] *)
  | Psig_extension of extension * attributes
        (* [%%id] *)
[@@deriving yojson]

and module_declaration = Parsetree.module_declaration =
    {
     pmd_name: string location_loc;
     pmd_type: module_type;
     pmd_attributes: attributes; (* ... [@@id1] [@@id2] *)
     pmd_loc: location_t;
    }
(* S : MT *)
[@@deriving yojson]

and module_type_declaration = Parsetree.module_type_declaration =
    {
     pmtd_name: string location_loc;
     pmtd_type: module_type option;
     pmtd_attributes: attributes; (* ... [@@id1] [@@id2] *)
     pmtd_loc: location_t;
    }
(* S = MT
   S       (abstract module type declaration, pmtd_type = None)
*)
[@@deriving yojson]

and open_description = Parsetree.open_description =
    {
     popen_lid: longident_t location_loc;
     popen_override: override_flag;
     popen_loc: location_t;
     popen_attributes: attributes;
    }
(* open! X - popen_override = Override (silences the 'used identifier
                              shadowing' warning)
   open  X - popen_override = Fresh
 *)
[@@deriving yojson]

and 'a include_infos = 'a Parsetree.include_infos =
    {
     pincl_mod: 'a;
     pincl_loc: location_t;
     pincl_attributes: attributes;
    }
[@@deriving yojson]

and include_description = module_type include_infos
(* include MT *)
[@@deriving yojson]

and include_declaration = module_expr include_infos
(* include ME *)
[@@deriving yojson]

and with_constraint = Parsetree.with_constraint =
  | Pwith_type of longident_t location_loc * type_declaration
        (* with type X.t = ...

           Note: the last component of the longident must match
           the name of the type_declaration. *)
  | Pwith_module of longident_t location_loc * longident_t location_loc
        (* with module X.Y = Z *)
  | Pwith_typesubst of type_declaration
        (* with type t := ... *)
  | Pwith_modsubst of string location_loc * longident_t location_loc
        (* with module X := Z *)
[@@deriving yojson]

(* Value expressions for the module language *)

and module_expr = Parsetree.module_expr =
    {
     pmod_desc: module_expr_desc;
     pmod_loc: location_t;
     pmod_attributes: attributes; (* ... [@id1] [@id2] *)
    }
[@@deriving yojson]

and module_expr_desc = Parsetree.module_expr_desc =
  | Pmod_ident of longident_t location_loc
        (* X *)
  | Pmod_structure of structure
        (* struct ... end *)
  | Pmod_functor of string location_loc * module_type option * module_expr
        (* functor(X : MT1) -> ME *)
  | Pmod_apply of module_expr * module_expr
        (* ME1(ME2) *)
  | Pmod_constraint of module_expr * module_type
        (* (ME : MT) *)
  | Pmod_unpack of expression
        (* (val E) *)
  | Pmod_extension of extension
        (* [%id] *)
[@@deriving yojson]

and structure = structure_item list
[@@deriving yojson]

and structure_item = Parsetree.structure_item =
    {
     pstr_desc: structure_item_desc;
     pstr_loc: location_t;
    }
[@@deriving yojson]

and structure_item_desc = Parsetree.structure_item_desc =
  | Pstr_eval of expression * attributes
        (* E *)
  | Pstr_value of rec_flag * value_binding list
        (* let P1 = E1 and ... and Pn = EN       (flag = Nonrecursive)
           let rec P1 = E1 and ... and Pn = EN   (flag = Recursive)
         *)
  | Pstr_primitive of value_description
        (*  val x: T
            external x: T = "s1" ... "sn" *)
  | Pstr_type of rec_flag * type_declaration list
        (* type t1 = ... and ... and tn = ... *)
  | Pstr_typext of type_extension
        (* type t1 += ... *)
  | Pstr_exception of extension_constructor
        (* exception C of T
           exception C = M.X *)
  | Pstr_module of module_binding
        (* module X = ME *)
  | Pstr_recmodule of module_binding list
        (* module rec X1 = ME1 and ... and Xn = MEn *)
  | Pstr_modtype of module_type_declaration
        (* module type S = MT *)
  | Pstr_open of open_description
        (* open X *)
  | Pstr_class of class_declaration list
        (* class c1 = ... and ... and cn = ... *)
  | Pstr_class_type of class_type_declaration list
        (* class type ct1 = ... and ... and ctn = ... *)
  | Pstr_include of include_declaration
        (* include ME *)
  | Pstr_attribute of attribute
        (* [@@@id] *)
  | Pstr_extension of extension * attributes
        (* [%%id] *)
[@@deriving yojson]

and value_binding = Parsetree.value_binding =
  {
    pvb_pat: pattern;
    pvb_expr: expression;
    pvb_attributes: attributes;
    pvb_loc: location_t;
  }
[@@deriving yojson]

and module_binding = Parsetree.module_binding =
    {
     pmb_name: string location_loc;
     pmb_expr: module_expr;
     pmb_attributes: attributes;
     pmb_loc: location_t;
    }
(* X = ME *)
[@@deriving yojson]

(** {2 Toplevel} *)

(* Toplevel phrases *)

type toplevel_phrase = Parsetree.toplevel_phrase =
  | Ptop_def of structure
  | Ptop_dir of string * directive_argument
     (* #use, #load ... *)
[@@deriving yojson]

and directive_argument = Parsetree.directive_argument =
  | Pdir_none
  | Pdir_string of string
  | Pdir_int of string * char option
  | Pdir_ident of longident_t
  | Pdir_bool of bool
[@@deriving yojson]
