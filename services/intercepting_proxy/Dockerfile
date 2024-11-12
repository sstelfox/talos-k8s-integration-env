FROM alpine:latest

RUN apk add --no-cache tinyproxy openssl ca-certificates

# Create directories for certificates and logs
RUN mkdir -p /etc/tinyproxy/certs /var/log/tinyproxy && \
    chown -R tinyproxy:tinyproxy /var/log/tinyproxy

COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf

EXPOSE 8888
EXPOSE 8889

CMD ["tinyproxy", "-d", "-c", "/etc/tinyproxy/tinyproxy.conf"]
