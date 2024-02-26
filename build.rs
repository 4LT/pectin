use git_testament::{git_testament, CommitKind};
use std::env;
use std::fs;
use std::process::Command;

git_testament!(TESTAMENT);

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
    let repo_name = env!("CARGO_PKG_REPOSITORY");
    let target = env::var("TARGET").unwrap();
    let profile = env::var("PROFILE").unwrap();

    let commit = match TESTAMENT.commit {
        CommitKind::NoTags(hash, _) => hash,
        CommitKind::FromTag(_, hash, _, _) => hash,
        _ => "",
    };

    let branch = TESTAMENT.branch_name.unwrap_or("");
    let dirty = !TESTAMENT.modifications.is_empty();

    if commit == "" {
        warn("Unknown commit");
    }

    if branch == "" {
        warn("Unknown branch");
    }

    if dirty {
        warn("Working directory is dirty");
    }

    fs::write(
        "src/build.tcldict",
        format!(
            r#"version "{version}"
            repo "{repo_name}"
            target "{target}"
            profile "{profile}"
            commit "{commit}"
            branch "{branch}"
            dirty {}
"#,
            if dirty { 1 } else { 0 }
        ),
    )
    .unwrap();
}
