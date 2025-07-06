# === PhantomSDR-Plus Docker Container ===
FROM ubuntu:22.04

LABEL maintainer="Joachim Thirsbro <joachim@thirsbro.dk>"

# Set environment variables to avoid warnings
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PATH="/usr/local/bin:${PATH}"

# Set working directory
WORKDIR /app

# Install dependencies including Node.js for frontend
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
    nodejs \
    npm \
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

# Initialize git submodules to get the frontend
RUN git submodule update --init --recursive || \
    (echo "Submodule init failed, cloning frontend manually..." && \
     git clone https://github.com/Steven9101/frontend.git frontend)

# Build PhantomSDR-Plus backend
RUN meson setup builddir --optimization=3 && \
    meson compile -C builddir

# Build frontend (now that submodule is initialized)
RUN if [ -d "frontend" ] && [ "$(ls -A frontend)" ]; then \
        cd frontend && \
        echo "Building frontend from Steven9101/frontend..." && \
        npm install && \
        (npm run build || npm run dev || echo "Frontend build completed with warnings"); \
    else \
        echo "Frontend directory is empty or missing!"; \
        exit 1; \
    fi

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

# Create HTML directory and copy frontend files
RUN mkdir -p /app/html && \
    if [ -d "frontend/dist" ]; then \
        echo "Copying frontend from frontend/dist..." && \
        cp -r frontend/dist/* /app/html/; \
    elif [ -d "frontend/build" ]; then \
        echo "Copying frontend from frontend/build..." && \
        cp -r frontend/build/* /app/html/; \
    elif [ -d "frontend/public" ]; then \
        echo "Copying frontend from frontend/public..." && \
        cp -r frontend/public/* /app/html/; \
    elif [ -d "frontend" ] && [ "$(ls -A frontend)" ]; then \
        echo "Copying frontend source files..." && \
        cp -r frontend/* /app/html/; \
    elif [ -d "html" ]; then \
        echo "Copying from html directory..." && \
        cp -r html/* /app/html/; \
    else \
        echo "No frontend files found! Creating minimal HTML interface..." && \
        echo '<!DOCTYPE html>\
<html><head><title>PhantomSDR-Plus</title></head>\
<body><h1>PhantomSDR-Plus Backend Running</h1>\
<p>Backend is running on port 9002</p>\
<p>Frontend submodule may need manual configuration.</p>\
<p>Check: <a href="https://github.com/Steven9101/frontend">Steven9101/frontend</a></p>\
</body></html>' > /app/html/index.html; \
    fi && \
    echo "Frontend files copied to /app/html/" && \
    ls -la /app/html/ | head -10

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
frequency = 145000000\n\
sample_rate = 2048000\n\
gain = 32\n\
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
  "siteSDRBaseFrequency": 145000000,\n\
  "siteSDRBandwidth": 8048000,\n\
  "siteSDRRegion": 2\n\
}' > /app/site_information.json.template

# Define volume for logs
VOLUME /app/logs

# Expose port 9002 (PhantomSDR-Plus default)
EXPOSE 9002

# Create a simple start script
RUN echo '#!/bin/bash\n\
cd /app\n\
\n\
# Create config from template if not exists\n\
if [ ! -f config.toml ]; then\n\
    cp config.toml.template config.toml\n\
fi\n\
\n\
# Create site info if not exists\n\
if [ ! -f /app/html/site_information.json ] && [ -f site_information.json.template ]; then\n\
    cp site_information.json.template /app/html/site_information.json\n\
fi\n\
\n\
# Set library path\n\
export LD_LIBRARY_PATH="/usr/local/lib/phantomsdr:/usr/local/lib:${LD_LIBRARY_PATH}"\n\
\n\
echo "Starting PhantomSDR-Plus..."\n\
echo "Web interface should be available at http://localhost:9002"\n\
echo "HTML root: /app/html"\n\
ls -la /app/html/ | head -10\n\
\n\
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
