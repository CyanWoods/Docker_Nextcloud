# 基础镜像：你自己的 Nextcloud 衍生镜像
FROM cyanwoods/nextcloud:tmp

# 避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 一次性安装所有运行时依赖 + 清理缓存
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        vim \
        sudo \
        ssl-cert \
        certbot \
        python3-certbot-apache \
        ffmpeg \
        ghostscript \
        procps \
        smbclient \
        supervisor \
    ; \
    rm -rf /var/lib/apt/lists/*

# 构建并启用 PHP 扩展（保留 bz2 与 smbclient；去掉 imap）
# 说明：Trixie 无 libc-client-dev，imap 扩展在 Trixie 上不建议自编译
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    # 构建期依赖：按需精简，libsmbclient-dev 用于 pecl smbclient
    apt-get install -y --no-install-recommends \
        libbz2-dev \
        libsmbclient-dev \
    ; \
    \
    # 安装并启用 bz2 扩展
    docker-php-ext-install bz2; \
    \
    # 通过 PECL 安装 smbclient 扩展并启用
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    \
    # 计算真正的运行时依赖并固定为 manual，其他构建依赖自动清理
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get(\"extension_dir\");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# Apache：启用 SSL 及默认站点
RUN set -eux; \
    a2enmod ssl; \
    a2ensite default-ssl

# supervisor 目录
RUN set -eux; \
    mkdir -p /var/log/supervisord /var/run/supervisord

# 复制你的 supervisor 配置
COPY supervisord.conf /supervisord.conf

# 启动 supervisord
CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]

