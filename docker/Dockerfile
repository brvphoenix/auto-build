ARG ARCH=x86-64
ARG BRANCH=snapshot
FROM openwrtorg/rootfs:$ARCH-$BRANCH

ADD entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
