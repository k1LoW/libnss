# The base of this code is https://github.com/pyama86/stns/blob/master/Makefile
CC=gcc
CFLAGS=-Wall -Wstrict-prototypes -Werror -fPIC -std=c99 -D_GNU_SOURCE -I/usr/local/curl/include

LIBRARY=libnss_stns.so.2.0
KEY_WRAPPER=stns-key-wrapper
LINKS=libnss_stns.so.2 libnss_stns.so
LD_SONAME=-Wl,-soname,libnss_stns.so.2
VERSION = $(shell cat version)

PREFIX=/usr
LIBDIR=$(PREFIX)/lib64
ifeq ($(wildcard $(LIBDIR)/.*),)
LIBDIR=$(PREFIX)/lib
endif
BINDIR=$(PREFIX)/lib/stns
BINSYMDIR=$(PREFIX)/local/bin/

BUILD=tmp/libs
CACHE=/var/cache/stns
CRITERION_VERSION=2.3.2
SHUNIT_VERSION=2.1.6
CURL_VERSION=7.64.0
SOURCES=Makefile stns.h stns.c stns*.c stns*.h toml.h toml.c parson.h parson.c stns.conf.example test
DIST ?= unknown

default: build
ci: curl depsdev test integration
test: testdev ## Test with dependencies installation

build_dir: ## Create directory for build
	test -d $(BUILD) || mkdir -p $(BUILD)

cache_dir: ## Create directory for cache
	test -d $(CACHE) || mkdir -p $(CACHE)

local_build: curl build
curl: build_dir
	test -d $(BUILD)/curl-$(CURL_VERSION) || (curl -sL https://curl.haxx.se/download/curl-$(CURL_VERSION).tar.gz -o $(BUILD)/curl-$(CURL_VERSION).tar.gz && cd $(BUILD) && tar xf curl-$(CURL_VERSION).tar.gz)
	test -f /usr/local/curl/lib/libcurl.a || (cd $(BUILD)/curl-$(CURL_VERSION) && LDFLAGS=-L/usr/lib/x86_64-linux-gnu ./configure \
	  --with-ssl \
	  --enable-libcurl-option \
	  --disable-shared \
	  --enable-static \
	  --prefix=/usr/local/curl \
	  --disable-ldap \
	  --disable-sspi \
	  --without-librtmp \
	  --disable-ftp \
	  --disable-file \
	  --disable-dict \
	  --disable-telnet \
	  --disable-tftp \
	  --disable-rtsp \
	  --disable-pop3 \
	  --disable-imap \
	  --disable-smtp \
	  --disable-gopher \
	  --disable-smb \
	  --without-libidn && make && make install)

depsdev: build_dir cache_dir ## Installing dependencies for development
	test -f $(BUILD)/criterion.tar.bz2 || curl -sL https://github.com/Snaipe/Criterion/releases/download/v$(CRITERION_VERSION)/criterion-v$(CRITERION_VERSION)-linux-x86_64.tar.bz2 -o $(BUILD)/criterion.tar.bz2
	cd $(BUILD); tar xf criterion.tar.bz2; cd ../
	test -d /usr/include/criterion || mv $(BUILD)/criterion-v$(CRITERION_VERSION)/include/criterion /usr/include/criterion && mv $(BUILD)/criterion-v$(CRITERION_VERSION)/lib/libcriterion.* $(LIBDIR)/
	test -f $(BUILD)/shunit2.tgz || curl -sL https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/shunit2/shunit2-$(SHUNIT_VERSION).tgz -o $(BUILD)/shunit2.tgz
	cd $(BUILD); tar xf shunit2.tgz; cd ../
	test -d /usr/include/shunit2 || mv $(BUILD)/shunit2-$(SHUNIT_VERSION)/ /usr/include/shunit2

debug:
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Testing$(RESET)"
	$(CC) -g -I/usr/local/curl/include \
	  test/debug.c stns.c stns_group.c toml.c parson.c stns_shadow.c stns_passwd.c \
		-lcurl -lpthread -o $(BUILD)/debug && \
		$(BUILD)/debug && valgrind --leak-check=full tmp/libs/debug

testdev: ## Test without dependencies installation
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Testing$(RESET)"
	$(CC) -g3 -fsanitize=address -O0 -fno-omit-frame-pointer -I/usr/local/curl/include \
	  stns.c stns_group.c toml.c parson.c stns_shadow.c stns_passwd.c stns_test.c stns_group_test.c stns_shadow_test.c stns_passwd_test.c \
		/usr/local/curl/lib/libcurl.a \
		-lcriterion \
		-lpthread \
		-lssl \
		-lcrypto \
		-lz \
		-ldl \
		-lrt \
		-o $(BUILD)/test
		$(BUILD)/test --verbose
build: nss_build key_wrapper_build
nss_build: build_dir ## Build nss_stns
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Building nss_stns$(RESET)"
	$(CC) $(CFLAGS) -c parson.c -o $(BUILD)/parson.o
	$(CC) $(CFLAGS) -c toml.c -o $(BUILD)/toml.o
	$(CC) $(CFLAGS) -c stns_passwd.c -o $(BUILD)/stns_passwd.o
	$(CC) $(CFLAGS) -c stns_group.c -o $(BUILD)/stns_group.o
	$(CC) $(CFLAGS) -c stns_shadow.c -o $(BUILD)/stns_shadow.o
	$(CC) $(CFLAGS) -c stns.c -o $(BUILD)/stns.o
	$(CC) -shared $(LD_SONAME) -o $(BUILD)/$(LIBRARY) \
		$(BUILD)/stns.o \
		$(BUILD)/stns_passwd.o \
		$(BUILD)/parson.o \
		$(BUILD)/toml.o \
		$(BUILD)/stns_group.o \
		$(BUILD)/stns_shadow.o \
		/usr/local/curl/lib/libcurl.a \
		-lpthread \
		-lssl \
		-lcrypto \
		-lz \
		-ldl \
		-lrt

key_wrapper_build: build_dir ## Build nss_stns
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Building nss_stns$(RESET)"
	$(CC) $(CFLAGS) -c toml.c -o $(BUILD)/toml.o
	$(CC) $(CFLAGS) -c parson.c -o $(BUILD)/parson.o
	$(CC) $(CFLAGS) -c stns_key_wrapper.c -o $(BUILD)/stns_key_wrapper.o
	$(CC) $(CFLAGS) -c stns.c -o $(BUILD)/stns.o
	$(CC) -o $(BUILD)/$(KEY_WRAPPER) \
		$(BUILD)/stns.o \
		$(BUILD)/stns_key_wrapper.o \
		$(BUILD)/parson.o \
		$(BUILD)/toml.o \
		/usr/local/curl/lib/libcurl.a \
		-lpthread \
		-lssl \
		-lcrypto \
		-lz \
		-ldl \
		-lrt

integration: curl build install depsdev ## Run integration test
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Integration Testing$(RESET)"
	mkdir -p /etc/stns/client
	mkdir -p /etc/stns/server
	cp test/integration_client.conf /etc/stns/client/stns.conf
	cp test/integration_server.conf /etc/stns/server/stns.conf && service stns restart
	bash -l -c "while ! nc -vz -w 1 127.0.0.1 1104 > /dev/null 2>&1; do sleep 1; echo 'sleeping'; done"
	test -d /usr/lib/x86_64-linux-gnu && ln -sf /usr/lib/libnss_stns.so.2.0 /usr/lib/x86_64-linux-gnu/libnss_stns.so.2.0 || true
	sed -i -e 's/^passwd:.*/passwd: files stns/g' /etc/nsswitch.conf
	sed -i -e 's/^shadow:.*/shadow: files stns/g' /etc/nsswitch.conf
	sed -i -e 's/^group:.*/group: files stns/g' /etc/nsswitch.conf
	grep test /etc/sudoers || echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
	test/integration_test.sh

install: install_lib install_key_wrapper ## Install stns

install_lib: ## Install only shared objects
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Installing as Libraries$(RESET)"
	[ -d $(LIBDIR) ] || install -d $(LIBDIR)
	install $(BUILD)/$(LIBRARY) $(LIBDIR)
	cd $(LIBDIR); for link in $(LINKS); do ln -sf $(LIBRARY) $$link ; done;

install_key_wrapper: ## Install only key wrapper
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Installing as Key Wrapper$(RESET)"
	[ -d $(BINDIR) ] || install -d $(BINDIR)
	[ -d $(BINSYMDIR) ] || install -d $(BINSYMDIR)
	install $(BUILD)/$(KEY_WRAPPER) $(BINDIR)
	ln -sf /usr/lib/stns/$(KEY_WRAPPER) $(BINSYMDIR)/

source_for_rpm: ## Create source for RPM
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Distributing$(RESET)"
	rm -rf tmp.$(DIST) libnss-stns-v2-$(VERSION).tar.gz
	mkdir -p tmp.$(DIST)/libnss-stns-v2-$(VERSION)
	cp -r $(SOURCES) tmp.$(DIST)/libnss-stns-v2-$(VERSION)
	cd tmp.$(DIST) && \
		tar cf libnss-stns-v2-$(VERSION).tar libnss-stns-v2-$(VERSION) && \
		gzip -9 libnss-stns-v2-$(VERSION).tar
	cp tmp.$(DIST)/libnss-stns-v2-$(VERSION).tar.gz ./builds
	rm -rf tmp.$(DIST)

rpm: source_for_rpm curl ## Packaging for RPM
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Packaging for RPM$(RESET)"
	cp builds/libnss-stns-v2-$(VERSION).tar.gz /root/rpmbuild/SOURCES
	spectool -g -R rpm/stns.spec
	rpmbuild -ba rpm/stns.spec
	mv /root/rpmbuild/RPMS/*/*.rpm /stns/builds

source_for_deb: ## Create source for DEB
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Distributing$(RESET)"
	rm -rf tmp.$(DIST) libnss-stns-v2_$(VERSION).orig.tar.xz
	mkdir -p tmp.$(DIST)/libnss-stns-v2-$(VERSION)
	cp -r $(SOURCES) tmp.$(DIST)/libnss-stns-v2-$(VERSION)
	cd tmp.$(DIST) && \
		tar cf libnss-stns-v2_$(VERSION).tar libnss-stns-v2-$(VERSION) && \
		xz -v libnss-stns-v2_$(VERSION).tar
	mv tmp.$(DIST)/libnss-stns-v2_$(VERSION).tar.xz tmp.$(DIST)/libnss-stns-v2_$(VERSION).orig.tar.xz

deb: source_for_deb curl ## Packaging for DEB
	@echo "$(INFO_COLOR)==> $(RESET)$(BOLD)Packaging for DEB$(RESET)"
	cd tmp.$(DIST) && \
		tar xf libnss-stns-v2_$(VERSION).orig.tar.xz && \
		cd libnss-stns-v2-$(VERSION) && \
		dh_make --single --createorig -y && \
		rm -rf debian/*.ex debian/*.EX debian/README.Debian && \
		cp -v /stns/debian/* debian/ && \
		sed -i -e 's/xenial/$(DIST)/g' debian/changelog && \
		debuild -uc -us
	cd tmp.$(DIST) && \
		find . -name "*.deb" | sed -e 's/\(\(.*libnss-stns-v2.*\).deb\)/mv \1 \2.$(DIST).deb/g' | sh && \
		cp *.deb /stns/builds
	rm -rf tmp.$(DIST)
pkg: ## Create some distribution packages
	rm -rf builds && mkdir builds
	docker-compose run --rm -v `pwd`:/stns nss_centos6
	docker-compose run --rm -v `pwd`:/stns nss_centos7
	docker-compose run --rm -v `pwd`:/stns nss_ubuntu16
	docker-compose run --rm -v `pwd`:/stns nss_debian8
	docker-compose run --rm -v `pwd`:/stns nss_debian9

changelog:
	git-chglog -o CHANGELOG.md

docker:
	docker rm -f libnss-stns | true
	docker build -f dockerfiles/Dockerfile -t libnss_develop .
	docker run --privileged -d --name libnss-stns -v "`pwd`":/stns -it libnss_develop /sbin/init
	docker exec -it libnss-stns /bin/bash

github_release: ## Create some distribution packages
	ghr -u STNS --replace v$(VERSION) builds/

.PHONY: depsdev test testdev build
