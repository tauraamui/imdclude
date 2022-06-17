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

	debug_mode := fp.bool('debug', `d`, false, 'Enable debug mode')
	target_doc_path := fp.string('target', `t`, '', 'Document to process all include statements')
	write_to_stdout := fp.bool('console', `c`, false, 'Write content to console instead of target document')
	backup_doc := fp.bool('backup', `b`, false, 'Backup document before processing')

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
	target_doc.read_content(mut &logg) or {
		eprintln('ERROR: $err')
		exit(1)
	}

	if backup_doc {
		imdclude.backup_document(target_doc) or {
			eprintln('ERROR: $err')
			exit(1)
		}
	}

	target_doc.resolve_includes(mut &logg) or {
		eprintln('ERROR: $err')
		exit(1)
	}
	target_doc.resolve_includes_to_content()

	if write_to_stdout {
		target_doc.output_content()
		exit(0)
	}

	target_doc.write_content_to_disk(mut &logg) or {
		eprintln('ERROR: $err')
		exit(1)
	}
}
