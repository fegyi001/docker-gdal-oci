# docker-gdal-oci

> Docker image for GDAL with OCI (Oracle) support

## Use the prebuilt image

```bash
# Download
docker pull fegyi001/gdal-oci

# Test
docker run fegyi001/gdal-oci ogr2ogr --formats
docker run fegyi001/gdal-oci gdalinfo --formats
```

## Build your own version

```bash
docker build -t my-own-gdal-oci-image .
```
