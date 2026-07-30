// guiintf-backend-contract
//
// MSEgui has ONE gui backend contract, lib/common/kernel/mseguiintf.inc, with
// several implementations: linux/mseguiintf.pas (X11), windows/mseguiintf.pas
// (gdi32), and any new target such as Wayland. Every implementation unit pulls
// the contract in with {$include ../mseguiintf.inc}.
//
// Measured on this repository before this rule was written:
//   - the contract declares 100 gui_* entry points once { } comments are
//     stripped (two are commented out and must never be demanded)
//   - both existing backends implement all 100. Zero exceptions.
//   - a gui_* was removed on purpose 11 times in 277 commits over 20 years,
//     so firing on a removal is a rare event, not noise.
//
// Two checks, neither duplicating FPC:
//   1. entry points the contract declares but this backend never implements.
//      FPC catches this only when the target is actually built, and MSEgui
//      cannot build a Wayland target at all yet, so CI never compiles it.
//   2. an entry point this unit implemented in the pre-image and no longer
//      does. Drop the declaration and the implementation together and the code
//      still compiles: no compiler can see it, only the pre-image can.
//
// Implementations are read from the AST (defProc = a definition with a body, so
// a bare forward declaration never counts as an implementation). The contract
// is a different file, reachable only as text through read_repo_file, so its
// declarations are scanned line-wise with { } comment tracking - two entry
// points really are commented out there and must never be demanded.
//
// The declared list is read from the contract at check time, never hard-coded:
// adding a 101st entry point requires no change here.

// Read an identifier at `from`, stopping at the first non-identifier char.
fn ident_at(s, from) {
    let out = "";
    let i = from;
    let n = s.len();
    while i < n {
        let c = s[i];
        if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
           || (c >= '0' && c <= '9') || c == '_' {
            out += c;
            i += 1;
        } else {
            break;
        }
    }
    out
}

// gui_* names declared in the contract. The contract is a different file,
// reachable only as text, so this scans line-wise at column 0 - where MSEgui
// writes every declaration - and tracks { } comments, because two entry points
// really are commented out there and must never be demanded of a backend.
// {$ ... } compiler directives are not comments.
fn declared_in_contract(src) {
    let names = [];
    let in_comment = false;
    for line in src.split("\n") {
        let t = line;

        if in_comment {
            let k = t.index_of("}");
            if k < 0 { continue; }
            t = t.sub_string(k + 1);
            in_comment = false;
            // a comment ended mid-line, so what follows is no longer column 0
            continue;
        }

        // Only column 0 counts: MSEgui declares and implements every gui_*
        // routine flush left, and nested locals are always indented.
        if t.len() == 0 { continue; }
        let c0 = t[0];
        if c0 == ' ' || c0 == '\t' {
            // still has to update comment state for multi-line comments
            if t.contains("{") && !t.contains("}") {
                let o = t.index_of("{");
                if !(o + 1 < t.len() && t[o + 1] == '$') { in_comment = true; }
            }
            continue;
        }

        // does this line open an unterminated { } comment?
        if t.contains("{") {
            let i = 0;
            while i < t.len() {
                if t[i] == '{' {
                    if i + 1 < t.len() && t[i + 1] == '$' {
                        let j = i;
                        while j < t.len() && t[j] != '}' { j += 1; }
                        i = j + 1;
                        continue;
                    }
                    if t.sub_string(i).index_of("}") < 0 { in_comment = true; }
                    t = t.sub_string(0, i);
                    break;
                }
                i += 1;
            }
        }

        if t.len() == 0 { continue; }
        let low = t.to_lower();
        let nm = "";
        if low.starts_with("function ") { nm = ident_at(low, 9); }
        else if low.starts_with("procedure ") { nm = ident_at(low, 10); }
        if nm.starts_with("gui_") && !names.contains(nm) { names.push(nm); }
    }
    names
}

// gui_* routines actually implemented in this unit, from the AST. A defProc
// node spans the whole routine - up to 604 lines here - so only its first line
// is folded: the header. Nested helpers are never named gui_*, so filtering on
// the prefix keeps this to the backend's own entry points.
fn implemented(matches) {
    let names = [];
    for m in matches {
        let head = m.text;
        let nl = head.index_of("\n");
        if nl >= 0 { head = head.sub_string(0, nl); }
        let low = head;
        low.trim();
        low = low.to_lower();
        let nm = "";
        if low.starts_with("function ") { nm = ident_at(low, 9); }
        else if low.starts_with("procedure ") { nm = ident_at(low, 10); }
        if nm.starts_with("gui_") && !names.contains(nm) { names.push(nm); }
    }
    names
}

fn missing_from(wanted, have) {
    let out = [];
    for nm in wanted {
        if !have.contains(nm) { out.push(nm); }
    }
    out
}

fn join_sample(items, limit) {
    let out = "";
    let i = 0;
    for it in items {
        if i >= limit { out += ", …"; break; }
        if i > 0 { out += ", "; }
        out += it;
        i += 1;
    }
    out
}

// ---------------------------------------------------------------- entry point

// Only backend implementations of the contract. Detected by content, not path,
// so behaviour is identical in the fixture harness and on a real file.
let text = file.new_text;
if type_of(text) == "()" { return; }
if !text.contains("mseguiintf.inc") { return; }

// Anchor findings on the include line - the one line every backend shares.
let anchor = 1;
let ln = 0;
for line in text.split("\n") {
    ln += 1;
    if line.contains("mseguiintf.inc") { anchor = ln; break; }
}

// The routine list is only trustworthy when the file parsed cleanly, so abstain
// on any file the parser could not read: silence beats a fabricated finding.
// This is not hypothetical. Before argot 0.2.119 taught the Pascal grammar that
// a record's last field may omit its `;` and that a label may sit on the empty
// statement before `end`, the X11 backend landed inside 1,921 ERROR nodes with
// only 21 of its 102 routines recoverable — which would have read as 81 missing
// entry points on a backend that is complete.
if ts_query("(ERROR) @e").len() > 0 { return; }

let now = implemented(ts_query("(defProc) @d"));

// --- check 2: an entry point this unit used to implement is gone -------------
if type_of(file.old_text) != "()" && ts_query_old("(ERROR) @e").len() == 0 {
    let before = implemented(ts_query_old("(defProc) @d"));
    if before.len() > 0 {
        let dropped = missing_from(before, now);
        if dropped.len() > 0 {
            report_span(anchor, anchor,
                "this change removes " + dropped.len() +
                " gui_* entry point(s) this backend previously implemented",
                #{
                    evidence: [
                        "removed: " + join_sample(dropped, 8),
                        "dropping the contract declaration alongside the implementation still compiles, and silently removes the feature from every target"
                    ],
                    symbol: "mseguiintf"
                }
            );
        }
    }
}

// --- check 1: the contract is not fully implemented --------------------------
// read_repo_file returns () when the contract is unreadable; stay silent then
// rather than guess.
let contract = read_repo_file("lib/common/kernel/mseguiintf.inc");
if type_of(contract) == "()" { return; }

let declared = declared_in_contract(contract);
if declared.len() == 0 { return; }

let missing = missing_from(declared, now);
if missing.len() > 0 {
    report_span(anchor, anchor,
        "this gui backend implements " + (declared.len() - missing.len()) +
        " of " + declared.len() +
        " gui_* entry points declared in the shared contract — " +
        missing.len() + " missing",
        #{
            evidence: [
                "missing: " + join_sample(missing, 8),
                "contract: lib/common/kernel/mseguiintf.inc",
                "both existing backends (X11, gdi32) implement all " + declared.len()
            ],
            symbol: "mseguiintf"
        }
    );
}
