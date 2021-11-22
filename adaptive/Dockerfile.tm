FROM openjdk:8 as builder

RUN git clone https://github.com/tilde-nlp/lucene-sentence-search.git
WORKDIR lucene-sentence-search
RUN git pull && git checkout 63f8f23f

RUN bash ./gradlew installDist

# Second stage - only jre
FROM openjdk:8u171-jre-slim
COPY --from=builder /lucene-sentence-search/build/install/tm /tm

EXPOSE 80
ENTRYPOINT ["tm/bin/tm", "--port", "80"]
