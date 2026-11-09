FROM task
# Harbor treats an explicit verifier image as having bundled private tests.
COPY --from=tests . /tests
COPY --from=client client_key /run/builder-client/key
COPY --from=client known_hosts /root/.ssh/known_hosts
RUN chmod 0600 /run/builder-client/key /root/.ssh/known_hosts
# Builds are remote-only: a failed builder never falls back to root locally.
ENV REPLICA_REMOTE_BUILDER="ssh-ng://buildclient@replica-builder x86_64-linux /run/builder-client/key 2 1 - -"
