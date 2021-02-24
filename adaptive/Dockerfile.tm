FROM openjdk:8 as builder

RUN git clone https://github.com/tilde-nlp/lucene-sentence-search.git
WORKDIR lucene-sentence-search
RUN git pull && git checkout a3f0c0ba

RUN bash ./gradlew installDist

# Second stage - only jre
FROM openjdk:8u171-jre-slim
COPY --from=builder /lucene-sentence-search/build/install/tm /tm

EXPOSE 80
ENTRYPOINT ["tm/bin/tm", "--port", "80"]
