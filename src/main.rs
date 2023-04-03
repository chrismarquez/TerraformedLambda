
use aws_lambda_events::encodings::Body;
use aws_lambda_events::event::apigw::{ApiGatewayProxyRequest, ApiGatewayProxyResponse};
use aws_lambda_events::http::HeaderMap;
use lambda_runtime::{Error, LambdaEvent, service_fn};


async fn handle_ping(event: LambdaEvent<ApiGatewayProxyRequest>) -> Result<ApiGatewayProxyResponse, Error> {
    let method = event.payload.http_method.as_str();
    let path = event.payload.path.unwrap();

    log::debug!("Running in debug mode");
    log::info!("Received {} request on {}", method, path);

    let resp = ApiGatewayProxyResponse {
        status_code: 200,
        headers: HeaderMap::new(),
        multi_value_headers: HeaderMap::new(),
        body: Some(Body::Text(format!("Hello from '{}'", path))),
        is_base64_encoded: Some(false),
    };

    Ok(resp)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    simple_logger::init_with_env().unwrap();
    let main_handler = service_fn(handle_ping);
    lambda_runtime::run(main_handler).await?;
    Ok(())
}
