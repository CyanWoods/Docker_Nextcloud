# Docker_Nextcloud

在官方 Nextcloud Apache 镜像上做二层构建，补齐官方镜像未内置的系统包与 PHP 扩展，并跟随上游版本滚动升级。

## 做了什么

- 基础镜像来自官方 [nextcloud/docker](https://github.com/nextcloud/docker)（以 git submodule 形式挂在 `nextcloud/`）。
- 追加 APT 包：`vim`、`sudo`、`ssl-cert`、`certbot`、`python3-certbot-apache`、`ffmpeg`、`ghostscript`、`procps`、`smbclient`、`supervisor`。
- 追加 PHP 扩展：`bz2`（`docker-php-ext-install`）与 `smbclient`（PECL）。构建期依赖 `libbz2-dev` / `libsmbclient-dev` 编译完成后自动清理，保持镜像精简。
- 启用 Apache `ssl` 模块与 `default-ssl` 站点。
- 追加 Apache 配置 `photokit-501.conf`（`a2enconf` 启用）：对 iOS 客户端 PhotoKit 探测（带 `X-NC-PhotoKit-Upload: 1` 的 `OPTIONS` 请求）返回 `501`，因服务端无可续传上传能力，客户端据此回退普通上传。
- 用 `supervisord` 取代默认 CMD，在同一容器内同时跑 `apache2-foreground` 与 Nextcloud 自带 `/cron.sh`。因为 `supervisord` 接管了 CMD，上游 entrypoint 的升级逻辑会被跳过，Dockerfile 显式设 `NEXTCLOUD_UPDATE=1` 补回。

## 两段式构建

| 阶段 | 来源 | 产物 |
|------|------|------|
| Stage 1 | `nextcloud/<major>/apache/Dockerfile`（上游） | `build.sh` 本地打 `cyanwoods/nextcloud:tmp`；`buildx.sh` 推 `cyanwoods/nextcloud-origin:<version>` / `:latest` |
| Stage 2 | 根 `Dockerfile`（`FROM` 上游基线 + 附加包/扩展/supervisor） | `cyanwoods/nextcloud:<version>` / `:latest` |

版本号取自 `nextcloud/latest.txt`（`buildx.sh` 从 `nextcloud/versions.json` 读 `<major>.version`）。

## 构建命令

单机构建（推 Docker Hub，构建后清理本地中间/最终镜像并 prune 缓存）：

```bash
./build.sh 34        # 指定 Nextcloud 主版本
```

多架构构建（`linux/amd64,linux/arm64`）：

```bash
./buildx.sh 34                                    # 默认双架构
./buildx.sh 34 linux/amd64,linux/arm64 --no-cache
```

多架构镜像无法 `--load` 到本地，`buildx.sh` 一律 `--push`。

## submodule 维护

```bash
cd nextcloud && git checkout master && git pull && git submodule update --init --recursive && cd ..
```

新增一个主版本（如 35）时：更新 submodule → 复制 `build34.sh` 为 `build35.sh` 并替换版本号 → 确认 `nextcloud/35/apache/Dockerfile` 存在。

## CI（Gitea Actions）

`.gitea/workflows/ci.yml`：

- **check** job：每天 `0 2 * * *` 拉取 submodule 上游，比对 `nextcloud/latest.txt`。有变更则提交 submodule 更新并 push 回本仓，输出 `changed=true`。
- **build** job：`changed=true` 或手动触发时 `force_build=true` 才运行。QEMU + Buildx 双架构构建并推送 Docker Hub。
- 手动触发（`workflow_dispatch`）输入：`force_build`（无上游变更也强制构建）、`no_cache`（`--no-cache` 全量重建）。

需在 Gitea 仓库配置 Secrets：`DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN`（写权限）。

## 部署

- Docker Hub：`cyanwoods/nextcloud`（最终镜像）、`cyanwoods/nextcloud-origin`（上游中间镜像）。
- 运行位置：NAS `nextcloud` 容器（`172.18.0.10`）。
