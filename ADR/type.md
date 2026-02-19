# 型定義方法議論

- `type`で全てまかなう vs `struct`, `enum`, `alias` を全部別で用意する。

## `type`

OCamlは全部 `type` でまかなっている

```ocaml
(* struct *)
type struct_type = { x : int; y : int}

(* enum *)
type enum_type =
    | A
    | B of int

(* alias *)
type alias_type = float * float
```

## 分ける

Haskell, Rustは、区別したり、ちょっと特殊な形をとる

```haskell
newtype RecordType1 = Record { x :: Int, y :: Int }

newtype Email = Email String

data RecordType2 = Record2 { x :: Int, y :: Int }

data EnumType = A | B Int

type Alias = (Float, Float)
```

```rust
struct Record {
    x: i64,
    y: i64
}

struct Email(String);

enum Enum {
    A,
    B(i64)
}

type Alias = (f64, f64);
```
