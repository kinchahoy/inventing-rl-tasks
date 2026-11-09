# Publishable verifier: task image + bundled tests. No real builder key; the fixture client key
# ships inside tests/ and the builder address comes from the task's tests/docker-compose.yaml.
FROM task
COPY --from=tests . /tests
RUN chmod 0600 /tests/builder_key
