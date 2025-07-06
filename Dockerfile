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
    nlohmann-json3-dev \
    git \
    psmisc \
    wget \
    unzip \
    rtl-sdr \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Copy source code from the repository (already available in build context)
COPY . /app/PhantomSDR-Plus
WORKDIR /app/PhantomSDR-Plus

# Make scripts executable
RUN chmod +x *.sh

# Build PhantomSDR-Plus and manually handle all libraries
RUN meson setup builddir --optimization=3 && \
    meson compile -C builddir

# Create library directory and copy all built shared libraries
RUN mkdir -p /usr/local/lib/phantomsdr && \
    find builddir -name "*.so*" -type f -exec cp {} /usr/local/lib/phantomsdr/ \; && \
    find builddir -name "*.so.*" -type f -exec cp {} /usr/local/lib/phantomsdr/ \; && \
    cp builddir/spectrumserver /usr/local/bin/ && \
    chmod +x /usr/local/bin/spectrumserver

# Also copy to standard library location as backup
RUN find builddir -name "*.so*" -type f -exec cp {} /usr/local/lib/ \;

# Update library cache with both locations
RUN echo "/usr/local/lib/phantomsdr" > /etc/ld.so.conf.d/phantomsdr.conf && \
    ldconfig

# Create wrapper script with explicit library path
RUN echo '#!/bin/bash\n\
export LD_LIBRARY_PATH="/usr/local/lib/phantomsdr:/usr/local/lib:${LD_LIBRARY_PATH}"\n\
echo "Starting PhantomSDR-Plus with library path: $LD_LIBRARY_PATH"\n\
exec /usr/local/bin/spectrumserver "$@"' > /app/spectrumserver-wrapper && \
    chmod +x /app/spectrumserver-wrapper

# Create necessary directories
RUN mkdir -p /app/logs

# Copy configuration template if it exists
RUN cp config.toml /app/config.toml.template 2>/dev/null || \
    echo '# PhantomSDR-Plus Configuration - Edit as needed\n\
[server]\n\
port = 9002\n\
max_users = 100\n\
htmlroot = "/app/html"\n\
\n\
[sdr]\n\
device = "rtlsdr"\n\
frequency = 145700000\n\
sample_rate = 3200000\n\
gain = 40\n\
\n\
[gpu]\n\
enabled = false\n\
device = "auto"\n\
\n\
[logging]\n\
level = "info"\n\
file = "/app/logs/phantomsdr.log"' > /app/config.toml.template

# Create site information template
RUN echo '{\n\
  "siteName": "PhantomSDR-Plus Station",\n\
  "siteDescription": "High-performance WebSDR",\n\
  "siteLocation": "Denmark",\n\
  "siteOperator": "Joachim Thirsbro",\n\
  "siteEmail": "joachim@thirsbro.dk",\n\
  "siteSDRBaseFrequency": 0,\n\
  "siteSDRBandwidth": 30000000,\n\
  "siteSDRRegion": 2\n\
}' > /app/site_information.json.template

# Define volume for logs
VOLUME /app/logs

# Expose port (ændre til 8080 hvis det er standard)
EXPOSE 9002

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
