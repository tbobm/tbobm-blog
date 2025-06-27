+++
title = 'Multi-stage container images from dev to production'
date = 2025-06-17T05:22:00+02:00
ShowToc = true
tags = ['tech', 'containers', 'go']
+++

Multi-stage container images have been a good friend of mine for some time now.
They enable projects to have a smarter way of packaging by splitting the build
and the run of a given software.

Let's take a first, simple hello world program in Go as our example.

```Dockerfile
FROM golang:1.24 AS builder

COPY go.mod .

COPY . .

RUN go build -o /my-executable

CMD ["/my-executable"]
```

Upon building our image, we end up with an astonishing **888MB** image due to
all the dev dependencies, build dependencies and so on that are inclured in the
`golang:1.24` image. That's our reference.

Mult-stage containers, as stated in the docker documentation, allow to get rid of
dev / build dependencies in the resulting container images, which reduce
the overall size (and attack surface for security folks), thus reducing
the overhead of running those images for instance. [^1]

[^1]: quite easy to observe if we compare the pull time of a 15GB image to a 15MB one

In the last years, I've went up to introducing actual **testing** stage within the container
images but ended up in a more common place, only leveraging the leaner images aspect
of this feature. With tools like `uv` which introduce some fine-graine, cache enabled
and very profitable examples, this great pattern is getting some light again.

A simple example of multi-stage can be the following snippet to leverage [scratch images][docker-scratch]:

```Dockerfile
FROM golang:1.24 AS builder

COPY go.mod .

COPY . .

RUN go build -o /my-executable

FROM scratch AS release

COPY --from=builder /my-executable /my-executable

CMD ["/my-executable"]
```

Upon building this image, we get a slimmer image of only **2.21MB**. Hard to beat without fiddling
with the build system.

However, scratch images are rarely the most suited ones for production use.

A neat-looking project called [distroless images][gh-distroless] acts as a middle ground between
slim base images while also exposing mandatory libraries or tools to be a part of this image.

Let's tweak our example a bit:

```Dockerfile
FROM golang:1.24 AS builder

COPY go.mod .

COPY . .

RUN go build -o /my-executable

FROM gcr.io/distroless/static-debian12 AS release

COPY --from=builder /my-executable /my-executable

CMD ["/my-executable"]
```

Distroless images can be extended by building them manually
using bazel (see [rules\_distroless][gh-bazel-distroless]).

## Further in - Lambda support

_I love AWS Lambda, I love go. Now, I do Lambdas in go. Quick maths._

One thing I always expect from my lambdas is the ability to run them locally. My go-to
solution has always been the Lambda RIE (Runtime Interface Emulator) due to how simple
it was to integrate it in existing projects.

It provides a simple HTTP interface (which is basically how lambdas are run anyway) that
we can use locally to inject our shiny events. Combined with localstack, we end up with
a local-first development setup that can be leveraged to provide a smooth, cloud-looking experience.

A Lambda container image's Dockerfile would look like this:

```Dockerfile
FROM golang:1.24 AS build

WORKDIR /app

# Copy dependencies list
COPY go.mod go.sum ./

# Build with optional lambda.norpc tag
COPY . .
RUN go build -tags lambda.norpc -o my-lambda

# Copy artifacts to a clean image
FROM public.ecr.aws/lambda/provided:al2023 AS production

COPY --from=build /app/my-lambda ./my-lambda
ENTRYPOINT [ "./my-lambda" ]

FROM production AS dev

RUN mkdir -p /aws-lambda-rie && \
    curl -Lo /aws-lambda-rie/aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \
    chmod +x /aws-lambda-rie/aws-lambda-rie

ENTRYPOINT [ "/aws-lambda-rie/aws-lambda-rie", "./my-lambda" ]
```

This enables a local HTTP based interface in our container. Lovely.

We can now build our container image by relying on **target** flags:
```console
$ docker build -t lambda:prod --target production .
$ docker build -t lambda:dev --target dev .
$ docker build -t lambda:default .  # default to dev
```

As a final touch, I prefer to default to a production target, which can be enabled using this
last instruction at the bottom at the dockerfile:

```Dockerfile
FROM production AS release
```

Meaning that we have a production targeting image **with local support**.

```console
$ docker build -t lambda:default .  # default to "release"
```

## Conclusion

Feel free to reach out if you have feedbacks or questions !

[Theo "Bob" Massard][linkedin]

[linkedin]: https://linkedin.com/in/tbobm/

[docker-scratch]: https://hub.docker.com/_/scratch
[gh-distroless]: https://github.com/GoogleContainerTools/distroless
[gh-bazel-distroless]: https://github.com/GoogleContainerTools/rules_distroless/tree/main
