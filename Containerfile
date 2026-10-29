# clean arch with a non-root user and the repo's mise tools; the repo itself is
# mounted at /repo when run, so the image only changes with mise.toml
FROM docker.io/library/archlinux:latest

RUN pacman -Syu --noconfirm --needed base-devel git jq mise && pacman -Scc --noconfirm
RUN useradd -m dev && printf 'dev ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/dev

USER dev
WORKDIR /home/dev
COPY --chown=dev mise.toml /home/dev/.config/mise/config.toml
RUN mise install
ENV PATH=/home/dev/.local/share/mise/shims:$PATH
