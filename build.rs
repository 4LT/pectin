use std::fs;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=about.hbs");

    let out = Command::new("cargo")
        .arg("about")
        .arg("generate")
        .arg("about.hbs")
        .output()
        .expect("Failed to run \"cargo about generate\"");

    if !out.status.success() {
        panic!("Process exited with non-zero status code");
    }

    let licenses_dict_text = String::from_utf8_lossy(&out.stdout);
    let licenses_dict_text = licenses_dict_text.replace("&quot;", r#"\""#);
    let licenses_dict_text = licenses_dict_text.replace("&lt;", "<");
    let licenses_dict_text = licenses_dict_text.replace("&gt;", ">");
    let licenses_dict_text = licenses_dict_text.replace("&#x27;", "\x27");

    fs::write("src/licenses.tcldict", licenses_dict_text)
        .expect("Failed to write to \"src/licenses.tcldict\"");

    let version = env!("CARGO_PKG_VERSION");

    fs::write(
        "src/build.tcldict",
        format!(
            r#"version {version}
"#
        ),
    )
    .expect("Failed to write to \"src/build.tcldict\"");
}
