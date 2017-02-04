(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

(* Environments *)

type env =                     (* information about an environment variable. *)
  { env_var : string;                                       (* the variable. *)
    env_doc : string;                                               (* help. *)
    env_docs : string; }              (* title of help section where listed. *)

let env
    ?(docs = Cmdliner_manpage.s_environment) ?(doc = "See option $(opt).")
    env_var =
  { env_var = env_var; env_doc = doc; env_docs = docs }

let env_var e = e.env_var
let env_doc e = e.env_doc
let env_docs e = e.env_docs

(* Arguments *)

type arg_absence = Err | Val of string Lazy.t
type opt_kind = Flag | Opt | Opt_vopt of string

type pos_kind =                  (* information about a positional argument. *)
  { pos_rev : bool;         (* if [true] positions are counted from the end. *)
    pos_start : int;                           (* start positional argument. *)
    pos_len : int option }    (* number of arguments or [None] if unbounded. *)

let pos ~rev:pos_rev ~start:pos_start ~len:pos_len =
  { pos_rev; pos_start; pos_len}

let pos_rev p = p.pos_rev
let pos_start p = p.pos_start
let pos_len p = p.pos_len

type arg =                     (* information about a command line argument. *)
  { id : int;                                 (* unique id for the argument. *)
    absent : arg_absence;                            (* behaviour if absent. *)
    env : env option;                               (* environment variable. *)
    doc : string;                                                   (* help. *)
    docv : string;                (* variable name for the argument in help. *)
    docs : string;                    (* title of help section where listed. *)
    pos : pos_kind;                                  (* positional arg kind. *)
    opt_kind : opt_kind;                               (* optional arg kind. *)
    opt_names : string list;                        (* names (for opt args). *)
    opt_all : bool; }                          (* repeatable (for opt args). *)

let new_arg_id =    (* thread-safe UIDs, Oo.id (object end) was used before. *)
  let c = ref 0 in
  fun () ->
    let id = !c in
    incr c; if id > !c then assert false (* too many ids *) else id

let dumb_pos = pos ~rev:false ~start:(-1) ~len:None

let arg ?docs ?(docv = "") ?(doc = "") ?env names =
  let dash n = if String.length n = 1 then "-" ^ n else "--" ^ n in
  let opt_names = List.map dash names in
  let docs = match docs with
  | Some s -> s
  | None ->
      match names with
      | [] -> Cmdliner_manpage.s_arguments
      | _ -> Cmdliner_manpage.s_options
  in
  { id = new_arg_id (); absent = Val (lazy ""); env; doc; docv; docs;
    pos = dumb_pos; opt_kind = Flag; opt_names; opt_all = false; }

let arg_id a = a.id
let arg_absent a = a.absent
let arg_env a = a.env
let arg_doc a = a.doc
let arg_docv a = a.docv
let arg_docs a = a.docs
let arg_pos a = a.pos
let arg_opt_kind a = a.opt_kind
let arg_opt_names a = a.opt_names
let arg_opt_all a = a.opt_all
let arg_opt_name_sample a =
  (* First long or short name (in that order) in the list; this
     allows the client to control which name is shown *)
  let rec find = function
  | [] -> List.hd a.opt_names
  | n :: ns -> if (String.length n) > 2 then n else find ns
  in
  find a.opt_names


let arg_make_req a = { a with absent = Err }
let arg_make_all_opts a = { a with opt_all = true }
let arg_make_opt ~absent ~kind:opt_kind a = { a with absent; opt_kind }
let arg_make_opt_all ~absent ~kind:opt_kind a =
  { a with absent; opt_kind; opt_all = true  }

let arg_make_pos ~pos a = { a with pos }
let arg_make_pos_abs ~absent ~pos a = { a with absent; pos }

let arg_is_opt a = a.opt_names <> []
let arg_is_pos a = a.opt_names = []
let arg_is_req a = a.absent = Err

let arg_pos_cli_order a0 a1 =              (* best-effort order on the cli. *)
  let c = compare (a0.pos.pos_rev) (a1.pos.pos_rev) in
  if c <> 0 then c else
  if a0.pos.pos_rev
  then compare a1.pos.pos_start a0.pos.pos_start
  else compare a0.pos.pos_start a1.pos.pos_start

let rev_arg_pos_cli_order a0 a1 = arg_pos_cli_order a1 a0

(* Term info *)

type term =
  { name : string;                                    (* name of the term. *)
    version : string option;                   (* version (for --version). *)
    tdoc : string;                        (* one line description of term. *)
    tdocs : string;       (* title of man section where listed (commands). *)
    sdocs : string;    (* standard options, title of section where listed. *)
    man : Cmdliner_manpage.block list; }                 (* man page text. *)

let term
    ?(sdocs = Cmdliner_manpage.s_options) ?(man = []) ?(docs = "COMMANDS")
    ?(doc = "") ?version name =
  { name = name; version = version; tdoc = doc; tdocs = docs; sdocs = sdocs;
    man = man }

let term_name t = t.name
let term_version t = t.version
let term_doc t = t.tdoc
let term_docs t = t.tdoc
let term_stdopts_docs t = t.sdocs
let term_man t = t.man

(* Eval info *)

type eval =                     (* information about the evaluation context. *)
  { term : term * arg list;                         (* term being evaluated. *)
    main : term * arg list;                                    (* main term. *)
    choices : (term * arg list) list;                   (* all term choices. *)
    env : string -> string option }          (* environment variable lookup. *)

let eval ~term ~main ~choices ~env = { term; main; choices; env }
let eval_term e = fst e.term
let eval_term_args e = snd e.term
let eval_main e = fst e.main
let eval_main_args e = snd e.main
let eval_choices e = e.choices
let eval_env_var e v = e.env v

let eval_kind ei =
  if ei.choices = [] then `Simple else
  if (fst ei.term) == (fst ei.main) then `Multiple_main else `Multiple_sub

let eval_with_term ei term = { ei with term }

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
