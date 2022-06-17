module imdclude

import os
import log

pub struct Document {
pub:
	relative_path_given bool
	name                string // name is the name and extension of the doc file
	rel_path            string // ref_path is the relative path of the doc file
	abs_path            string // abs_path is the full absolute path of the doc file
mut:
	content       []string
	file          os.File
	included_docs map[int]Document
}

pub fn new_document(rel_path string) Document {
	return Document{
		relative_path_given: !os.is_abs_path(rel_path)
		name: os.base(rel_path)
		rel_path: rel_path
		abs_path: os.abs_path(rel_path)
	}
}

pub fn (d Document) output_content_and_includes() {
	d.output_content()
	d.output_includes()
}

pub fn (d Document) output_content_and_includes_nested_too() {
	d.output_content_and_includes()
	for _, incl in d.included_docs {
		incl.output_content_and_includes_nested_too()
	}
}

pub fn (d Document) output_content() {
	println("DOC $d.name's content:")

	max_line_index_len := d.content.len.str().split('').len
	for i, line in d.content {
		line_index_len := i.str().split('').len
		mut padding_prefix := ' '
		for li := line_index_len; li < max_line_index_len; li++ {
			padding_prefix += ' '
		}
		println('[$i]($padding_prefix)$line')
	}
}

pub fn (d Document) output_content_nested_too() {
	d.output_content()
	for _, incl in d.included_docs {
		incl.output_content_nested_too()
	}
}

pub fn (d Document) output_includes() {
	if d.included_docs.len == 0 {
		println('DOC $d.name HAS NO INCLUDES')
		return
	}

	mut list_str_header := "DOC $d.name's INCLUDES: ["
	for i, incl in d.included_docs {
		list_str_header = '$list_str_header\n\t$incl.name on line ${i + 1}'
		if i + 1 < d.included_docs.len {
			list_str_header += ','
		}
	}
	list_str_header += '\n]'
	println(list_str_header)
}

pub fn (d Document) output_includes_nested_too() {
	d.output_includes()
	for _, incl in d.included_docs {
		incl.output_includes_nested_too()
	}
}

pub fn (mut d Document) resolve_includes(mut log log.Logger) ? {
	d.read_content(mut log) or { return err }
	d.find_includes_within_content(mut log) or { return err }
	d.resolve_includes_includes(mut log) or { return err }
}

pub fn (mut d Document) resolve_includes_to_content() {
	mut line_pos_offset := 0
	for line_pos, mut incl in d.included_docs {
		adjusted_line_pos := line_pos_offset + line_pos
		if incl.included_docs.len > 0 {
			incl.resolve_includes_to_content()
		}
		mut resolved_content := []string{}
		resolved_content.insert(resolved_content.len, d.content[..adjusted_line_pos])
		resolved_content.insert(resolved_content.len, incl.content)
		resolved_content.insert(resolved_content.len, d.content[safe_slice_high_index(adjusted_line_pos,
			d.content.len)..])
		d.content = resolved_content
		line_pos_offset += incl.content.len
	}
}

pub fn (mut d Document) write_content_to_disk(mut log log.Logger) ? {
	log.debug("attempting to write content to '$d.abs_path'")
	os.truncate(d.abs_path, 0) or {
		return error("unable to wipe '$d.abs_path' file content: $err")
	}

	os.write_file(d.abs_path, d.content.join_lines()) or {
		return error("unable to write '$d.abs_path' file content: $err")
	}
}

fn safe_slice_high_index(i int, len int) int {
	if len > 0 && i != len {
		return i + 1
	}

	return i
}

fn (mut d Document) resolve_includes_includes(mut log log.Logger) ? {
	for _, mut incl in d.included_docs {
		incl.resolve_includes(mut log) or { return err }
	}
}

fn (mut d Document) read_content(mut log log.Logger) ? {
	log.debug("attempting to read content from '$d.abs_path'")
	d.content = os.read_lines(d.abs_path) or {
		return error("unable read '$d.abs_path' file content: $err")
	}
}

fn (mut d Document) find_includes_within_content(mut log log.Logger) ? {
	log.debug('searching within $d.abs_path file content lines for includes...')

	for i, cl in d.content {
		mut cl_copy := cl
		cl_copy = cl.trim_space()
		if cl_copy.len == 0 {
			log.debug('skipping $i (blank line)')
			continue
		}

		mut proclogline := 'processing line #$i -> $cl_copy'
		if cl_copy.starts_with('#include') {
			proclogline = '$proclogline [FOUND INCLUDE]'

			cl_copy = cl_copy.replace('#include', '')
			line_parts := cl_copy.fields() // extract remaining whitespace delim'd line content into list
			if line_parts.len != 1 {
				log.debug(proclogline)
				log.error('include line does not match expected pattern: #include filename.md\\n')
				continue
			}

			doc_abs_path := d.convert_include_stmt_to_abs_path_rel_to_parent(line_parts[0])
			proclogline = '$proclogline ($doc_abs_path)'
			log.debug(proclogline)

			d.included_docs[i] = new_document(doc_abs_path)
		} else {
			log.debug('$proclogline [NO INCLUDE]')
		}
	}
}

fn (d Document) convert_include_stmt_to_abs_path_rel_to_parent(statement string) string {
	if os.is_abs_path(statement) {
		return statement
	}

	return os.join_path(d.abs_path.replace(d.name, ''), statement)
}
