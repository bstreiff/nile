#
# Marks classes 

NILE_MIGRATE_CONFIG_CONF_DIR ?= "${datadir}/migrate-config"
NILE_MIGRATE_CONFIG_CONF ?= "${NILE_MIGRATE_CONFIG_CONF_DIR}/${PN}.conf"

do_install:append() {
    if [ -e "${WORKDIR}/nile-migrate-config" ]; then
        install -d "${D}${NILE_MIGRATE_CONFIG_CONF_DIR}"
        install -m 0644 "${WORKDIR}/nile-migrate-config/*.conf" "${D}${NILE_MIGRATE_CONFIG_CONF_DIR}"
    fi
}

python do_create_migrate_config_data() {
    for pkg in (d.getVar("PACKAGES") or "").split():
        bb.note("Creating nile-migrate-config data file for %s" % pkg)

        conffiles = d.getVar('NILE_MIGRATE_CONFFILES:%s' % pkg)
        if conffiles is None:
            conffiles = ""
        conffiles = conffiles.split()

        if len(conffiles) > 0:
            outpath = os.path.join(d.getVar("WORKDIR"), "nile-migrate-config", "%s.conf" % pkg)
            migratedata = open(outpath, 'w')
            for f in conffiles:
                migratedata.write('%s\n' % f)
            migratedata.close()
}

addtask create_migrate_config_data before do_install do_deploy after do_compile
