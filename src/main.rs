use quake_util::{bsp, BinParseError, BinParseResult};
use std::collections::HashMap;
use std::ffi::CString;
use std::fs::File;
use std::io::BufReader;
use std::path::Path;
use std::str::FromStr;
use std::time::Duration;
use tcl::{tclfn, Obj, TclResult};

#[derive(Clone)]
enum ReportField {
    Pass(String),
    Fail(String, String),
}

impl From<ReportField> for tcl::Obj {
    fn from(field: ReportField) -> Self {
        match field {
            ReportField::Pass(val) => {
                tcl::Obj::from(vec!["pass".to_string(), val])
            }
            ReportField::Fail(val, reason) => {
                tcl::Obj::from(vec!["fail".to_string(), val, reason])
            }
        }
    }
}

#[derive(Clone)]
enum ReportPayload {
    Error(String, String),
    Report(HashMap<String, ReportField>),
}

impl From<ReportPayload> for tcl::Obj {
    fn from(payload: ReportPayload) -> Self {
        match payload {
            ReportPayload::Error(kind, mesg) => {
                tcl::Obj::from(vec![kind, mesg])
            }
            ReportPayload::Report(fields) => tcl::Obj::from(fields),
        }
    }
}

#[derive(Clone)]
struct Report {
    pub filename: String,
    pub payload: ReportPayload,
}

impl From<Report> for tcl::Obj {
    fn from(report: Report) -> Self {
        let mut map = HashMap::new();
        map.insert("filename".to_string(), tcl::Obj::from(report.filename));

        match report.payload {
            pl @ ReportPayload::Report(_) => {
                map.insert("report".to_string(), tcl::Obj::from(pl));
            }
            pl @ ReportPayload::Error(_, _) => {
                map.insert("error".to_string(), tcl::Obj::from(pl));
            }
        }

        tcl::Obj::from(map)
    }
}

fn report_payload(
    path: impl AsRef<Path>,
) -> BinParseResult<HashMap<String, ReportField>> {
    let mut report_payload = HashMap::<String, ReportField>::new();
    let file = File::open(path.as_ref())?;
    let mut reader = BufReader::new(file);
    let mut parser = bsp::Parser::new(&mut reader)?;

    let vis_field = if parser.lump_empty(bsp::EntryOffset::Vis) {
        ReportField::Fail("No".to_string(), "VIS wasn't run".to_string())
    } else {
        ReportField::Pass("Yes".to_string())
    };

    let light_field = if parser.lump_empty(bsp::EntryOffset::Light) {
        ReportField::Fail("No".to_string(), "No lighting".to_string())
    } else {
        ReportField::Pass("Yes".to_string())
    };

    let version_field = match parser.version() {
        bsp::BSP_VERSION => ReportField::Pass("29".to_string()),
        bsp::BSP2_VERSION => ReportField::Pass("BSP2".to_string()),
        v => ReportField::Fail(
            "Unknown".to_string(),
            format!("Unknown version {v}"),
        ),
    };

    let empty_keyvalue = |key: &str| {
        ReportField::Fail(
            "<Nothing>".to_string(),
            format!("Empty field (no key '{key}')"),
        )
    };

    let mut title_field = empty_keyvalue("message");
    let mut track_field = empty_keyvalue("sounds");
    let mut exit_maps: Vec<String> = Vec::new();

    let qmap = parser.parse_entities()?;

    for entity in qmap.entities {
        let edict = entity.edict;
        let classname_value = edict.get(&CString::new("classname").unwrap());

        if let Some(classname) = classname_value {
            if classname == &CString::new("worldspawn").unwrap() {
                if let Some(title) =
                    edict.get(&CString::new("message").unwrap())
                {
                    title_field = if title.as_bytes().is_empty() {
                        ReportField::Fail(
                            "\"\"".to_string(),
                            "Empty string value".to_string(),
                        )
                    } else {
                        ReportField::Pass(title.to_string_lossy().to_string())
                    }
                }

                if let Some(track) = edict.get(&CString::new("sounds").unwrap())
                {
                    track_field = if track.as_bytes().is_empty() {
                        ReportField::Fail(
                            "\"\"".to_string(),
                            "Empty string value".to_string(),
                        )
                    } else {
                        let track_str = track.to_string_lossy().to_string();
                        let track_int = i32::from_str(&track_str).ok();

                        match track_int {
                            Some(track_num) if track_num < 1 => {
                                ReportField::Fail(
                                    track_num.to_string(),
                                    "Track no. < 1".to_string(),
                                )
                            }
                            Some(track_num) if track_num > 255 => {
                                ReportField::Fail(
                                    track_num.to_string(),
                                    "Track no. > 255".to_string(),
                                )
                            }
                            Some(track_num) if track_num == 1 => {
                                ReportField::Fail(
                                    track_num.to_string(),
                                    "Track no. = 1 (data)".to_string(),
                                )
                            }
                            Some(track_num) if track_num == 2 => {
                                ReportField::Fail(
                                    track_num.to_string(),
                                    "Track no. = 2 (intro)".to_string(),
                                )
                            }
                            Some(track_num) if track_num == 3 => {
                                ReportField::Fail(
                                    track_num.to_string(),
                                    "Track no. = 3 (intermission)".to_string(),
                                )
                            }
                            Some(track_num) => {
                                ReportField::Pass(track_num.to_string())
                            }
                            None => ReportField::Fail(
                                format!("\"{track_str}\""),
                                "Not an integer".to_string(),
                            ),
                        }
                    };
                }
            } else if classname == &CString::new("trigger_changelevel").unwrap()
            {
                match edict.get(&CString::new("map").unwrap()) {
                    Some(map_name) => {
                        exit_maps.push(format!(
                            "\"{}\"",
                            map_name.to_string_lossy()
                        ));
                    }
                    None => {
                        exit_maps.push("<No Map>".to_string());
                    }
                }
            }
        }

        let target_value = edict.get(&CString::new("target").unwrap());
        if let Some(target) = target_value {
            if target.as_bytes().is_empty() {
                let targetname_value =
                    edict.get(&CString::new("targetname").unwrap());

                let targetname = targetname_value
                    .map(|s| format!("\"{}\"", s.to_string_lossy()))
                    .unwrap_or("<Unnamed>".to_string());

                report_payload.insert(
                    format!("{targetname} Target"),
                    ReportField::Fail(
                        "\"\"".to_string(),
                        "Target is empty string ".to_string(),
                    ),
                );
            }
        }
    }

    let filename = path.as_ref().file_name();
    let filename = filename.and_then(|f| f.to_str());

    let bad_exit = if filename == Some("start.bsp") {
        false
    } else {
        exit_maps.iter().any(|map_name| map_name != "\"start\"")
    };

    let exit_maps_str = exit_maps.join(",");

    let exit_field = if exit_maps.is_empty() {
        ReportField::Fail("<Nothing>".to_string(), "No map exit".to_string())
    } else if bad_exit {
        ReportField::Fail(exit_maps_str, "Exit to non-start map".to_string())
    } else {
        ReportField::Pass(exit_maps_str)
    };

    report_payload.insert("Changelevel".to_string(), exit_field);
    report_payload.insert("Title".to_string(), title_field);
    report_payload.insert("Track No.".to_string(), track_field);
    report_payload.insert("Version".to_string(), version_field);
    report_payload.insert("Vis".to_string(), vis_field);
    report_payload.insert("Lighting".to_string(), light_field);

    Ok(report_payload)
}

fn report(path_string: &str) -> TclResult<tcl::Obj> {
    let path = Path::new(path_string);
    let filename = path.file_name();
    let filename = filename.and_then(|f| f.to_str());
    let filename = filename.unwrap_or(path_string).to_string();

    let payload = match report_payload(path) {
        Ok(report) => ReportPayload::Report(report),
        Err(BinParseError::Parse(error)) => {
            ReportPayload::Error("Parse".to_string(), error)
        }
        Err(BinParseError::Io(error)) => {
            ReportPayload::Error("IO".to_string(), error.to_string())
        }
    };

    Ok(tcl::Obj::from(Report { filename, payload }))
}

fn main() -> Result<(), String> {
    let interp = tcl::Interpreter::new().map_err(|e| e.to_string())?;
    let licenses = Obj::from(include_str!("licenses.tcldict"));
    interp.set("licenses", licenses);

    let _report_cmd = tclfn!(
        &interp,
        fn build_report(path: String) -> TclResult<tcl::Obj> {
            report(&path)
        }
    );

    let tcl_src = include_str!("pectin.tcl");
    interp.run(tcl_src).map_err(|e| e.to_string())?;
    let mut done = false;

    while !done {
        std::thread::sleep(Duration::from_millis(1000 / 60));
        interp.update().map_err(|e| e.to_string())?;
        let root_cmd =
            interp.eval("info commands .").map_err(|e| e.to_string())?;

        if Vec::<String>::try_from(root_cmd).unwrap().is_empty() {
            done = true;
        }
    }

    Ok(())
}
