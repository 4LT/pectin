//use std::env;

//const CLANG_ARGS: &str = "BINDGEN_EXTRA_CLANG_ARGS_x86_64-pc-windows-gnu";

fn cross_windows() {
    //println!("cargo:rerun-if-env-changed={CLANG_ARGS}");
    //env::set_var(CLANG_ARGS, r#"-I"vendor/tcl/generic""#);
}

fn main() {
    if cfg!(not(windows)) {
        if build_target::target_os().unwrap() == build_target::Os::Windows {
            cross_windows();
        }
    }
}
