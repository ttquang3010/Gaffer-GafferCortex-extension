# Gaffer-GafferCortex-extension
Since GafferCortex is being deprecated in GafferHQ, 
this repo aims to maintain it as an extension for Gaffer.

To build you just need to have `curl`, `make` and `docker` installed. 
Just type `make` and a little help will show up. 

The Makefile retrives the Gaffer binary directly from GafferHQ, and builds
GafferCortex using the same docker container used by gaffers github action. 
This guarantees the .so files will be compatible.

It's also possible to build it for any release of Gaffer by just specifying the 
GAFFER_VERSION parameter to make, like `make GAFFER_VERSION=1.3.0.0 install`. 
When GAFFER_VERSION is not set manually, make will retrieve the latest version 
from the github release url. 

