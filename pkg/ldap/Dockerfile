FROM alpine AS mirror

RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/
RUN apk add --no-cache --initdb -p /out \
    alpine-baselayout \
    busybox \
    bash \
    ca-certificates \
    musl \
    tini \
    openldap \
    openldap-back-mdb \
    openldap-clients \
    && true
# we really do not want a rogue inittab here
RUN rm -rf /out/etc/inittab
COPY scripts/* /out/etc/openldap/
COPY slapd.sh /out/

FROM scratch
ENTRYPOINT ["/sbin/tini","-s","-v","--"]
WORKDIR /
COPY --from=mirror /out/ /
CMD ["/slapd.sh"]
