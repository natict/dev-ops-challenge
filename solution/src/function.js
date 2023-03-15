function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var host = request.headers.host.value;

    headers['x-host'] = {value: host};

    return request;
}