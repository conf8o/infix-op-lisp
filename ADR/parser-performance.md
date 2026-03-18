# パーサーのパフォーマンス改善

## ステータス

IN DISCUSSION

## 背景

現在のパーサー実装では、文字列をパースする際に`String.sub`を使用して部分文字列を毎回コピーしている。これは以下の問題を引き起こす可能性がある：

1. **メモリコピーのオーバーヘッド**: 文字列の長さがnの場合、各パース操作でO(n)のコピーが発生
2. **メモリ使用量の増加**: 部分文字列が大量に生成され、GCの負荷が増加
3. **大規模ファイルでのパフォーマンス低下**: ファイルサイズに対して非線形的にパフォーマンスが悪化する可能性

### 現状の実装

```ocaml
let satisfy (pred : char -> bool) : char parser =
  fun input ->
  if String.length input = 0 then
    Failure ("Unexpected end of input", { line = 0; column = 0 })
  else (
    let c = input.[0] in
    if pred c then
      Success (c, String.sub input 1 (String.length input - 1))  (* ← コピーが発生 *)
    else
      Failure (...)
  )
```

## 改善案の検討

### 案1: インデックスベースのアプローチ

文字列とインデックス（現在位置）のペアを状態として持つ。

**メリット:**
- 文字列のコピーが不要になる
- メモリ使用量が大幅に削減される
- 実装が比較的シンプル

**デメリット:**
- パーサーの型が変わる: `type 'a parser = string -> int -> ('a * int) parse_result`
- 既存のコードを全面的に書き換える必要がある
- インデックスの管理が煩雑になる可能性

**実装イメージ:**
```ocaml
type 'a parser = string -> int -> ('a * int, error) result

let satisfy pred input pos =
  if pos >= String.length input then
    Error "Unexpected end of input"
  else if pred input.[pos] then
    Ok (input.[pos], pos + 1)
  else
    Error "Character does not satisfy predicate"
```

### 案2: Angstromなどの既存パーサーライブラリの使用

Angstromは高性能なパーサーコンビネーターライブラリで、内部的にバッファベースのアプローチを採用している。

**メリット:**
- 高度に最適化されたパフォーマンス
- バックトラッキング、エラーメッセージなどの機能が充実
- メンテナンスされているライブラリを利用できる

**デメリット:**
- 外部依存が増える
- 学習コストがかかる
- カスタマイズの自由度が下がる
- PoC段階での過剰な依存になる可能性

### 案3: Sedlexによるレクサーの分離

レクシング（トークン化）とパージング（構文解析）を分離し、Sedlexでレクサーを実装する。

**メリット:**
- 字句解析のパフォーマンスが向上
- Unicode対応が容易
- 関心の分離ができる

**デメリット:**
- ppxによるビルドプロセスの複雑化
- 現在のモナディックなパーサーコンビネーターのアプローチと異なる
- レクサーとパーサーの2段構成になり、実装が複雑になる

### 案4: 現状維持（最適化の延期）

現時点ではパフォーマンスが問題になっていないため、何もしない。

**メリット:**
- 実装コストがゼロ
- シンプルなコードが維持される
- 他の機能開発に注力できる

**デメリット:**
- 将来的にパフォーマンス問題が顕在化する可能性
- 後で書き直すコストが大きくなる可能性

## パフォーマンス計測の必要性

改善を行う前に、実際のパフォーマンスを計測すべきである：

1. **ベンチマークの作成**: 様々なサイズのLispプログラムでパース時間を計測
2. **メモリプロファイリング**: GC統計やメモリ使用量を確認
3. **ボトルネックの特定**: パフォーマンスの問題が実際にString.subにあるか確認

計測結果に基づいて、最適化の優先度を判断する。

## 推奨される方向性

### 短期的: 案4（現状維持）

- 現在はPoCフェーズであり、機能の実装を優先する
- パフォーマンス問題が実際に発生していない
- パーサーの機能が安定してから最適化を検討する

### 中期的: ベンチマークと計測

- 基本的な機能が実装できたタイミングでベンチマークを作成
- 実際のパフォーマンス問題を定量的に把握
- 最適化のROI（投資対効果）を評価

### 長期的: 案1（インデックスベース）または案2（Angstrom）

計測結果に基づいて判断：

- **軽度の問題の場合**: 案1を採用。実装の制御を保ちつつパフォーマンス改善
- **深刻な問題の場合**: 案2を採用。実証済みの高性能ライブラリに移行

## 参考資料

- [Angstrom - Parser combinators built for speed and memory efficiency](https://github.com/inhabitedtype/angstrom)
- [Sedlex - Unicode-friendly lexer generator](https://github.com/ocaml-community/sedlex)
- [Real World OCaml - Parsing with OCamllex and Menhir](https://dev.realworldocaml.org/parsing-with-ocamllex-and-menhir.html)
- ["Functional Pearl: Monadic Parsing in Haskell"](https://www.cs.nott.ac.uk/~pszgmh/pearl.pdf) - パーサーコンビネーターの理論的背景

## 今後のアクション

1. ドキュメントとして本ADRを保存
2. 機能実装を優先し、パーサーAPIを安定させる
3. 適切なタイミング（例: v0.1リリース前）でベンチマークを実装
4. 計測結果に基づいて最適化戦略を再検討
