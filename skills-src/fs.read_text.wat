(module
  (import "provenact" "input_len" (func $input_len (result i32)))
  (import "provenact" "input_read" (func $input_read (param i32 i32 i32) (result i32)))
  (import "provenact" "fs_read_file" (func $fs_read_file (param i32 i32 i32 i32) (result i32)))
  (import "provenact" "output_write" (func $output_write (param i32 i32) (result i32)))
  (memory (export "memory") 2)
  (func (export "run") (result i32)
    (local $path_len i32)
    (local $n i32)
    call $input_len
    local.set $path_len
    i32.const 0
    i32.const 0
    local.get $path_len
    call $input_read
    drop
    i32.const 0
    local.get $path_len
    i32.const 2048
    i32.const 65536
    call $fs_read_file
    local.set $n
    local.get $n
    i32.const 0
    i32.lt_s
    if
      i32.const 1
      return
    end
    i32.const 2048
    local.get $n
    call $output_write
    drop
    i32.const 0
  )
)
