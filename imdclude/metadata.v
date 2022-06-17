module imdclude

import v.vmod

const manifest = vmod.from_file('v.mod') or { panic(err) }

pub const (
	version     = manifest.version
	name        = manifest.name
	description = manifest.name
)
