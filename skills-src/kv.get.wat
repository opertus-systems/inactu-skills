(module
  (import "provenact" "kv_get" (func $kv_get (param i32 i32 i32 i32) (result i32)))
  (import "provenact" "output_write" (func $output_write (param i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 0) "default")
  (func (export "run") (result i32)
    (local $n i32)
    i32.const 0
    i32.const 7
    i32.const 64
    i32.const 4096
    call $kv_get
    local.set $n
    local.get $n
    i32.const 0
    i32.lt_s
    if
      i32.const 1
      return
    end
    i32.const 64
    local.get $n
    call $output_write
    drop
    i32.const 0
  )
)
