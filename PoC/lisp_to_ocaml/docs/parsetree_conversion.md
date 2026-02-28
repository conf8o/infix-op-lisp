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

現在の実装では、以下の簡易的なLisp ASTを定義しています：

```ocaml
type lisp_expr =
  | Int of int                      (* 整数リテラル *)
  | Add of lisp_expr * lisp_expr    (* 加算 *)
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

#### `to_unit_pat : unit -> pattern`

unitパターン `()` を作成します。

```ocaml
let to_unit_pat () : pattern =
  Pat.construct { txt = Lident "()"; loc = Location.none } None
```

**用途:**
- 関数のunit引数: `fun () -> ...`
- unit値の束縛: `let () = ...`

#### `to_variable_pat : string -> pattern`

変数パターンを作成します。

```ocaml
let to_variable_pat (name : string) : pattern =
  Pat.var { txt = name; loc = Location.none }
```

**例:**
- `to_variable_pat "x"` → パターン `x`
- `let x = ...` における `x` の部分

#### `wrap_in_unit_function : expression -> expression`

式を受け取り、それを `fun () -> expr` というunit引数の関数でラップします。

**命名の意図:**
- 式自体は関数ではないが、それを関数の本体として使う
- 「式を関数式に変換する」のではなく「式を関数でラップする」という意図を明確に

```ocaml
let wrap_in_unit_function (body : expression) : expression =
  let unit_param = {
    pparam_loc = Location.none;
    pparam_desc = Pparam_val (Nolabel, None, to_unit_pat ());
  } in
  Exp.function_ [unit_param] None (Pfunction_body body)
```

**詳細:**
1. `function_param` レコードを構築
   - `pparam_loc`: 位置情報（PoCでは `Location.none`）
   - `pparam_desc`: パラメータの記述
     - `Pparam_val (Nolabel, None, pattern)` - ラベルなし、デフォルト値なし、パターン
2. `Exp.function_` でPexp_functionを構築
   - 第1引数: パラメータリスト `[unit_param]`
   - 第2引数: 型制約 `None`
   - 第3引数: 関数本体 `Pfunction_body body`

**注意:** 
- OCaml 5.3では `Pexp_fun` が `Pexp_function` に統合されました
- `function_param` を構築するヘルパーがないため、レコードを直接構築します

### メイン変換関数: `to_ocaml_expr`

Lisp ASTをOCaml Parsetreeの式に変換します。

```ocaml
let rec to_ocaml_expr (e : lisp_expr) : expression =
  match e with
  | Int n -> to_constant_int_exp n
  | Add (a, b) ->
      Exp.apply
        (to_identifier_exp "+")
        [ (Nolabel, to_ocaml_expr a); (Nolabel, to_ocaml_expr b) ]
```

**変換の仕組み:**

1. **整数リテラル** (`Int n`)
   - `to_constant_int_exp n` で整数定数の式に変換

2. **加算** (`Add (a, b)`)
   - OCamlでは `a + b` は `(+) a b` の糖衣構文
   - Parsetreeでは関数適用として表現
   - 演算子 `+` を `to_identifier_exp` で識別子式に変換
   - 引数には `Nolabel` を付与（名前付き引数ではないため）
   - 再帰的に `a` と `b` を変換

### トップレベル構造の生成: `to_toplevel_structure`

式を受け取り、`let generated () = expr` という形式のトップレベル定義を生成します。

```ocaml
let to_toplevel_structure (expr : expression) : structure =
  let function_expr = wrap_in_unit_function expr in
  let value_binding =
    Vb.mk (to_variable_pat "generated") function_expr
  in
  [ Str.value Nonrecursive [ value_binding ] ]
```

**生成される構造:**
```ocaml
let generated () = expr
```

**実装のポイント:**

1. `wrap_in_unit_function` で式を関数でラップ
   - `expr` → `fun () -> expr`

2. `Vb.mk` で値束縛を作成
   - パターン: `to_variable_pat "generated"` → 変数 `generated`
   - 式: `function_expr` → `fun () -> expr`

3. `Str.value` でトップレベル構造要素を作成
   - `Nonrecursive` - 非再帰的な定義
   - 値束縛のリスト `[value_binding]`

**なぜこの形式か:**
- `let generated () = expr` は `let generated = fun () -> expr` と等価
- 関数定義の形式にすることで、後から `generated ()` で評価できる
- print文などのノイズを排除し、純粋にLisp式の変換結果のみを表現

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
Add (Int 1, Int 2)
```

**生成されるOCamlコード** (generated.ml):
```ocaml
let generated () = 1 + 2
```

**実行方法:**
```bash
$ dune exec lisp_to_ocaml
Wrote generated.ml

$ ocaml generated.ml
# 何も出力されない（関数定義のみ）

$ ocaml -stdin <<EOF
#use "generated.ml";;
generated ();;
EOF
- : int = 3
```

## 拡張の方針

現在は加算のみをサポートしていますが、以下のような拡張が考えられます：

1. **他の二項演算子の追加**
   - 減算、乗算、除算など
   - `lisp_expr` に `Sub`, `Mul`, `Div` を追加
   - `to_ocaml_expr` で対応する演算子名を使用

2. **変数の参照**
   - `lisp_expr` に `Var of string` を追加
   - `to_ocaml_expr` で `to_identifier_exp` を使用

3. **関数定義とlet束縛**
   - より複雑なトップレベル構造の生成
   - `Exp.let_` の使用

4. **条件分岐**
   - `Exp.ifthenelse` の使用

5. **パターンマッチ**
   - `Exp.match_` の使用

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
  pparam_desc = Pparam_val (Nolabel, None, to_unit_pat ());
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
