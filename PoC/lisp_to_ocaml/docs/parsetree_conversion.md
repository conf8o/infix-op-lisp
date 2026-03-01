# Lisp表現からOCaml Parsetreeへの変換

## 概要

このPoCでは、簡易的なLispのAST表現をOCamlのParsetreeに変換し、OCamlソースコードを生成しています。

**変換の流れ:**
```
Lisp AST → OCaml Parsetree → OCamlソースコード
```

**例:**
```clojure
; Lisp表現
(+ 1 2)
```
↓
```ocaml
(* 生成されるOCamlコード *)
let generated () = 1 + 2
```

## 使用しているOCamlのモジュール

### 1. Parsetree

OCamlコンパイラが提供するモジュールで、OCamlの抽象構文木（AST）の型定義を含んでいます。

**主要な型:**
- `expression` - 式を表す型
- `structure` - トップレベルの構造（モジュールの内容）を表す型
- `pattern` - パターンマッチのパターンを表す型
- `function_param` - 関数パラメータを表す型（レコード型）
- `function_param_desc` - 関数パラメータの種類を表す型
- `function_body` - 関数本体を表す型

**主要な型コンストラクタ:**
- `Pexp_function` - 関数式（`fun` や `function` キーワードの両方を表現）
- `Pparam_val of arg_label * expression option * pattern` - 値パラメータ
- `Pfunction_body of expression` - 通常の関数本体（式1つ）
- `Pfunction_cases` - パターンマッチによる関数本体（`function` キーワード用）

### 2. Ast_helper

Parsetreeを構築するためのヘルパーモジュール。各構文要素を簡潔に構築できます。
コードでは `open Ast_helper` により、サブモジュールを直接使用しています。

**使用している主なヘルパー:**

#### Exp (式の構築)
- `Exp.ident : Longident.t Location.loc -> expression`
  - 識別子の式を作成 (例: 変数参照、演算子)
- `Exp.constant : constant -> expression`
  - 定数の式を作成 (例: 整数リテラル)
- `Exp.apply : expression -> (arg_label * expression) list -> expression`
  - 関数適用の式を作成 (例: `f x y` や `a + b`)
- `Exp.function_ : function_param list -> type_constraint option -> function_body -> expression`
  - 関数式を作成 (例: `fun () -> expr` や `function x -> ...`)

#### Const (定数の構築)
- `Const.int : int -> constant`
  - 整数定数を作成

#### Pat (パターンの構築)
- `Pat.construct : Longident.t Location.loc -> pattern option -> pattern`
  - バリアント構築子のパターンを作成 (例: `()`)
- `Pat.var : string Location.loc -> pattern`
  - 変数パターンを作成 (例: `let x = ...` の `x`)

#### Vb (値束縛の構築)
- `Vb.mk : pattern -> expression -> value_binding`
  - 値束縛を作成 (例: `let pattern = expression`)

#### Str (構造要素の構築)
- `Str.value : rec_flag -> value_binding list -> structure_item`
  - トップレベルの値定義を作成 (例: `let ... = ...`)

### 3. Longident

長い識別子（モジュールパスを含む識別子）を表現する型。

**使用している型:**
- `Lident of string` - 単純な識別子 (例: `"+"`, `"x"`, `"print_int"`)

### 4. Asttypes

ASTに共通する型定義を含むモジュール。

**使用している型:**
- `rec_flag` - 再帰フラグ
  - `Nonrecursive` - 非再帰的
  - `Recursive` - 再帰的
- `arg_label` - 引数ラベル
  - `Nolabel` - ラベルなし

### 5. Location

ソースコード上の位置情報を扱うモジュール。

**使用している値:**
- `Location.none` - 位置情報なしを表す値（PoCでは実際のソース位置を追跡しないため使用）

### 6. Pprintast

ParsetreeをOCamlソースコードとして整形出力するモジュール。

**使用している関数:**
- `Pprintast.structure : Format.formatter -> structure -> unit`
  - `structure` を整形してフォーマッタに出力

## 実装の詳細

### Lisp ASTの定義

現在の実装では、以下のLisp ASTを定義しています：

```ocaml
type var = string

type binding_pattern =
  | Var of var                      (* 変数 *)
  | Fn of var * (var list)          (* 関数名と引数リスト *)

type lisp =
  | Int of int                      (* 整数リテラル *)
  | Var of var                      (* 変数参照 *)
  | List of lisp list               (* リスト（関数適用） *)
  | Let of bindings * lisp          (* let束縛（未実装） *)
  | If of bool * lisp * lisp        (* 条件分岐（未実装） *)
  | Decl of declaration             (* 宣言 *)
and declaration =
  | Def of binding                  (* 定義 *)
and binding =
  binding_pattern * lisp
and bindings =
  binding list
```

### 変換ヘルパー関数

#### `to_identifier_exp : string -> expression`

文字列から識別子の式を作成します。変数参照や演算子の参照に使用します。

**命名の意図:**
- `to_` - 変換を表すプレフィックス
- `identifier` - 識別子（変数、関数名、演算子など）
- `exp` - expression（式）の略

```ocaml
let to_identifier_exp (name : string) : expression =
  Exp.ident { txt = Lident name; loc = Location.none }
```

**例:**
- `to_identifier_exp "+"` → 演算子 `+` の参照
- `to_identifier_exp "x"` → 変数 `x` の参照

#### `to_constant_int_exp : int -> expression`

整数リテラルの式を作成します。

```ocaml
let to_constant_int_exp (n : int) : expression =
  Exp.constant (Const.int n)
```

**例:**
- `to_constant_int_exp 42` → 整数リテラル `42`

#### `to_variable_pat : string -> pattern`

変数パターンを作成します。

```ocaml
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }
```

**例:**
- `to_variable_pat "x"` → パターン `x`
- `let x = ...` における `x` の部分

### メイン変換関数: `to_ocaml_exp`

Lisp ASTをOCaml Parsetreeの式に変換します。

```ocaml
let rec to_ocaml_exp (e : lisp) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Var name -> to_identifier_exp name
  | List items ->
    (* Function application: (f arg1 arg2 ...) *)
    (match items with
    | [] -> failwith "Empty Cons is not a valid expression"
    | [single] -> to_ocaml_exp single
    | fn :: args ->
        let fn_exp = to_ocaml_exp fn in
        let arg_exps = List.map (fun arg -> (Nolabel, to_ocaml_exp arg)) args in
        Exp.apply fn_exp arg_exps)
  | Let (_bindings, _body) ->
    failwith "not implemented"
  | If (_pred, _then_expr, _else_expr) ->
    failwith "not implemented"
  | Decl _ ->
      failwith "Def cannot be converted to expression; use to_structure instead"
```

**変換の仕組み:**

1. **整数リテラル** (`Int n`)
   - `to_constant_int_exp n` で整数定数の式に変換

2. **変数参照** (`Var name`)
   - `to_identifier_exp name` で変数参照の式に変換

3. **リスト（関数適用）** (`List items`)
   - Lispでは `(f arg1 arg2 ...)` の形式で関数適用を表現
   - OCamlでは `f arg1 arg2` として表現
   - Parsetreeでは関数適用として表現
   - 先頭要素を関数として、残りを引数として変換
   - 引数には `Nolabel` を付与（名前付き引数ではないため）
   - 例: `(+ x 1)` → `(+) x 1` → `x + 1`

4. **宣言** (`Decl _`)
   - 式としては変換できないため、`to_structure` を使用する必要がある

### トップレベル構造の生成: `to_structure`

Lisp ASTを受け取り、OCamlのトップレベル定義（`structure`）を生成します。

```ocaml
let to_structure (e : lisp) : structure =
  match e with
  | Decl (Def (Var name, value)) ->
      (* OCaml AST representation of: let name = value *)
      [ Str.value Nonrecursive [ Vb.mk (to_variable_pat name) (to_ocaml_exp value) ] ]
  | Decl (Def (Fn (name, args), body)) ->
      (* OCaml AST representation of: let name arg1 arg2 ... = body *)
      let body_exp = to_ocaml_exp body in
      let params = match args with
        | [] ->
            (* No arguments: create unit parameter for fun () -> body *)
            [{
              pparam_loc = Location.none;
              pparam_desc = Pparam_val (Nolabel, None, Pat.construct { txt = Lident "()"; loc = Location.none } None);
            }]
        | _ ->
            (* Map each argument to a function parameter *)
            List.map (fun arg ->
              {
                pparam_loc = Location.none;
                pparam_desc = Pparam_val (Nolabel, None, to_variable_pat arg);
              }
            ) args
      in
      let fun_exp = Exp.function_ params None (Pfunction_body body_exp) in
      [ Str.value Nonrecursive [ Vb.mk (to_variable_pat name) fun_exp ] ]
  | _ ->
      (* Other expressions are evaluated at top level: ;;expr *)
      [ Str.eval (to_ocaml_exp e) ]
```

**生成される構造の種類:**

1. **変数定義** (`Decl (Def (Var name, value))`)
   - Lisp: `(def x 10)`
   - OCaml: `let x = 10`

2. **関数定義** (`Decl (Def (Fn (name, args), body))`)
   - Lisp: `(def (main) (+ x 1))` （引数なし）
   - OCaml: `let main () = x + 1`
   - Lisp: `(def (add a b) (+ a b))` （引数あり）
   - OCaml: `let add a b = a + b`

3. **その他の式**
   - トップレベルで評価される式として扱う

**関数定義の実装のポイント:**

1. **引数なしの場合**
   - unit引数 `()` を持つ関数として生成
   - `function_param` レコードを直接構築
   - `pparam_desc` に `Pparam_val (Nolabel, None, unit_pattern)` を指定

2. **引数ありの場合**
   - 各引数を `function_param` に変換
   - `List.map` で引数リストを `function_param` リストに変換
   - 各引数は変数パターンとして扱う

3. **関数式の構築**
   - `Exp.function_` を使用して `Pexp_function` を構築
   - 第1引数: パラメータリスト `params`
   - 第2引数: 型制約 `None`
   - 第3引数: 関数本体 `Pfunction_body body_exp`

4. **トップレベル定義の生成**
   - `Vb.mk` で値束縛を作成（パターン + 関数式）
   - `Str.value Nonrecursive` でトップレベル定義を作成

**注意点:**
- OCaml 5.3では `function_param` を構築するヘルパーがないため、レコードを直接構築
- `Pexp_function` は `fun` と `function` の両方を統一的に表現
- 引数が複数ある場合、OCamlではカリー化された関数として扱われる

### ソースコードの出力

Parsetreeを実際のOCamlソースコードとして出力します。

```ocaml
let oc = open_out "generated.ml" in
let fmt = Format.formatter_of_out_channel oc in
Pprintast.structure fmt structure;
Format.pp_print_flush fmt ();
close_out oc
```

**手順:**
1. 出力ファイルを開く
2. `Format.formatter` を作成
3. `Pprintast.structure` でParsetreeを整形出力
4. バッファをフラッシュ
5. ファイルを閉じる

## 実行例

**入力Lisp AST:**
```ocaml
let program = [
  Decl (Def (Var "x", Int 10));  (* (def x 10) *)
  Decl (Def (Fn ("main", []), List [Var "+"; Var "x"; Int 1]))  (* (def (main) (+ x 1)) *)
]
```

**生成されるOCamlコード** (bin/generated.ml):
```ocaml
let x = 10
let main () = x + 1
```

**実行方法:**
```bash
$ dune exec lisp_to_ocaml
Wrote bin/generated.ml

$ ocaml bin/generated.ml
# 何も出力されない（定義のみ）

$ ocaml -stdin <<EOF
#use "bin/generated.ml";;
main ();;
EOF
val x : int = 10
val main : unit -> int = <fun>
- : int = 11
```

## 拡張の方針

現在実装されている機能：
- 変数参照と変数定義
- 関数定義（引数なし/あり）
- リスト形式による関数適用（演算子を含む）
- 整数リテラル

今後の拡張として考えられる機能：

1. **let束縛（式レベル）**
   - `Let of bindings * lisp` の実装
   - `Exp.let_` の使用

2. **条件分岐**
   - `If of bool * lisp * lisp` の実装
   - `Exp.ifthenelse` の使用

3. **パターンマッチ**
   - `Exp.match_` の使用

4. **再帰関数**
   - `Str.value Recursive` の使用

5. **その他のリテラル**
   - 文字列、浮動小数点数、真偽値など

## OCaml 5.3における変更点

### Pexp_fun から Pexp_function への統合

OCaml 5.3では、関数式の表現が変更されました：

**変更前（OCaml 5.2以前）:**
- `Pexp_fun` - 単純なラムダ式 `fun x -> e`
- `Pexp_function` - パターンマッチ `function p1 -> e1 | p2 -> e2`

**変更後（OCaml 5.3）:**
- `Pexp_function` のみ - 両方を統一的に表現
- `fun P1 ... Pn -> E` も `function` も同じ構造

### function_param の構築

`function_param` 型はレコード型で、ヘルパー関数が提供されていません：

```ocaml
type function_param = {
  pparam_loc : Location.t;
  pparam_desc : function_param_desc;
}

type function_param_desc =
  | Pparam_val of arg_label * expression option * pattern
  | Pparam_newtype of string Location.loc
```

そのため、レコードを直接構築する必要があります：

```ocaml
let unit_param = {
  pparam_loc = Location.none;
  pparam_desc = Pparam_val (Nolabel, None, Pat.construct { txt = Lident "()"; loc = Location.none } None);
}
```

## 参考資料

- [OCaml Compiler Libs - Parsetree](https://ocaml.org/api/compilerlibref/Parsetree.html)
- [OCaml Compiler Libs - Ast_helper](https://ocaml.org/api/compilerlibref/Ast_helper.html)
- [OCaml Manual - Language Extensions](https://ocaml.org/manual/extn.html)

## 注意点

- 現在の実装では `Location.none` を使用しており、実際のソース位置情報は保持していません
- エラーメッセージなどで位置情報が必要な場合は、適切なLocation情報を伝播させる必要があります
- Parsetreeは OCamlのバージョンによって変更される可能性があるため、バージョン互換性に注意が必要です
  - 特にOCaml 5.3では `Pexp_fun` が `Pexp_function` に統合されました
- `function_param` を構築するAst_helperが存在しないため、レコードを直接構築します
