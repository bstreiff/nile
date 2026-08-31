#
# Marks classes 

NILE_MIGRATE_CONFFILES:${PN} ?= "${CONFFILES:${PN}}"

NILE_MIGRATE_CONFIG_CONF_DIR ?= "${datadir}/migrate-config"
NILE_MIGRATE_CONFIG_CONF ?= "${NILE_MIGRATE_CONFIG_CONF_DIR}/${PN}.conf"

do_install:append() {
	install -d "${D}${NILE_MIGRATE_CONFIG_CONF_DIR}"
}

python create_migrate_config_data() {
	# This is cribbed from get_conffiles in package.py
	# differences:
	# - different variable name
	# - we do not require that the file exists
	#   (e.g. it may be completely generated at runtime)

	conffiles = d.getVar('NILE_MIGRATE_CONFFILES:%s' % pkg)
	if conffiles is None:
		conffiles = d.getVar('NILE_MIGRATE_CONFFILES')
	if conffiles is None:
		conffiles = ""
	conffiles = conffiles.split()
	conf_orig_list = files_from_filevars(conffiles)[0]

	conf_list = []
	for f in conf_orig_list:
		if os.path.isdir(f) or os.path.islink(f):
			continue
		conf_list.append(f)

	# Remove the leading './'
	for i in range(0, len(conf_list)):
		conf_list[i] = conf_list[i][1:]

	if len(conf_list) > 0:
		migratedata = open(os.path.join(), 'w')
		for f in conf_list:
			migratedata.write('%s\n' % f)
		migratedata.close()
}

addtask create_migrate_config_data before do_install do_deploy after do_compile
