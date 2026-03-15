# OCaml Parsetree と Ast_helper の解説

## 概要

OCamlのParsetreeとAst_helperは、OCamlの抽象構文木（AST）を扱うためのモジュールです。Parsetreeはコンパイラが提供するAST型定義であり、Ast_helperはそれらを構築するためのヘルパー関数を提供します。

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

## 使用例

### ParsetreeをOCamlソースコードとして出力する

Parsetreeを実際のOCamlソースコードとして出力する基本的な流れ：

```ocaml
let oc = open_out "output.ml" in
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
