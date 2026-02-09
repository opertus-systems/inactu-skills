(module
  (import "provenact" "input_len" (func $input_len (result i32)))
  (import "provenact" "input_read" (func $input_read (param i32 i32 i32) (result i32)))
  (import "provenact" "fs_write_file" (func $fs_write_file (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 0) "/tmp/provenact-fs/out.txt")
  (func (export "run") (result i32)
    (local $n i32)
    call $input_len
    local.set $n
    i32.const 64
    i32.const 0
    local.get $n
    call $input_read
    drop
    i32.const 0
    i32.const 22
    i32.const 64
    local.get $n
    call $fs_write_file
  )
)
