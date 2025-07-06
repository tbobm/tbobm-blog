FROM ghcr.io/gohugoio/hugo:v0.145.0

USER root
COPY . /project
CMD ["server", "--bind", "0.0.0.0"]
ENTRYPOINT ["hugo"]
