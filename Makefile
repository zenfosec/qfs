# $Id$
#
# Created 2012/07/27
# Author: Mike Ovsiannikov
#
# Copyright 2012-2016 Quantcast All rights reserved.
#
# This file is part of Quantcast File System.
#
# Licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# Do not assume GNU Make. Keep this makefile as simple as possible.

BUILD_TYPE=release
CMAKE_OPTIONS=-D CMAKE_BUILD_TYPE=RelWithDebInfo
CMAKE=cmake
MAKE_OPTIONS=
QFSTEST_OPTIONS=
JAVA_BUILD_OPTIONS=
QFSHADOOP_VERSIONS=0.23.11  1.0.4  1.1.2  2.5.1  2.7.2  2.7.7  2.8.5  2.9.2  2.10.1  3.1.4  3.2.2  3.3.1

.PHONY: all
all: build

.PHONY: dir
dir:
	mkdir -p build/${BUILD_TYPE}

.PHONY: run-cmake
run-cmake: dir
	cd build/${BUILD_TYPE} && ${CMAKE} ${CMAKE_OPTIONS} ../..

.PHONY: build
build: run-cmake
	cd build/${BUILD_TYPE} && $(MAKE) ${MAKE_OPTIONS} install

.PHONY: java
java: build
	./src/java/javabuild.sh ${JAVA_BUILD_OPTIONS} clean
	./src/java/javabuild.sh ${JAVA_BUILD_OPTIONS}

.PHONY: hadoop-jars
hadoop-jars: java
	if mvn --version >/dev/null 2>&1 ; then \
	    ./src/java/javabuild.sh ${JAVA_BUILD_OPTIONS} clean && \
	    for hadoop_version in ${QFSHADOOP_VERSIONS}; do \
	        ./src/java/javabuild.sh \
	            ${JAVA_BUILD_OPTIONS} "$${hadoop_version}" \
	            || exit 1; \
	    done \
	; fi

.PHONY: tarball
tarball: hadoop-jars
	cd build && \
	myuname=`uname -s`; \
	myarch=`cc -dumpmachine 2>/dev/null | cut -d - -f 1` ; \
	[ x"$$myarch" = x ] && \
	    myarch=`gcc -dumpmachine 2>/dev/null | cut -d - -f 1` ; \
	[ x"$$myarch" = x ] && myarch=`uname -m` ; \
	if [ x"$$myuname" = x'Linux' -a \( -f /etc/issue -o -f /etc/system-release \) ]; then \
		if [ -f /etc/system-release ]; then \
			myflavor=`head -n 1 /etc/system-release | cut -d' ' -f1` ; \
			myflavor="$$myflavor-`head -n 1 /etc/system-release | sed -e 's/^.* *release *//' | cut -d' ' -f1 | cut -d. -f1`" ; \
		else \
			myflavor=`head -n 1 /etc/issue | cut -d' ' -f1` ; \
			if [ x"$$myflavor" = x'Ubuntu' ]; then \
				myflavor="$$myflavor-`head -n 1 /etc/issue | cut -d' ' -f2 | cut -d. -f1,2`" ; \
			elif [ x"$$myflavor" = x ]; then \
				myflavor=$$myuname ; \
			else \
				myflavor="$$myflavor-`head -n 1 /etc/issue | cut -d' ' -f3 | cut -d. -f1,2`" ; \
			fi ; \
		fi ; \
	else \
	    if echo "$$myuname" | grep CYGWIN > /dev/null; then \
		myflavor=cygwin ; \
	    else \
		myflavor=$$myuname ; \
	    fi ; \
	fi ; \
	qfsversion=`../src/cc/common/buildversgit.sh --release` ; \
	tarname="qfs-$$myflavor-$$qfsversion-$$myarch" ;\
	tarname=`echo "$$tarname" | tr A-Z a-z` ; \
	{ test -d tmpreldir || mkdir tmpreldir; } && \
	rm -rf "tmpreldir/$$tarname" && \
	mkdir "tmpreldir/$$tarname" && \
	cp -r ${BUILD_TYPE}/bin ${BUILD_TYPE}/lib ${BUILD_TYPE}/include ../scripts ../webui \
	     ../examples ../benchmarks "tmpreldir/$$tarname/" && \
	if ls -1 ./java/qfs-access/qfs-access-*.jar > /dev/null 2>&1; then \
	    cp ./java/qfs-access/qfs-access*.jar "tmpreldir/$$tarname/lib/"; fi && \
	if ls -1 ./java/hadoop-qfs/hadoop-*.jar > /dev/null 2>&1; then \
	    cp ./java/hadoop-qfs/hadoop-*.jar "tmpreldir/$$tarname/lib/"; fi && \
	tar cvfz "$$tarname".tgz -C ./tmpreldir "$$tarname" && \
	rm -rf tmpreldir

.PHONY: python
python: build
	cd build/${BUILD_TYPE} && python ../../src/cc/access/kfs_setup.py build

.PHONY: mintest
mintest: hadoop-jars
	cd build/${BUILD_TYPE} && \
	../../src/test-scripts/qfstest.sh -auth ${QFSTEST_OPTIONS}

.PHONY: test
test: mintest
	cd build/${BUILD_TYPE} && \
	echo '--------- QC RS recovery test ---------' && \
	../../src/test-scripts/recoverytest.sh && \
	echo '--------- Jerasure recovery test ------' && \
	filecreateparams='fs.createParams=1,6,3,1048576,3,15,15' \
	../../src/test-scripts/recoverytest.sh && \
	if [ -d qfstest/certs ]; then \
		echo '--------- Test without authentication --------' && \
		../../src/test-scripts/qfstest.sh -noauth ${QFSTEST_OPTIONS} ; \
	fi

.PHONY: rat
rat: dir
	cd build/${BUILD_TYPE} && ../../scripts/rat.sh ../..

.PHONY: clean
clean:
	rm -rf build
