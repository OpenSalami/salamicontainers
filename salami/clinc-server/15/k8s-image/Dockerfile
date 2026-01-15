FROM ubuntu:22.04

# Minimal base for running Cinc Server in a container/Kubernetes (no systemd)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl ca-certificates bash locales iproute2 \
      tzdata \
      cron && \
    rm -rf /var/lib/apt/lists/*

# Ensure cron hourly directory exists (infra-server::log_cleanup expects it)
RUN mkdir -p /etc/cron.hourly

# Locale
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# Set timezone files so tzdata / Perl can resolve it
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Basic hostname/hosts for Ohai (can be overridden by Kubernetes)
RUN echo "cinc-server" > /etc/hostname && \
    printf "127.0.0.1 localhost cinc-server\n::1 localhost ip6-localhost ip6-loopback\n" > /etc/hosts

# Install Cinc Server (amd64)
RUN curl -L https://omnitruck.cinc.sh/install.sh -o /tmp/install-cinc.sh && \
    chmod +x /tmp/install-cinc.sh && \
    bash /tmp/install-cinc.sh -P cinc-server && \
    rm -f /tmp/install-cinc.sh

# Optional: initial config tweak so postgres listen_address doesn't depend on Ohai
RUN mkdir -p /etc/opscode && \
    cat > /etc/opscode/private-chef.rb <<'EOF'
postgresql['listen_address'] = '127.0.0.1'

# /etc/opscode/private-chef.rb

postgresql['listen_address'] = '127.0.0.1'

begin
  class Chef
    class Resource
      class ComponentRunitSupervisor < Chef::Resource
        resource_name :component_runit_supervisor

        default_action :create
        allowed_actions :create

        property :name, String, name_property: true

        action :create do
          Chef::Log.warn("component_runit_supervisor[\#{name}] no-op in k8s image (no real systemd)")
          # Do nothing: rely on docker-entrypoint.sh and runit
        end
      end
    end
  end
rescue StandardError => e
  Chef::Log.warn("Failed to override component_runit_supervisor: \#{e}")
end
EOF

RUN cat /etc/opscode/private-chef.rb
# Support external Postgres via environment variables if desired
# (Typically you will mount a ConfigMap/Secret with a full private-chef.rb instead.)
# These envs are hints; real config should live in private-chef.rb.
ENV PGHOST="" \
    PGPORT="5432" \
    PGUSER="" \
    PGPASSWORD="" \
    PGSSLMODE="prefer"

# Stub partybus config.rb to satisfy infra-server::partybus in container
RUN mkdir -p /opt/cinc-project/embedded/service/partybus && \
        printf '%s\n' \
            '# Minimal stub Partybus config for container/Kubernetes' \
            'module Partybus' \
            '  class Config' \
            '    def self.config' \
            '      @config ||= {}' \
            '    end' \
            '  end' \
            'end' \
            > /opt/cinc-project/embedded/service/partybus/config.rb

# Minimal systemctl shim so omnibus cookbooks that call
# 'systemctl daemon-reload' don't fail. This does NOT run real systemd.
COPY systemctl-shim.sh /usr/local/bin/systemctl
RUN chmod +x /usr/local/bin/systemctl && \
        ln -s /usr/local/bin/systemctl /bin/systemctl

# Simple entrypoint: reconfigure once (idempotent) then start services
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["foreground"]
