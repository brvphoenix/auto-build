ARG ARCH=x86_64
ARG BRANCH=snapshot
FROM openwrtorg/rootfs:$ARCH-$BRANCH

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
