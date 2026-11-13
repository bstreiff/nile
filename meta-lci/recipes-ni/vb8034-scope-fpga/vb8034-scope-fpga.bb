# This recipe is only buildable for internal builders.

DESCRIPTION = "VB8034 Scope FPGA bitfile (test recipe)"
SUMMARY = "VB8034 Scope FPGA bitfile (test recipe)"
LICENSE = "CLOSED"

PV = "1.0.0.8-manual-hasissues-users-dlarsen-virtualbench+26101216.b673b9ad"
SRC_URI = "nuget://rnd-nuget-pre/ni.hw-DAQ.VirtualBench.VB8034Scope/${PV};sha256sum=bf1009df7c7f110729bf047677889efc2edefea1e221b0ba3018533d0344bebf"

S = "${WORKDIR}/nuget"

do_install() {
	install -d ${D}/lib/firmware
	install -m 0644 ${S}/vb8034_scope_synth/bitfile/vb8034_scope_synth.bit ${D}${nonarch_base_libdir}/firmware/vb8034_scope_synth.bit
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/vb8034_scope_synth.bit"
