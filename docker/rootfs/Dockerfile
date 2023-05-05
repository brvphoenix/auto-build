ARG TAG=x86-64
FROM ghcr.io/openwrt/rootfs:$TAG

EXPOSE 8080

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
