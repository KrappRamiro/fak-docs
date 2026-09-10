FROM squidfunk/mkdocs-material:9

# Dependencias que usan los plugins "social" y "optimize"
# ver https://squidfunk.github.io/mkdocs-material/plugins/requirements/image-processing/
RUN apk add --no-cache \
    gcc \
    musl-dev \
    python3-dev \
    cairo \
    cairo-dev \
    freetype-dev \
    libffi-dev \
    jpeg-dev \
    libpng-dev \
    zlib-dev \
    pngquant

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /docs
