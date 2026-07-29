// Placement convention mined by `argot conventions`: each subsystem's
// registration entry point is used only inside the directory that owns it.
// Measured concentration at fit time (2026-07-29, 524-file corpus):
//
//   registerlangconsts         8 files in lib/common/lang_consts    0 outside
//   registerformat            11 files in lib/common/image          0 outside
//   regopensslinit            14 files in lib/common/crypto         0 outside
//   registercomponenttabhints 17 files in lib/common/regcomponents  1 outside*
//
//   * that one is designutils/msedesignintf.pas, which *declares* the routine
//     that regcomponents/ calls — a declaration site, not a leak, so it counts
//     as home below.
//
// The rule is the contrapositive: one of these names outside its home is a
// finding. Object Pascal is case-insensitive, so match on lowercased text.
//
// Note on fixtures: under `argot rules test`, file.path is
// "tests/<case>/input.pas" — so a case directory named exactly `crypto`
// exercises the in-home (silent) branch. Renaming that case would break it.

let features = [
    #{ name: "registerlangconsts",
       homes: ["/lang_consts/"],
       owner: "lib/common/lang_consts" },
    #{ name: "registerformat",
       homes: ["/image/"],
       owner: "lib/common/image" },
    #{ name: "regopensslinit",
       homes: ["/crypto/"],
       owner: "lib/common/crypto" },
    #{ name: "registercomponenttabhints",
       homes: ["/regcomponents/", "/designutils/msedesignintf.pas"],
       owner: "lib/common/regcomponents" },
];

// Leading slash so a home directory at the repo root still matches.
let path = "/" + file.path;

for id in ts_query("(identifier) @x") {
    let text = id.text.to_lower();

    for f in features {
        if text != f.name {
            continue;
        }

        let at_home = false;
        for h in f.homes {
            if path.contains(h) {
                at_home = true;
            }
        }

        if !at_home {
            report(
                id.line,
                f.name + "() belongs in " + f.owner +
                " — that subsystem owns its registration; calling it from here spreads registration across the tree"
            );
        }

        break;
    }
}
