FROM ubuntu:22.04

ENV container=docker

# Systemd + basics + tzdata
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd systemd-sysv \
      dbus \
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

# Basic hostname/hosts for Ohai
RUN echo "cinc-server" > /etc/hostname && \
    printf "127.0.0.1 localhost cinc-server\n::1 localhost ip6-localhost ip6-loopback\n" > /etc/hosts

# Install Cinc Server (amd64)
RUN curl -L https://omnitruck.cinc.sh/install.sh -o /tmp/install-cinc.sh && \
    chmod +x /tmp/install-cinc.sh && \
    bash /tmp/install-cinc.sh -P cinc-server && \
    rm -f /tmp/install-cinc.sh

# Optional: initial config tweak so postgres listen_address doesn't depend on Ohai
RUN mkdir -p /etc/opscode && \
    printf "postgresql['listen_address'] = '127.0.0.1'\n" > /etc/opscode/private-chef.rb

# Stub partybus config.rb to satisfy infra-server::partybus in container
RUN mkdir -p /opt/cinc-project/embedded/service/partybus && \
    printf '%s\n' \
      '# Minimal stub Partybus config for container lab' \
      'module Partybus' \
      '  class Config' \
      '    def self.config' \
      '      @config ||= {}' \
      '    end' \
      '  end' \
      'end' \
      > /opt/cinc-project/embedded/service/partybus/config.rb

EXPOSE 443

STOPSIGNAL SIGRTMIN+3
VOLUME ["/sys/fs/cgroup", "/run", "/run/lock"]

CMD ["/sbin/init"]