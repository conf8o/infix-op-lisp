# Lisp表現からOCamlのparsetreeに変換するプログラムの実装方針

## パフォーマンスよりも理解しやすさを優先する

- 関数は単一責務を意識し、小さい関数で大きな関数を作る。
- 関数名は意図が伝わる命名にする。意図が不明瞭な略語は使わない。
- 入出力は別の関数を用意する

## parsetreeを実装するにあたって参考にするドキュメント

PoC/lisp_to_ocaml/docs/parsetree_conversion.md