FROM scratch
EXPOSE 80 443 22
WORKDIR /
COPY ./rootfs/ .
USER root
ADD ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
