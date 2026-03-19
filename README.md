# infix-op-lisp

中置演算子を標準でサポートするLisp系関数型言語の実験です。Clojure, Racket, Haskell, OCamlをベースに、他言語の慣例も取り入れたシンプルで一貫性のある構文を目指します。

## 基本理念

- 従来のLispらしくないコード表現には、必ずLispらしい正規形があること
- 構文はシンプルで一貫性があり、わずらわしさが少ないこと
- 関数型プログラミングができること
- 仕様やモデルとしての型を定義ができること
- 型推論によって冗長な型注釈を省略できること

## (満たしたい)言語仕様ドキュメント

- [基本構文](docs/basic-syntax.md)
- [中置演算子](docs/infix-operators.md)
- [型宣言](docs/type-declaration.md)
- [基本的なデータ構造](docs/basic-data-structures.md)
- [型定義](docs/def-types.md)

## PoC

- [lisp_to_ocaml](Poc/lisp_to_ocaml)
  - Lisp AST
  - 型検査
  - パーサ
  - OCamlへのトランスパイラ
