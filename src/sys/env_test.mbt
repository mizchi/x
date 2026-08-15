///|
test "environment access" {
  let key = "MIZCHI_X_ENV_TEST"
  let previous = get_env_var(key)
  set_env_var(key, "ok")
  assert_eq(get_env_var(key), Some("ok"))
  match previous {
    Some(value) => set_env_var(key, value)
    None => unset_env_var(key)
  }
}

///|
test "environment and arguments enumeration" {
  let _vars = get_env_vars()
  let _args = get_cli_args()
}
