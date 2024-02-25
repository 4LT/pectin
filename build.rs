use std::fs;
use std::process::Command;

fn warn(mesg: impl std::fmt::Display) {
    println!("cargo:warning={mesg}");
}

fn main() {
    println!("cargo:rerun-if-changed=about.hbs");

    let out = Command::new("cargo")
        .arg("about")
        .arg("generate")
        .arg("about.hbs")
        .output()
        .expect("Failed to run \"cargo about generate\"");

    let license_dict = if out.status.success() {
        String::from_utf8_lossy(&out.stdout)
            .replace("&quot;", r#"\""#)
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&#x27;", "\x27")
    } else {
        warn("\"cargo about\" failed (not installed?)");
        warn("Skipping compilation of licenses");
        String::from("")
    };

    fs::write("src/licenses.tcldict", license_dict).unwrap();

    let version = env!("CARGO_PKG_VERSION");
    let repo = env!("CARGO_PKG_REPOSITORY");

    fs::write(
        "src/build.tcldict",
        format!(
            r#"version {version}
            repo {repo}
"#
        ),
    )
    .unwrap();
}
