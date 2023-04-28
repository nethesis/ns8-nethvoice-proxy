#!/bin/bash

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="ghcr.io/nethesis"

# Configure the image name
reponame="nethvoice-proxy-postgres"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/postgres
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-kamailio"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/kamailio
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-redis"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/redis
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-rtpengine"
buildah bud -t "${repobase}/${reponame}" modules/rtpengine
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Setup CI when pushing to Github.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "::set-output name=images::%s\n" "${images[*]}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
