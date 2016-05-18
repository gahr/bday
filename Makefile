PREFIX?=	/usr/local
TCLSH?=		/usr/bin/env tclsh8.6
TCLLAUNCHER?=	${PREFIX}/bin/tcllauncher

.PHONY: test
test:
	${TCLSH} test/all.tcl ${TESTFLAGS}

install:
	rm -rf ${PREFIX}/lib/bday
	cp ${TCLLAUNCHER} ${PREFIX}/bin/bday
	mkdir -p ${PREFIX}/lib/bday
	cp -r lib/* ${PREFIX}/lib/bday
	cp bin/bday ${PREFIX}/lib/bday/main.tcl
