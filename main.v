module main

import os
import flag
import imdclude
import log

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(imdclude.name)
	fp.version(imdclude.version)
	fp.description(imdclude.description)
	fp.skip_executable()

	debug_mode := fp.bool("debug", `d`, false, "Enable debug mode")
	target_doc_path := fp.string_opt("target", `t`, "Document to process all include statements") or { '' }

	fp.finalize() or {} // handles builtin arguments (--help, -h, or --version)
						// but will ignore any undefined arguments passed in

	if target_doc_path.len == 0 {
		eprintln("ERROR: parameter 'target' not provided")
		exit(1)
	}

	mut logg := log.Log{}
	if debug_mode {
		logg.set_level(log.Level.debug)
	}

	mut target_doc := imdclude.new_document(target_doc_path)
	target_doc.resolve_includes(mut &logg) or {
		eprintln("ERROR: $err")
		exit(1)
	}
	target_doc.resolve_includes_to_content()

	target_doc.output_content()
}
