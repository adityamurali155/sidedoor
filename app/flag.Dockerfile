FROM alpine:latest
CMD ["sh", "-c", "mkdir -p /root/flag && echo $FLAG > /root/flag/flag.txt && sleep infinity"]