#!/usr/bin/env python3

import sys, os, argparse
from glob import glob


CD=os.path.dirname( os.path.abspath( __file__ ) )

parser = argparse.ArgumentParser(description='install gaffer and gaffer_cortex in a pipeVFX libs folder')
parser.add_argument('-n', help='dry run. default: %(default)s', action='store_true', default=False)
parser.add_argument('-p', help='specify the install prefix for the installation. If not specified, will use pipeVFX to find out.',  nargs='+')
parser.add_argument('-b', help='run make on the previous folder to build the gaffer_cortex for the latest gaffer', action='store_true', default=False)
parser.add_argument('-m', help='compare the gaffer versions already installed in INSTALL_PREFIX}/gaffer/ and build and install only the missing ones. (used to run weekly on cron job to automatically install new versions)', action='store_true', default=False)
parser.add_argument('-v', help='specify the versions to install.',  nargs='+')
args = parser.parse_args()

def system(cmd):
    ret = 0
    print(cmd)
    if not args.n:
        ret = os.system(cmd)
        if ret != 0:
            print(f"return: {ret}")
            sys.exit(ret)
    return ret
    

if args.p:
    _INSTALL_PREFIX=args.p
else:
    import pipe    
    _INSTALL_PREFIX=[pipe.roots.libs()]



gaffer_latest = [ x.strip() for x in os.popen( f'make -C {CD}/../ list' ).readlines() if x[0].isdigit() ][-2:]
for INSTALL_PREFIX in _INSTALL_PREFIX:
    # detect if we have a new version of Gaffer that is not already installed
    if args.m:
        if '@' in INSTALL_PREFIX:
            gaffer_versions = gaffer_latest
            gaffer_missing = gaffer_latest
        else:
            gaffer_versions = [ os.path.basename(os.path.dirname(x)) for x in glob(f"{INSTALL_PREFIX}/gaffer/*/*") ]
            gaffer_versions = list(set(gaffer_versions))
            gaffer_missing = [ x for x in gaffer_latest if x not in gaffer_versions ]
    else:
        gaffer_missing = gaffer_latest[-1:]

    # force build the version we specify
    if args.v:
        gaffer_missing = args.v

    for GAFFER_VERSION in gaffer_missing:
        if args.b:
            system( f'make -C {CD}/../ install GAFFER_VERSION={GAFFER_VERSION}' )

        # install all gaffer found in the ../build/dependencies folder
        system( f'sudo mkdir -p {INSTALL_PREFIX}/gaffer' )
        system( f'sudo rsync -avpP --delete --delete-excluded {CD}/../build/dependencies/{GAFFER_VERSION}/ {INSTALL_PREFIX}/gaffer/{GAFFER_VERSION}/' )

        # install all gaffer_cortex found in the ../install folder
        system( f'sudo mkdir -p {INSTALL_PREFIX}/gaffer_cortex' )
        system( f'sudo rsync -avpP --delete --delete-excluded {CD}/../install/{GAFFER_VERSION}/ {INSTALL_PREFIX}/gaffer_cortex/{GAFFER_VERSION}/' )

