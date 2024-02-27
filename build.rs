use git_testament::{git_testament, CommitKind};
use std::env;
use std::fs;
use std::process::Command;

fn warn(fatal: bool, mesg: impl std::fmt::Display) {
    if fatal {
        panic!("{mesg}");
    } else {
        println!("cargo:warning={mesg}");
    }
}

fn main() {
    println!("cargo:rerun-if-changed=.git");
    git_testament!(TESTAMENT);
    println!("cargo:rerun-if-changed=about.hbs");
    println!("cargo:rerun-if-env-changed=WARN_FATAL");

    let out = Command::new("cargo")
        .arg("about")
        .arg("generate")
        .arg("about.hbs")
        .output()
        .expect("Failed to run \"cargo about generate\"");

    let warn_is_fatal = env::var("WARN_FATAL")
        .map_err(|_| ())
        .and_then(|x| x.parse::<i32>().map_err(|_| ()))
        .unwrap_or(0)
        != 0;

    let license_dict = if out.status.success() {
        String::from_utf8_lossy(&out.stdout)
            .replace("&quot;", r#"\""#)
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&#x27;", "\x27")
    } else {
        warn(warn_is_fatal, "\"cargo about\" failed (not installed?)");
        warn(false, "Skipping compilation of licenses");
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

    if commit.is_empty() {
        warn(warn_is_fatal, "Unknown commit");
    }

    if branch.is_empty() {
        warn(warn_is_fatal, "Unknown branch");
    }

    if dirty {
        warn(warn_is_fatal, "Working directory is dirty");
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
