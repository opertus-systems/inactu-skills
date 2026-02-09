(module
  (import "provenact" "random_fill" (func $random_fill (param i32 i32) (result i32)))
  (import "provenact" "output_write" (func $output_write (param i32 i32) (result i32)))
  (memory (export "memory") 1)

  (func (export "run") (result i32)
    i32.const 0
    i32.const 16
    call $random_fill
    drop
    i32.const 0
    i32.const 16
    call $output_write
    drop
    i32.const 0
  )
)
