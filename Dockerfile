# === PhantomSDR-Plus Docker Container ===
FROM ubuntu:22.04

LABEL maintainer="Joachim Thirsbro <joachim@thirsbro.dk>"

# Set environment variables to avoid warnings
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PATH="/usr/local/bin:${PATH}"

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    meson \
    libfftw3-dev \
    libwebsocketpp-dev \
    libflac++-dev \
    zlib1g-dev \
    libzstd-dev \
    libboost-all-dev \
    libopus-dev \
    libliquid-dev \
    libusb-1.0-0-dev \
    libcurl4-openssl-dev \
    git \
    psmisc \
    wget \
    unzip \
    rtl-sdr \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Clone PhantomSDR-Plus from your repository
RUN git clone --recursive https://github.com/joachimth/PhantomSDR-Plus_docker.git || \
    (git config --global http.sslVerify false && \
     git clone --recursive https://github.com/joachimth/PhantomSDR-Plus_docker.git) && \
    cd PhantomSDR-Plus_docker && \
    chmod +x *.sh

# Build PhantomSDR-Plus manually to avoid install script issues
RUN cd PhantomSDR-Plus_docker && \
    meson setup builddir --optimization=3 && \
    meson compile -C builddir

# Create necessary directories
RUN mkdir -p /app/logs

# Copy built binary to expected location
RUN cp PhantomSDR-Plus_docker/builddir/spectrumserver /usr/local/bin/ || \
    cp PhantomSDR-Plus_docker/build/spectrumserver /usr/local/bin/

# Copy configuration template if it exists
RUN cp PhantomSDR-Plus_docker/config.toml /app/config.toml.template 2>/dev/null || \
    echo "# PhantomSDR Config" > /app/config.toml.template

# Define volume for logs
VOLUME /app/logs

# Expose port (ændre til 8080 hvis det er standard)
EXPOSE 8080

# Create a simple start script
RUN echo '#!/bin/bash\n\
cd /app\n\
if [ ! -f config.toml ]; then\n\
    cp config.toml.template config.toml\n\
fi\n\
echo "Starting PhantomSDR-Plus..."\n\
exec /usr/local/bin/spectrumserver --config config.toml' > /app/start.sh && \
    chmod +x /app/start.sh

# Define default command
CMD ["/app/start.sh"]

# Metadata labels
LABEL \
    org.label-schema.name="phantomsdr-plus" \
    org.label-schema.description="Docker container for PhantomSDR-Plus" \
    org.label-schema.version="latest" \
    org.label-schema.vcs-url="https://github.com/joachimth/PhantomSDR-Plus" \
    org.label-schema.schema-version="1.0"
