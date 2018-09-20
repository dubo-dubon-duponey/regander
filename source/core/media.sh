#!/usr/bin/env bash
##########################################################################
# Media types
# ------
# All media types
##########################################################################

# v1
readonly MIME_V1_MANIFEST="application/vnd.docker.distribution.manifest.v1+json"
readonly MIME_V1_MANIFEST_JSON="application/json"
readonly MIME_V1_MANIFEST_SIGNED="application/vnd.docker.distribution.manifest.v1+prettyjws"

# v2
readonly MIME_V2_MANIFEST="application/vnd.docker.distribution.manifest.v2+json"
readonly MIME_V2_LIST="application/vnd.docker.distribution.manifest.list.v2+json"

# Subtypes
readonly MIME_V2_CONFIG="application/vnd.docker.container.image.v1+json"
readonly MIME_V2_LAYER="application/vnd.docker.image.rootfs.diff.tar.gzip"
readonly MIME_V2_FOREIGN="application/vnd.docker.image.rootfs.foreign.diff.tar.gzip"

# Alternative config objects
readonly MIME_V2_CONFIG_PLUGIN="application/vnd.docker.plugin.v1+json"
readonly MIME_V2_CONFIG_X_APP="x-application/vnd.docker.app-definition.v1+json"
readonly MIME_V2_CONFIG_X_APP_TPL="x-application/vnd.docker.app-template.v1+json"

# OCI
readonly MIME_OCI_MANIFEST="application/vnd.oci.image.manifest.v1+json"
readonly MIME_OCI_LIST="application/vnd.oci.image.index.v1+json"

# Subtypes
readonly MIME_OCI_CONFIG="application/vnd.oci.image.config.v1+json"
readonly MIME_OCI_LAYER="application/vnd.oci.image.layer.v1.tar"
readonly MIME_OCI_GZLAYER="application/vnd.oci.image.layer.v1.tar+gzip"
readonly MIME_OCI_FOREIGN="application/vnd.oci.image.layer.nondistributable.v1.tar"
readonly MIME_OCI_GZFOREIGN="application/vnd.oci.image.layer.nondistributable.v1.tar+gzip"
