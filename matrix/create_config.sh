docker run -it --rm \
    -v "$(pwd)/data:/data" \
    -e SYNAPSE_SERVER_NAME=matrix.domain.ru \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
