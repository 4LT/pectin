use std::env;
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
    let repo_name = env!("CARGO_PKG_REPOSITORY");
    let target = env::var("TARGET").unwrap();
    let profile = env::var("PROFILE").unwrap();

    let repo_res = git2::Repository::open(".");
    let (commit, branch, dirty) = match repo_res {
        Ok(repo) => {
            let reference = repo.head();
            let oid_res = reference.map(|r| r.target());

            let (tree, c) = match oid_res {
                Ok(Some(oid)) => (
                    repo.find_commit(oid)
                        .map_err(|e| {
                            warn("Can't get commit for HEAD");
                            e
                        })
                        .and_then(|commit| commit.tree())
                        .map_err(|e| {
                            warn("Can't find tree assoc. with HEAD");
                            e
                        })
                        .ok(),
                    oid.to_string(),
                ),
                Ok(None) => {
                    warn("No ref HEAD");
                    warn("Setting \"commit\" to \"Unknown\"");
                    (None, "Unknown".to_string())
                }
                Err(err) => {
                    warn(format!("Failed to get ref HEAD: {err}"));
                    warn("Setting \"commit\" to \"Unknown\"");
                    (None, "Unknown".to_string())
                }
            };

            let branch_obj: Option<git2::Branch> = repo
                .branches(Some(git2::BranchType::Local))
                .map(|mut branches| {
                    branches.find_map(|branch_res| {
                        if let Ok((branch, _)) = branch_res {
                            if branch.is_head() {
                                Some(branch)
                            } else {
                                None
                            }
                        } else {
                            None
                        }
                    })
                })
                .map_err(|e| {
                    warn("Can't get branches");
                    warn("Setting \"branch\" to \"Unknown\"");
                    e
                })
                .unwrap_or(None);

            let b: String = branch_obj
                .and_then(|branch| {
                    branch
                        .name()
                        .unwrap_or_else(|e| {
                            warn(format!("Can't get branch name: {e}"));
                            None
                        })
                        .map(String::from)
                })
                .unwrap_or("Unknown".to_string());

            let d = repo.state() != git2::RepositoryState::Clean;
            let idx_res = repo.index();

            let d = d
                || match idx_res {
                    Ok(idx) => !idx.is_empty(),
                    Err(err) => {
                        warn(format!("Can't get index: {err}"));
                        warn("Assuming dirty");
                        true
                    }
                };

            let d = d
                || repo
                    .diff_tree_to_workdir_with_index(
                        tree.as_ref(),
                        Some(git2::DiffOptions::new().include_untracked(true)),
                    )
                    .map(|diff| diff.deltas().len() > 0)
                    .map_err(|e| {
                        warn("Failed to diff working dir against HEAD");
                        warn("Assuming dirty");
                        e
                    })
                    .unwrap_or(true);

            (c, b, d)
        }
        Err(err) => {
            warn(format!("Failed to open current repository: {err}"));
            warn("Setting \"branch\" and \"commit\" to \"Unknown\"");
            ("Unknown".to_string(), "Unknown".to_string(), true)
        }
    };

    if dirty {
        warn("Working directory is dirty, or failed to get repo stats");
    }

    fs::write(
        "src/build.tcldict",
        format!(
            r#"version {version}
            repo {repo_name}
            target {target}
            profile {profile}
            commit {commit}
            branch {branch}
            dirty {}
"#,
            if dirty { 1 } else { 0 }
        ),
    )
    .unwrap();
}
