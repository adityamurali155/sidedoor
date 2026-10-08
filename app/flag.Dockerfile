FROM alpine:latest
RUN apk add --no-cache util-linux
CMD ["sh", "-c", "mkdir -p /root/flag && echo $FLAG > /root/flag/flag.txt && sleep infinity"]