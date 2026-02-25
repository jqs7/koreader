FROM koreader/kokindle:0.4.6-22.04
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && "$HOME/.cargo/bin/rustup" default stable
