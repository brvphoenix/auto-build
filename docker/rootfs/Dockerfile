ARG ARCH=x86_64
ARG BRANCH=snapshot
FROM openwrtorg/rootfs:$ARCH-$BRANCH

EXPOSE 28181

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
