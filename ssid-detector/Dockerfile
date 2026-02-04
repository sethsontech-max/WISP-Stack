FROM alpine:latest

RUN apk add --no-cache bash curl jq

COPY ssid-change-detector.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/ssid-change-detector.sh

CMD ["/usr/local/bin/ssid-change-detector.sh"]