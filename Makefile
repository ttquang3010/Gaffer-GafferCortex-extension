

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# retrieve the current container image name used by GafferHQ github action to build Gaffer releases
DOCKER_IMAGE:=$(shell echo $$(curl -L 'https://raw.githubusercontent.com/GafferHQ/gaffer/main/.github/workflows/main.yml' 2>/dev/null | egrep 'containerImage.*gafferhq' | head -1 | sed 's/containerImage.//'))

# if no custom gaffer version specified, retrieve the latest one
ifeq "$(GAFFER_VERSION)" ""
GAFFER_VERSION:=$(shell curl https://github.com/GafferHQ/gaffer/releases 2>/dev/null | grep releases.tag | awk -F'tag/' '{print $$2}' | awk -F'"' '{print $$1}' | sort -V | tail -1)
endif

$(info Using docker image from GafferHQ: $(DOCKER_IMAGE))
$(info GAFFER_VERSION=$(GAFFER_VERSION))

GAFFER_CORTEX_SRC:=$(wildcard src/GafferCortex/*.cpp)
GAFFER_CORTEX_OBJ=$(GAFFER_CORTEX_SRC:.cpp=.o)
GAFFER_CORTEX_SRC+=$(wildcard include/GafferCortex/*.h)
GAFFER_CORTEX_MODULE_SRC:=$(wildcard src/GafferCortexModule/*.cpp)

help:
	@echo ""
	@echo "make help                                         - display this help screen."
	@echo "make update                                       - pull GafferCortex source from the main branch of GafferHQ."
	@echo "make install [GAFFER_VERSION=<gaffer version]     - build GafferCortex using the same docker container as the official Gaffer binaries."
	@echo "make run [GAFFER_VERSION=<gaffer version]         - run gaffer GAFFER_VERSION from the downloaded binary, with GafferCortex configured as extension"
	@echo "make test [GAFFER_VERSION=<gaffer version]        - run GafferCortex unit test"
	@echo "make clean								         - cleanup install folder"
	@echo "make nuke								         - cleanup everything"
	@echo ""
	@echo "    GAFFER_VERSION specifies the Gaffer version to build for. If not set, this makefile will retrieve the latest from Github releases page."
	@echo ""


install: docker_build
build_all: install/$(GAFFER_VERSION)/lib/libGafferCortex.so install/$(GAFFER_VERSION)/python/GafferCortex/_GafferCortex.so

# force the use of one shell for all shell lines, instead of one shell per line.
.ONESHELL:

# run this makefile in the same docker container used to build Gaffer on github
# but as the current user
UID:=$(shell id -u ${USER})
GID:=$(shell id -g ${USER})
GROUP:=$(shell id -g -n ${USER})
CORES:=$(shell grep MHz /proc/cpuinfo  | wc -l)
docker_build:
	docker pull $(DOCKER_IMAGE)
	docker run \
		--rm \
		--privileged=true \
		-v $(ROOT_DIR)/:$(ROOT_DIR)/ \
		$(DOCKER_IMAGE) \
		/bin/bash -c "\
			groupadd -g $(GID) $(GROUP)
			useradd -l -u $(UID) -g $(GID) $(USER) && \
			cd $(ROOT_DIR)/ && \
			runuser $(USER) -c 'make build_all -j $(CORES)' \
		"

# just update the current GafferCortex source from the main branch on GafferHQ git
# only used while GafferCortex still exists in the main branch
update:
	cd $(ROOT_DIR)
	rm -rf /tmp/GafferHQ-git/
	git clone --depth=1 https://github.com/GafferHQ/gaffer.git /tmp/GafferHQ-git/
	ls -1d  /tmp/GafferHQ-git/*/GafferCortex* | while read from ; do \
		to=$$(echo $$from | sed 's/.tmp.GafferHQ-git/./') ; \
		mkdir -p $$to ; \
		rsync -avpP --delete --delete-excluded $$from/ $$to/ ; \
	done
	rm -rf /tmp/GafferHQ-git/

# download GAFFER_VERSION binary from GafferHQ
prepare:
	if [ ! -e build/dependencies/$(GAFFER_VERSION)/bin/gaffer ] ; then
		mkdir -p build/dependencies/$(GAFFER_VERSION)/
		cd build/dependencies/$(GAFFER_VERSION)/
		curl -L https://github.com/GafferHQ/gaffer/releases/download/$(GAFFER_VERSION)/gaffer-$(GAFFER_VERSION)-linux.tar.gz | tar xzf - --strip-components=1 
	fi

# retrieve the C++ STD used by the GAFFER_VERSION, directly from it's SConstruct on github
CXXSTD=$(shell curl -L 'https://raw.githubusercontent.com/GafferHQ/gaffer/1.3.1.0/SConstruct' 2>/dev/null | grep CXXSTD -A 2 | grep minimum -A1 | tail -1 | awk -F'"' '{print $$2}')

# build GafferCortex using the downloaded GafferHQ binary
install/$(GAFFER_VERSION)/lib/libGafferCortex.so: prepare $(GAFFER_CORTEX_SRC)
	mkdir -p install/$(GAFFER_VERSION)/lib
	g++ --shared -fPIC -std=$(CXXSTD) \
		-I./include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/Imath \
		-L./build/dependencies/$(GAFFER_VERSION)/lib/ \
		$(GAFFER_CORTEX_SRC) -o $@ && \
	mkdir -p install/$(GAFFER_VERSION)/include/ && \
	cp -rfuv include/* install/$(GAFFER_VERSION)/include/

install/$(GAFFER_VERSION)/python/GafferCortex/_GafferCortex.so: install/$(GAFFER_VERSION)/lib/libGafferCortex.so $(GAFFER_CORTEX_MODULE_SRC)
	mkdir -p install/$(GAFFER_VERSION)/python/GafferCortex
	g++ --shared -fPIC -std=$(CXXSTD) \
		-I./include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/Imath \
		-I./build/dependencies/$(GAFFER_VERSION)/include/python3.7m \
		-L./build/dependencies/$(GAFFER_VERSION)/lib/ \
		-L./install/$(GAFFER_VERSION)/lib/ \
		-lGafferBindings \
		-lGafferCortex \
		-lGafferDispatch \
		$(GAFFER_CORTEX_MODULE_SRC) -o $@ && \
	cp -rfuv python/* install/$(GAFFER_VERSION)/python/

run: 
	mkdir -p /tmp/home
	export HOME=/tmp/home
	export GAFFER_EXTENSION_PATHS=$(ROOT_DIR)/install/$(GAFFER_VERSION)
	export PATH=$(ROOT_DIR)/build/dependencies/$(GAFFER_VERSION)/bin/:$(PATH)
	gaffer
	rm -rf /tmp/home

test: 
	mkdir -p /tmp/home
	export HOME=/tmp/home
	export GAFFER_EXTENSION_PATHS=$(ROOT_DIR)/install/$(GAFFER_VERSION)
	export PATH=$(ROOT_DIR)/build/dependencies/$(GAFFER_VERSION)/bin/:$(PATH)
	cp -rfuv ./python/GafferCortexTest ./build/dependencies/$(GAFFER_VERSION)/python/ && \
	gaffer test GafferCortexTest && \
	gaffer test GafferCortexUITest && \
	rm -rf /tmp/home


clean:
	rm -rf install

nuke: clean
	rm -rf build
