# infix-op-lisp

中置演算子を標準でサポートするLisp系関数型言語の仕様書です。Clojure, Dr.Racket, Haskell, Elm, OCaml, をベースに、シンプルで一貫性のある構文を提供します。

## ドキュメント

- [基本構文](docs/basic-syntax.md)
  - コア機能（定義、束縛、パターンマッチング、条件分岐など）
  - 演算子の表層形式
  - モナド・アプリカティブファンクタ

- [中置演算子](docs/infix-operators.md)
  - 中置演算子の概要
  - 演算子の宣言方法（連鎖可能 / プレーン）

- [型宣言](docs/type-declaration.md)
  - 前置スタイル・中置スタイルの型宣言

- [コレクション型](docs/collection-types.md)
  - リスト、タプル、ハッシュマップ、配列
  - リテラル表現とパターンマッチング

- [コメント装飾パターン](docs/comment-conventions.md)
  - 仕様書内でのコメント記法の凡例

## ADR（Architecture Decision Records）

設計上の重要な決定事項は[ADR](ADR/)ディレクトリに記録されています。

- [型の宣言とパターンマッチング](ADR/def_type.md)