(module
  (import "provenact" "time_now_unix" (func $time_now_unix (result i64)))
  (func (export "run") (result i32)
    call $time_now_unix
    i32.wrap_i64
  )
)
