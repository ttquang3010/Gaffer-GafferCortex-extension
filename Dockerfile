FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /work

# Copy GafferCortex source code into the image
COPY . /work

# Build GafferCortex
RUN make install GAFFER_VERSION=1.3.1.0

CMD ["bash"]