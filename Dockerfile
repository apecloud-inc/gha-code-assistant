FROM alpine:latest

RUN apk --no-cache add bash jq curl git github-cli

ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
