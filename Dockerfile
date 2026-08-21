FROM docker.io/nousresearch/hermes-agent:latest

USER root

RUN mkdir -p /sandbox/.hermes \
    && chown -R 10000:10000 /sandbox

ENV HOME=/sandbox
ENV HERMES_HOME=/sandbox/.hermes
ENV HERMES_WRITE_SAFE_ROOT=/sandbox
ENV PATH=/opt/hermes/bin:/opt/hermes/.venv/bin:${PATH}

WORKDIR /sandbox

USER 10000:10000

CMD ["/bin/bash"]