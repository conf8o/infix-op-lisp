# infix-op-lisp

中置演算子を標準でサポートするLisp系関数型言語の仕様書です。Clojure, Dr.Racket, Haskell, Elm, OCamlをベースに、シンプルで一貫性のある構文を目指しています。

## 基本理念

- 従来のLispらしくないコード表現には、必ずLispらしい正規形があること
- 構文はシンプルで一貫性があり、わずらわしさが少ないこと
- 関数型プログラミングができること

## ドキュメント

- [基本構文](docs/basic-syntax.md)
  - コア機能（定義、束縛、パターンマッチング、条件分岐など）
  - 演算子の表層形式
  - モナドスタイル・アプリカティブスタイル構文

- [中置演算子](docs/infix-operators.md)
  - 中置演算子の概要
  - 演算子の宣言方法(右結合・左結合)

- [型宣言](docs/type-declaration.md)

- [コレクション型](docs/collection-types.md)
  - リスト、タプル、レコード、ハッシュマップ、配列
  - リテラル表現とパターンマッチング

- [型定義](docs/def-types.md)
  - 代数的データ型（deftype / defstruct / defalias）
  - 直積型（構造体、タプル）と直和型（列挙型）
  - 値の構築（型構成子 / コンストラクタ関数 / recordリテラル）
  - フィールドアクセスとパターンマッチング

- [コメント装飾パターン](docs/comment-conventions.md)
  - 仕様書内でのコメント記法の凡例

## ADR（Architecture Decision Records）

設計上の重要な決定事項は[ADR](ADR/)ディレクトリに記録されています。

- [型の宣言とパターンマッチング](ADR/def_type.md)
