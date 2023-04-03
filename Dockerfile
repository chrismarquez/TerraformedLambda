FROM rust:1.68 as build
WORKDIR /usr/src/api-service
COPY src ./src
COPY Cargo.lock Cargo.toml ./
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo install --path . --target x86_64-unknown-linux-musl

FROM gcr.io/distroless/cc-debian11
ARG log_level
ENV RUST_LOG=${log_level}
COPY --from=build /usr/local/cargo/bin/TerraformedLambda .
ENTRYPOINT [ "./TerraformedLambda" ]
