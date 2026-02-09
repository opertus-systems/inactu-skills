(module
  (import "provenact" "sha256_input_hex" (func $sha256_input_hex (param i32 i32) (result i32)))
  (import "provenact" "output_write" (func $output_write (param i32 i32) (result i32)))
  (memory (export "memory") 1)

  (func (export "run") (result i32)
    i32.const 0
    i32.const 64
    call $sha256_input_hex
    drop
    i32.const 0
    i32.const 64
    call $output_write
    drop
    i32.const 0
  )
)
