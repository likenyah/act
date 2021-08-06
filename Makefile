# SPDX-License-Identifier: 0BSD
# -----------------------------------------------------------------------------

V_MAJOR = 0
V_MINOR = 1
V_PATCH = 0
V_EXTRA =
VERSION = $(V_MAJOR).$(V_MINOR).$(V_PATCH)$(V_EXTRA)

all:

man: act.1

clean:
	rm -f act.1

distclean: clean

act.1: act.1.adoc
	asciidoctor -a VERSION="$(VERSION)" -b manpage -o $@ $<

.PHONY: all clean distclean
