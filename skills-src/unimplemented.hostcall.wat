(module
  (import "provenact" "output_write" (func $output_write (param i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 0) "UNIMPLEMENTED_HOSTCALL")
  (func (export "run") (result i32)
    i32.const 0
    i32.const 22
    call $output_write
    drop
    i32.const 78
  )
)
