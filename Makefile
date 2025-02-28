# Makefile for Windows

#####################################################################################################

ROOT_DIR:=$(shell cd)

# If no custom gaffer version specified, retrieve the latest one
GAFFER_VERSION:=1.3.1.0
DOCKER_IMAGE:=gafferhq/gaffer

$(info =============================================================================================)
$(info Using docker image from GafferHQ: $(DOCKER_IMAGE))
$(info GAFFER_VERSION=$(GAFFER_VERSION))
$(info =============================================================================================)

GAFFER_CORTEX_SRC:=$(wildcard src/GafferCortex/*.cpp)
GAFFER_CORTEX_OBJ=$(GAFFER_CORTEX_SRC:.cpp=.o)
GAFFER_CORTEX_SRC+=$(wildcard include/GafferCortex/*.h)
GAFFER_CORTEX_MODULE_SRC:=$(wildcard src/GafferCortexModule/*.cpp)

.PHONY: help update install build_all run test list clean nuke

help:
	@echo ""
	@echo "make help                                         - display this help screen."
	@echo "make update                                       - pull GafferCortex source from the main branch of GafferHQ."
	@echo "make install [GAFFER_VERSION=<gaffer version>]   - build GafferCortex using the same docker container as the official Gaffer binaries."
	@echo "make run [GAFFER_VERSION=<gaffer version>]       - run gaffer GAFFER_VERSION from the downloaded binary, with GafferCortex configured as extension"
	@echo "make test [GAFFER_VERSION=<gaffer version>]      - run GafferCortex unit test"
	@echo "make list                                         - show all available versions from the GitHub release page"
	@echo "make clean                                        - cleanup install folder"
	@echo "make nuke                                         - cleanup everything"
	@echo ""
	@echo "Make parameters:"
	@echo ""
	@echo "    GAFFER_VERSION: specifies the Gaffer version to build for. If not set, this makefile will retrieve the latest from Github releases page."
	@echo ""

install: docker_build 
build_all: install/$(GAFFER_VERSION)/lib/libGafferCortex.so install/$(GAFFER_VERSION)/python/GafferCortex/_GafferCortex.so test
.PHONY: build_all

# force the use of one shell for all shell lines, instead of one shell per line.
.ONESHELL:

# run this makefile in the same docker container used to build Gaffer on github
# but as the current user
# UID:=$(shell id -u ${USER})
# GID:=$(shell id -g ${USER})
# GROUP:=$(shell id -g -n ${USER})
CORES:=$(shell grep MHz /proc/cpuinfo  | wc -l)

docker_build:
	docker build -t local/gaffercortex .
	docker run \
		--rm \
		--privileged=true \
		-v "$(ROOT_DIR)":/work \
		local/gaffercortex \
		/bin/bash -c "\
			cd /work && \
			make install GAFFER_VERSION=$(GAFFER_VERSION) \
		"

# list the latest releases from the github release url
list:
	@curl https://github.com/GafferHQ/gaffer/releases 2>nul | findstr /C:"releases.tag" | awk -F'tag/' "{print $$2}" | awk -F'\"' "{print $$1}" | sort -V

# just update the current GafferCortex source from the main branch on GafferHQ git
# only used while GafferCortex still exists in the main branch
update:
	powershell -Command "\
		git clone --depth=1 https://github.com/GafferHQ/gaffer.git temp && \
		rm -rf GafferCortex && \
		mv temp/GafferCortex . && \
		rm -rf temp \
	"

# download GAFFER_VERSION binary from GafferHQ
build/dependencies/$(GAFFER_VERSION)/.done:
	mkdir -p build/dependencies/$(GAFFER_VERSION)/
	cd build/dependencies/$(GAFFER_VERSION)/
	curl -Lo gaffer-$(GAFFER_VERSION)-linux.tar.gz https://github.com/GafferHQ/gaffer/releases/download/$(GAFFER_VERSION)/gaffer-$(GAFFER_VERSION)-linux.tar.gz
	tar xzf gaffer-$(GAFFER_VERSION)-linux.tar.gz --strip-components=1
	echo | set /p = > ./.done

# retrieve the C++ STD used by the GAFFER_VERSION, directly from it's SConstruct on github
CXXSTD=$(shell curl -L 'https://raw.githubusercontent.com/GafferHQ/gaffer/$(GAFFER_VERSION)/SConstruct' 2>/dev/null | grep CXXSTD -A 2 | grep minimum -A1 | tail -1 | awk -F'"' '{print $$2}')

# build GafferCortex using the downloaded GafferHQ binary
install/$(GAFFER_VERSION)/lib/libGafferCortex.so: build/dependencies/$(GAFFER_VERSION)/.done $(GAFFER_CORTEX_SRC)
	mkdir -p install/$(GAFFER_VERSION)/lib
	g++ --shared -fPIC -std=$(CXXSTD) \
		-I./include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/Imath \
		$(GAFFER_CORTEX_SRC) -o $@ \
		-L./build/dependencies/$(GAFFER_VERSION)/lib/ \
		-Wl,-rpath=./build/dependencies/$(GAFFER_VERSION)/lib/ \
		-lGafferBindings \
		-lGafferCortex \
		-lGafferDispatch \
		&& \
	mkdir -p install/$(GAFFER_VERSION)/include/ && \
	cp -rfuv include/* install/$(GAFFER_VERSION)/include/

# build GafferCortex python module using the downloaded GafferHQ binary
install/$(GAFFER_VERSION)/python/GafferCortex/_GafferCortex.so: install/$(GAFFER_VERSION)/lib/libGafferCortex.so $(GAFFER_CORTEX_MODULE_SRC)
	mkdir -p install/$(GAFFER_VERSION)/python/GafferCortex
	g++ --shared -fPIC -std=$(CXXSTD) \
		-I./include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/ \
		-I./build/dependencies/$(GAFFER_VERSION)/include/Imath \
		-I./build/dependencies/$(GAFFER_VERSION)/include/python3.7m \
		$(GAFFER_CORTEX_MODULE_SRC) -o $@ \
		-L./build/dependencies/$(GAFFER_VERSION)/lib/ \
		-L./install/$(GAFFER_VERSION)/lib/ \
		-Wl,-rpath=./build/dependencies/$(GAFFER_VERSION)/lib/ \
		-lGafferBindings \
		-lGafferCortex \
		-lGafferDispatch \
		&& \
	cp -rfuv python/* install/$(GAFFER_VERSION)/python/
# run the downloaded Gaffer with the just built GafferCortex setup as extension
run:
    GAFFER_EXTENSION_PATHS="/d/gaffercortex/install/$(GAFFER_VERSION)" \
    PATH="/d/gaffer/build/dependencies/$(GAFFER_VERSION)/bin:$${PATH}" \
    gaffer

# run the GafferCortex unit tests
test: install/$(GAFFER_VERSION)/python/GafferCortex/_GafferCortex.so
	mkdir -p /tmp/home
	export HOME=/tmp/home
	export GAFFER_EXTENSION_PATHS=$(ROOT_DIR)/install/$(GAFFER_VERSION)
	export PATH=$(ROOT_DIR)/build/dependencies/$(GAFFER_VERSION)/bin/:$(PATH)
	Xvfb :99 -screen 0 1280x1024x24 & export DISPLAY=:99
	cp -rfuv ./python/GafferCortexTest ./build/dependencies/$(GAFFER_VERSION)/python/ && \
	gaffer test GafferCortexTest && \
	gaffer test GafferCortexUITest && \
	rm -rf /tmp/home
	rm -rf ./build/dependencies/$(GAFFER_VERSION)/python/GafferCortexTest
	pkill -fc -9 Xvfb..99

clean:
	rm -rf install

nuke: clean
	rm -rf build