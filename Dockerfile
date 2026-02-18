ARG ALPINE_VERSION=latest

FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache strongswan

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/docker-entrypoint.sh" ]

CMD [ "start", "--nofork" ]
